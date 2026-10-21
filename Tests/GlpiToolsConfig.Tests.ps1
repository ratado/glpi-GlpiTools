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

Describe 'Get-GlpiToolsConfig cache' {

    BeforeAll {
        Set-GlpiToolsConfig -AppToken 'cache1' -UserToken 'u' -PathToGlpi 'http://glpi/apirest.php'
    }

    It 'decrypts the file only once while it is unchanged' {
        # rewriting the config empties the cache, so the first read below is the only one that decrypts
        Set-GlpiToolsConfig -AppToken 'cache1' -UserToken 'u' -PathToGlpi 'http://glpi/apirest.php'
        Mock ConvertFrom-GlpiConfigSecret { 'x' } -ModuleName GlpiTools
        Get-GlpiToolsConfig | Out-Null
        Get-GlpiToolsConfig | Out-Null
        Get-GlpiToolsConfig | Out-Null
        # one decryption per secret field (7) for the whole sequence
        Should -Invoke ConvertFrom-GlpiConfigSecret -ModuleName GlpiTools -Exactly 7
        # the mocked values must not leak into the next tests
        Set-GlpiToolsConfig -AppToken 'cache1' -UserToken 'u' -PathToGlpi 'http://glpi/apirest.php'
    }

    It 'returns a copy that does not alter the cache' {
        $First = Get-GlpiToolsConfig
        $First.AppToken = 'changed'
        (Get-GlpiToolsConfig).AppToken | Should -Be 'cache1'
    }

    It 'is refreshed by Set-GlpiToolsConfig' {
        Set-GlpiToolsConfig -AppToken 'cache2' -UserToken 'u' -PathToGlpi 'http://glpi/apirest.php'
        (Get-GlpiToolsConfig).AppToken | Should -Be 'cache2'
    }

    It 'notices a change made to the file by another process' {
        InModuleScope GlpiTools {
            Get-GlpiToolsConfig | Out-Null
        }
        $Data = Get-Content $script:ConfigFile | ConvertFrom-Json
        $Data.ApiVersion = 'v3'
        $Data | ConvertTo-Json | Out-File -FilePath $script:ConfigFile
        (Get-Item $script:ConfigFile).LastWriteTimeUtc = [datetime]::UtcNow.AddSeconds(5)
        (Get-GlpiToolsConfig).ApiVersion | Should -Be 'v3'
    }
}

Describe 'OutputFormat in the configuration' {

    It 'is Legacy by default in the v3 configuration' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p'
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Legacy'
        InModuleScope GlpiTools { Get-GlpiToolsOutputFormat } | Should -Be 'Legacy'
    }
    It 'is stored when informed' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p' -OutputFormat Native
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Native'
        InModuleScope GlpiTools { Get-GlpiToolsOutputFormat } | Should -Be 'Native'
    }
    It 'is Legacy for a file written before the field existed' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p' -OutputFormat Native
        $Data = Get-Content $script:ConfigFile | ConvertFrom-Json
        $Data.PSObject.Properties.Remove('OutputFormat')
        $Data | ConvertTo-Json | Out-File -FilePath $script:ConfigFile
        (Get-Item $script:ConfigFile).LastWriteTimeUtc = [datetime]::UtcNow.AddSeconds(5)
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Legacy'
    }
    It 'is Legacy for a value that is not valid' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p'
        $Data = Get-Content $script:ConfigFile | ConvertFrom-Json
        $Data.OutputFormat = 'Other'
        $Data | ConvertTo-Json | Out-File -FilePath $script:ConfigFile
        (Get-Item $script:ConfigFile).LastWriteTimeUtc = [datetime]::UtcNow.AddSeconds(6)
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Legacy'
    }
    It 'is not accepted with the legacy tokens' {
        { Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'http://x/apirest.php' -OutputFormat Native } | Should -Throw
    }
    It 'is ignored by the legacy API even if the file says Native' {
        Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'http://x/apirest.php'
        $Data = Get-Content $script:ConfigFile | ConvertFrom-Json
        $Data | Add-Member -NotePropertyName OutputFormat -NotePropertyValue Native -Force
        $Data | ConvertTo-Json | Out-File -FilePath $script:ConfigFile
        (Get-Item $script:ConfigFile).LastWriteTimeUtc = [datetime]::UtcNow.AddSeconds(7)
        InModuleScope GlpiTools { Get-GlpiToolsOutputFormat } | Should -Be 'Legacy'
    }
}

