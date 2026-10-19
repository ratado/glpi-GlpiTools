BeforeAll {
    # keep the real config untouched by redirecting the home directory
    $script:OriginalHome = $env:HOME
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $script:SavedSession = $global:GlpiToolsSessionToken
    $script:TempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("glpitools-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:TempHome | Out-Null
    $env:HOME = $script:TempHome
    $env:LOCALAPPDATA = $script:TempHome
    # the script module is imported directly so that private functions are reachable and mockable
    Import-Module (Join-Path $PSScriptRoot '..' 'GlpiTools.psm1') -Force
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-GlpiToolsBaseUrl' {
    It 'derives API and token URLs from the site URL' -ForEach @(
        @{ Path = 'https://glpi.example.com' }
        @{ Path = 'https://glpi.example.com/' }
        @{ Path = 'https://glpi.example.com/api.php/v3.0' }
        @{ Path = 'https://glpi.example.com/api.php/v3.0/' }
    ) {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi $Path -ClientId c -ClientSecret s -Username u -Password p
        Get-GlpiToolsBaseUrl -Type Api | Should -Be 'https://glpi.example.com/api.php/v3.0'
        Get-GlpiToolsBaseUrl -Type Token | Should -Be 'https://glpi.example.com/api.php/token'
        Get-GlpiToolsBaseUrl -Type Site | Should -Be 'https://glpi.example.com'
    }
    It 'keeps a site in a subdirectory' {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://x.example.com/glpi' -ClientId c -ClientSecret s -Username u -Password p
        Get-GlpiToolsBaseUrl -Type Token | Should -Be 'https://x.example.com/glpi/api.php/token'
    }
    It 'returns the stored URL unchanged for the legacy API' {
        Set-GlpiToolsConfig -AppToken a -UserToken b -PathToGlpi 'http://x/apirest.php'
        Get-GlpiToolsBaseUrl | Should -Be 'http://x/apirest.php'
    }
}

Describe 'API v3 session' {
    BeforeEach {
        $global:GlpiToolsSessionToken = $null
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId 'cid' -ClientSecret 'csecret' -Username 'glpi' -Password 'pw' -Scope 'api'
        Mock Invoke-RestMethod { [pscustomobject]@{ token_type = 'Bearer'; expires_in = 3600; access_token = 'AT1'; refresh_token = 'RT1' } } -ModuleName GlpiTools
    }

    It 'requests the password grant with the right form body' {
        $s = Set-GlpiToolsInitSession
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Uri -eq 'https://glpi.example.com/api.php/token' -and $Method -eq 'post' -and
            $ContentType -eq 'application/x-www-form-urlencoded' -and
            $Body.grant_type -eq 'password' -and $Body.client_id -eq 'cid' -and $Body.client_secret -eq 'csecret' -and
            $Body.username -eq 'glpi' -and $Body.password -eq 'pw' -and $Body.scope -eq 'api'
        }
        $s.SessionToken | Should -Be 'AT1'
    }
    It 'stores refresh token, type and an expiry 60 seconds before expires_in' {
        Set-GlpiToolsInitSession | Out-Null
        $t = $global:GlpiToolsSessionToken
        $t.RefreshToken | Should -Be 'RT1'
        $t.TokenType | Should -Be 'Bearer'
        ($t.ExpiresAt - [datetime]::UtcNow).TotalSeconds | Should -BeGreaterThan 3500
        ($t.ExpiresAt - [datetime]::UtcNow).TotalSeconds | Should -BeLessThan 3541
    }
    It 'initializes a session on demand' {
        (Get-GlpiToolsSessionToken).SessionToken | Should -Be 'AT1'
    }
    It 'reuses a valid token without calling the server' {
        Set-GlpiToolsInitSession | Out-Null
        Get-GlpiToolsSessionToken | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1
    }
    It 'renews an expired token with the refresh token' {
        Set-GlpiToolsInitSession | Out-Null
        $global:GlpiToolsSessionToken.ExpiresAt = [datetime]::UtcNow.AddMinutes(-1)
        Get-GlpiToolsSessionToken | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Body.grant_type -eq 'refresh_token' -and $Body.refresh_token -eq 'RT1' -and $Body.client_id -eq 'cid' -and $Body.client_secret -eq 'csecret'
        }
    }
    It 'repeats the password grant when the refresh token is rejected' {
        Set-GlpiToolsInitSession | Out-Null
        $global:GlpiToolsSessionToken.ExpiresAt = [datetime]::UtcNow.AddMinutes(-1)
        Mock Invoke-RestMethod { throw 'rejected' } -ModuleName GlpiTools -ParameterFilter { $Body.grant_type -eq 'refresh_token' }
        Mock Invoke-RestMethod { [pscustomobject]@{ token_type = 'Bearer'; expires_in = 3600; access_token = 'AT2'; refresh_token = 'RT2' } } -ModuleName GlpiTools -ParameterFilter { $Body.grant_type -eq 'password' }
        (Get-GlpiToolsSessionToken).SessionToken | Should -Be 'AT2'
    }
    It 'adds SkipCertificateCheck to the token request when configured' {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p -SkipCertificateCheck
        Set-GlpiToolsInitSession | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -ParameterFilter { $SkipCertificateCheck -eq $true } -Exactly 1
    }
    It 'turns OAuth errors into clear messages without leaking secrets' -ForEach @(
        @{ Err = 'invalid_client'; Match = 'invalid_client' }
        @{ Err = 'invalid_grant'; Match = 'invalid_grant' }
    ) {
        Mock Invoke-RestMethod {
            $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Unauthorized'), 'x', 'NotSpecified', $null)
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new((@{ error = $Err; error_description = 'bad' } | ConvertTo-Json))
            throw $e
        } -ModuleName GlpiTools
        $msg = $null
        try { Set-GlpiToolsInitSession } catch { $msg = $_.Exception.Message }
        $msg | Should -Match $Match
        $msg | Should -Not -Match 'csecret'
        $msg | Should -Not -Match 'pw'
    }
    It 'only discards the token on kill session' {
        Set-GlpiToolsInitSession | Out-Null
        Set-GlpiToolsKillSession
        $global:GlpiToolsSessionToken | Should -BeNullOrEmpty
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1
    }
}

