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

Describe 'Assert-GlpiToolsV3ParameterRequired' {
    It 'does nothing when every parameter was informed' {
        { Assert-GlpiToolsV3ParameterRequired -Name 'A', 'B' -BoundParameters @{ A = 1; B = 2 } } | Should -Not -Throw
    }
    It 'throws the typed error naming one parameter' {
        $e = try { Assert-GlpiToolsV3ParameterRequired -Name 'ComputerId' -BoundParameters @{} } catch { $_ }
        $e.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3ParameterRequired'
        $e.Exception.Message | Should -Be 'The parameter -ComputerId is required with the GLPI API v3.'
    }
    It 'names two parameters and fails when only one is informed' {
        $e = try { Assert-GlpiToolsV3ParameterRequired -Name 'ItemType', 'ItemId' -BoundParameters @{ ItemType = 'Computer' } } catch { $_ }
        $e.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3ParameterRequired'
        $e.Exception.Message | Should -Be 'The parameters -ItemType and -ItemId are required with the GLPI API v3.'
    }
}

Describe 'Asset sub-resource cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { @([pscustomobject]@{ id = 2 }, [pscustomobject]@{ id = 3 }, [pscustomobject]@{ id = 4 }) } -ModuleName GlpiTools
    }

    Context '<Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsComputerSoftwareVersions'; IdParam = 'ComputerSoftwareVersionId'; Required = @{}; Missing = 'ComputerId'; Extra = @{ ComputerId = 7 }; Route = '/Assets/Computer/7/SoftwareInstallation' }
        @{ Cmd = 'Get-GlpiToolsSoftwareVersions'; IdParam = 'SoftwareVersionId'; Required = @{}; Missing = 'SoftwareId'; Extra = @{ SoftwareId = 7 }; Route = '/Assets/Software/7/Version' }
        @{ Cmd = 'Get-GlpiToolsFinancialAndAdministrativeInformations'; IdParam = 'FinancialAndAdminstrativeId'; Required = @{}; Missing = 'ItemType'; Extra = @{ ItemType = 'Computer'; ItemId = 7 }; Route = '/Assets/Computer/7/Infocom' }
    ) {
        It 'requires the v3 only parameter with the typed error, before any request' {
            $e = try { & $Cmd -All } catch { $_ }
            $e.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3ParameterRequired'
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
        }
        It 'stops at the first id of a pipeline with the typed error, even when errors are silenced' {
            $result = @()
            $e = $null
            try { $result = @(2, 3, 4 | & $Cmd -ErrorAction SilentlyContinue) } catch { $e = $_ }
            $e.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3ParameterRequired'
            $result.Count | Should -Be 0
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
        }
        It 'reads the list once for a pipeline of ids' {
            $params = $Extra
            $out = @(2, 3 | & $Cmd @params)
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq $Route }
            @($out).Count | Should -Be 2
        }
        It 'reads the list again in a new call' {
            $params = $Extra
            2 | & $Cmd @params | Out-Null
            3 | & $Cmd @params | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 2 -ParameterFilter { $Resource -eq $Route }
        }
    }
}