Describe 'Set-GlpiToolsOutputFormat' {

    BeforeEach {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'client1' -ClientSecret 'secret1' -Username 'user1' -Password 'pass1'
    }

    It 'changes only the format and keeps the credentials' {
        $Before = Get-Content $script:ConfigFile | ConvertFrom-Json
        Set-GlpiToolsOutputFormat -Format Native
        $After = Get-Content $script:ConfigFile | ConvertFrom-Json
        $After.OutputFormat | Should -Be 'Native'
        # the encrypted values are the same text, so nothing was decrypted and encrypted again
        foreach ($Field in 'PathToGlpi', 'ClientId', 'ClientSecret', 'Username', 'Password', 'ApiVersion', 'Scope') {
            $After.$Field | Should -Be $Before.$Field
        }
        $Config = Get-GlpiToolsConfig
        $Config.ClientSecret | Should -Be 'secret1'
        $Config.Password | Should -Be 'pass1'
    }
    It 'does not change the file with -WhatIf' {
        # the format is kept when the configuration is rewritten, so the starting point is set explicitly
        Set-GlpiToolsOutputFormat -Format Legacy
        Set-GlpiToolsOutputFormat -Format Native -WhatIf
        (Get-Content $script:ConfigFile | ConvertFrom-Json).OutputFormat | Should -Be 'Legacy'
    }
    It 'is seen at once by the commands, because the cached configuration is dropped' {
        Get-GlpiToolsConfig | Out-Null
        Set-GlpiToolsOutputFormat -Format Native
        InModuleScope GlpiTools { Get-GlpiToolsOutputFormat } | Should -Be 'Native'
        Set-GlpiToolsOutputFormat -Format Legacy
        InModuleScope GlpiTools { Get-GlpiToolsOutputFormat } | Should -Be 'Legacy'
    }
    It 'keeps the open session' {
        Set-GlpiToolsSessionToken -SessionToken 'keepme'
        Set-GlpiToolsOutputFormat -Format Native
        $global:GlpiToolsSessionToken.SessionToken | Should -Be 'keepme'
    }
    It 'keeps the file private on Linux' -Skip:(-not $IsLinux) {
        Set-GlpiToolsOutputFormat -Format Native
        # the flags are compared as a value, because the text of an enum lists them in no fixed order
        [System.IO.File]::GetUnixFileMode((Get-Item -LiteralPath $script:ConfigFile).FullName) -eq [System.IO.UnixFileMode]'UserRead, UserWrite' | Should -BeTrue
    }
    It 'refuses a format that does not exist' {
        { Set-GlpiToolsOutputFormat -Format Other } | Should -Throw
    }
    It 'refuses to run with the legacy configuration' {
        Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'http://x/apirest.php'
        { Set-GlpiToolsOutputFormat -Format Native } | Should -Throw '*API v3*'
    }
    It 'refuses to run without a configuration' {
        Remove-Item $script:ConfigFile -Force
        { Set-GlpiToolsOutputFormat -Format Native } | Should -Throw '*Config File*'
    }
}

Describe 'OutputFormat when the configuration is rewritten' {
    It 'keeps Native when -OutputFormat is not informed' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p' -OutputFormat Native
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 'new' -Username 'u' -Password 'p'
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Native'
        (Get-GlpiToolsConfig).ClientSecret | Should -Be 'new'
    }
    It 'changes it when informed' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p' -OutputFormat Legacy
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Legacy'
    }
    It 'does not carry Native over to the legacy API' {
        Set-GlpiToolsConfig -PathToGlpi 'https://x' -ClientId 'c' -ClientSecret 's' -Username 'u' -Password 'p' -OutputFormat Native
        Set-GlpiToolsConfig -AppToken 'a' -UserToken 'b' -PathToGlpi 'http://x/apirest.php'
        (Get-GlpiToolsConfig).OutputFormat | Should -Be 'Legacy'
    }
}
