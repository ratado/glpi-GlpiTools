BeforeAll {
    # keep the real config untouched by redirecting the home directory
    $script:OriginalHome = $env:HOME
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $script:TempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("glpitools-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:TempHome | Out-Null
    $env:HOME = $script:TempHome
    $env:LOCALAPPDATA = $script:TempHome
    # the script module is imported directly so that private functions are reachable and mockable
    Import-Module (Join-Path $PSScriptRoot '..' 'GlpiTools.psm1') -Force
    # the tests write and delete files, so they must stay inside the temporary home
    $script:SavedSession = $global:GlpiToolsSessionToken
    $script:ConfigFile = if ($IsLinux) { "$env:HOME/.config/GlpiToolsConfig\Configuration.json" } else { "$env:LOCALAPPDATA\GlpiToolsConfig\Configuration.json" }
    if (-not $script:ConfigFile.StartsWith($script:TempHome)) { throw "Config path is outside the temporary home: $script:ConfigFile" }
}

AfterAll {
    $global:GlpiToolsSessionToken = $script:SavedSession
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Set-GlpiToolsConfig / Get-GlpiToolsConfig' {

    Context 'legacy configuration (v1)' {
        BeforeAll {
            Set-GlpiToolsConfig -AppToken 'app123' -UserToken 'user456' -PathToGlpi 'http://glpi/apirest.php'
            $script:Cfg = Get-GlpiToolsConfig
        }
        It 'keeps the legacy fields' {
            $Cfg.AppToken | Should -Be 'app123'
            $Cfg.UserToken | Should -Be 'user456'
            $Cfg.PathToGlpi | Should -Be 'http://glpi/apirest.php'
        }
        It 'reports v1 and leaves OAuth fields empty' {
            $Cfg.ApiVersion | Should -Be 'v1'
            $Cfg.ClientId | Should -BeNullOrEmpty
            $Cfg.ClientSecret | Should -BeNullOrEmpty
            $Cfg.SkipCertificateCheck | Should -BeFalse
        }
        It 'does not store secrets in clear text' {
            $raw = Get-Content $ConfigFile -Raw
            $raw | Should -Not -Match 'app123'
            $raw | Should -Not -Match 'user456'
        }
        It 'reports v1 through Get-GlpiToolsApiVersion' {
            Get-GlpiToolsApiVersion | Should -Be 'v1'
        }
    }

    Context 'old config file without the new fields' {
        BeforeAll {
            # build a file in the format written by versions before the API v3 support
            $enc = { param($t) ConvertFrom-SecureString (ConvertTo-SecureString $t -AsPlainText -Force) }
            [ordered]@{ AppToken = (& $enc 'oldapp'); UserToken = (& $enc 'olduser'); PathToGlpi = (& $enc 'http://old/apirest.php') } |
                ConvertTo-Json | Out-File -FilePath $ConfigFile
            $script:Cfg = Get-GlpiToolsConfig
        }
        It 'is read as v1 without errors' {
            $Cfg.ApiVersion | Should -Be 'v1'
            $Cfg.AppToken | Should -Be 'oldapp'
            $Cfg.PathToGlpi | Should -Be 'http://old/apirest.php'
        }
    }

    Context 'v3 password grant' {
        BeforeAll {
            Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId 'cid' -ClientSecret 'csecret' `
                -Username 'glpi' -Password (ConvertTo-SecureString 'pw' -AsPlainText -Force) -SkipCertificateCheck
            $script:Cfg = Get-GlpiToolsConfig
        }
        It 'stores and reads all fields' {
            $Cfg.ApiVersion | Should -Be 'v3'
            $Cfg.AuthMode | Should -Be 'Password'
            $Cfg.PathToGlpi | Should -Be 'https://glpi.example.com'
            $Cfg.ClientId | Should -Be 'cid'
            $Cfg.ClientSecret | Should -Be 'csecret'
            $Cfg.Username | Should -Be 'glpi'
            $Cfg.Password | Should -Be 'pw'
            $Cfg.Scope | Should -Be 'api'
            $Cfg.SkipCertificateCheck | Should -BeTrue
        }
        It 'does not store secrets in clear text' {
            $raw = Get-Content $ConfigFile -Raw
            $raw | Should -Not -Match 'csecret'
            $raw | Should -Not -Match '"pw"'
        }
        It 'reports v3 through Get-GlpiToolsApiVersion' {
            Get-GlpiToolsApiVersion | Should -Be 'v3'
        }
        It 'restricts file permissions on Linux' -Skip:(-not $IsLinux) {
            (Get-Item $ConfigFile).UnixFileMode | Should -Be ([System.IO.UnixFileMode]'UserRead, UserWrite')
        }
    }

    Context 'session reset' {
        It 'drops the session token when the configuration is rewritten' {
            Set-GlpiToolsSessionToken -SessionToken 'abc'
            Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'http://x/apirest.php'
            $global:GlpiToolsSessionToken | Should -BeNullOrEmpty
        }
    }

    Context 'invalid combinations' {
        It 'rejects v3 without ClientId' {
            { Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://x' -ClientSecret 's' -Username 'u' -Password 'p' } | Should -Throw
        }
        It 'rejects -ApiVersion v1 together with OAuth parameters' {
            { Set-GlpiToolsConfig -ApiVersion v1 -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p' } | Should -Throw
        }
        It 'rejects -ApiVersion v3 with legacy tokens' {
            { Set-GlpiToolsConfig -ApiVersion v3 -AppToken 'a' -UserToken 'b' -PathToGlpi 'https://x' } | Should -Throw
        }
        It 'rejects empty secrets and keeps the previous config' {
            Set-GlpiToolsConfig -AppToken 'keep' -UserToken 'me' -PathToGlpi 'http://x/apirest.php'
            { Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret '' -Username 'u' -Password 'p' } | Should -Throw
            (Get-GlpiToolsConfig).AppToken | Should -Be 'keep'
        }
        It 'infers v3 when ApiVersion is omitted' {
            Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p'
            (Get-GlpiToolsConfig).ApiVersion | Should -Be 'v3'
        }
    }

    Context 'missing config file' {
        It 'warns and returns nothing' {
            Remove-Item $ConfigFile -Force -ErrorAction SilentlyContinue
            $r = Get-GlpiToolsConfig -WarningVariable w -WarningAction SilentlyContinue
            $r | Should -BeNullOrEmpty
            $w | Should -Not -BeNullOrEmpty
        }
    }

    Context 'certificate option in requests' {
        BeforeEach {
            Mock Invoke-RestMethod { 'ok' } -ModuleName GlpiTools
        }
        It 'adds SkipCertificateCheck when the option is on' {
            Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'https://x/apirest.php' -SkipCertificateCheck
            Invoke-GlpiToolsRequestApi -Params @{ uri = 'https://x'; method = 'get' } | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -ParameterFilter { $SkipCertificateCheck -eq $true } -Exactly 1
        }
        It 'does not add it by default' {
            Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'https://x/apirest.php'
            Invoke-GlpiToolsRequestApi -Params @{ uri = 'https://x'; method = 'get' } | Out-Null
            Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -ParameterFilter { -not $SkipCertificateCheck } -Exactly 1
        }
    }

    Context 'session closing on reconfiguration' {
        BeforeEach {
            Mock Invoke-RestMethod { 'ok' } -ModuleName GlpiTools
        }
        It 'calls killSession for an open legacy session' {
            Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'https://x/apirest.php'
            Set-GlpiToolsSessionToken -SessionToken 'tok'
            Set-GlpiToolsConfig -AppToken 'a2' -UserToken 'b2' -PathToGlpi 'https://x/apirest.php'
            Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -ParameterFilter { $Uri -match 'killSession' } -Exactly 1
            $global:GlpiToolsSessionToken | Should -BeNullOrEmpty
        }
        It 'does not call the server when there is no session' {
            Set-GlpiToolsConfig -AppToken 'a3' -UserToken 'b3' -PathToGlpi 'https://x/apirest.php'
            Set-GlpiToolsConfig -AppToken 'a4' -UserToken 'b4' -PathToGlpi 'https://x/apirest.php'
            Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 0
        }
    }
}