Describe 'Legacy session (regression)' {
    BeforeEach {
        $global:GlpiToolsSessionToken = $null
        Set-GlpiToolsConfig -AppToken 'app1' -UserToken 'usr1' -PathToGlpi 'http://glpi/apirest.php'
        Mock Invoke-RestMethod { [pscustomobject]@{ session_token = 'S1' } } -ModuleName GlpiTools
    }
    It 'calls initSession with the legacy headers' {
        $s = Set-GlpiToolsInitSession
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Uri -eq 'http://glpi/apirest.php/initSession/' -and $Headers['App-Token'] -eq 'app1' -and $Headers['Authorization'] -eq 'user_token usr1'
        }
        $s.SessionToken | Should -Be 'S1'
        $global:GlpiToolsSessionToken.PSObject.Properties.Name | Should -Be @('SessionToken')
    }
    It 'calls killSession with the session header' {
        Set-GlpiToolsInitSession | Out-Null
        Set-GlpiToolsKillSession
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Uri -eq 'http://glpi/apirest.php/killSession/' -and $Headers['Session-Token'] -eq 'S1' -and $Headers['App-Token'] -eq 'app1'
        }
        $global:GlpiToolsSessionToken | Should -BeNullOrEmpty
    }
    It 'initializes on demand and returns the stored session' {
        (Get-GlpiToolsSessionToken).SessionToken | Should -Be 'S1'
        (Get-GlpiToolsSessionToken).SessionToken | Should -Be 'S1'
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1
    }
}
