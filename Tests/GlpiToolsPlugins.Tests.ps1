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
    # the API v3 document is not downloaded by the tests; the filter fields are then not validated
    Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
    # runs a cmdlet with the parameters given as a hashtable
    function script:Invoke-WithParams { param($Name, $Params) & $Name @Params }
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Plugin cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
    }
    It 'lists the plugins with the state as text' {
        Mock Invoke-GlpiToolsRequest { @([pscustomobject]@{ id = 1; internal_name = 'a'; name = 'A'; version = '1'; state = 1 }, [pscustomobject]@{ id = 2; internal_name = 'b'; name = 'B'; version = '1'; state = 2 }, [pscustomobject]@{ id = 3; internal_name = 'c'; name = 'C'; version = '1'; state = 4 }) } -ModuleName GlpiTools
        $Plugins = @(Get-GlpiToolsPlugins)
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Setup/Plugin' -and $All }
        $Plugins.directory | Should -Be 'a', 'b', 'c'
        $Plugins.state | Should -Be 'Enabled', 'Not installed', 'Installed / not activated'
    }
    It 'keeps the numeric state with -Raw' {
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 1; internal_name = 'a'; state = 1 } } -ModuleName GlpiTools
        (Get-GlpiToolsPlugins -Raw).state | Should -Be 1
    }
    It '<Cmd> has no v3 route' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponent' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentDb' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentInstance' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentLicense' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentSla' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentState' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentTarget' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentTechnic' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentType' }
        @{ Cmd = 'Get-GlpiToolsAppsStructuresComponentUser' }
        @{ Cmd = 'Get-GlpiToolsFusionInventoryAgentModules' }
        @{ Cmd = 'Get-GlpiToolsFusionInventoryAgents' }
        @{ Cmd = 'Get-GlpiToolsFusionInventoryConfig' }
        @{ Cmd = 'Get-GlpiToolsFusionInventoryUnmanaged' }
    ) {
        Mock Check-GlpiToolsPluginExist { $true } -ModuleName GlpiTools
        { & $Cmd } | Should -Throw "*$Cmd is not supported by the GLPI API v3*"
    }
}

Describe 'Plugin list on the legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 5; name = 'x'; state = 1 } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'still calls apirest.php' {
        Get-GlpiToolsPlugins | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'http://glpi/apirest.php/Plugin/' }
    }
}
