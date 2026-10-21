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
    . (Join-Path $PSScriptRoot 'Support' 'TrashFilter.ps1')
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

Describe 'Asset cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
    }

    Context '<Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsComputers'; Base = 'Computer'; Route = '/Assets/Computer' }
        @{ Cmd = 'Get-GlpiToolsMonitors'; Base = 'Monitor'; Route = '/Assets/Monitor' }
        @{ Cmd = 'Get-GlpiToolsNetworkEquipments'; Base = 'NetworkEquipment'; Route = '/Assets/NetworkEquipment' }
        @{ Cmd = 'Get-GlpiToolsPeripherals'; Base = 'Peripheral'; Route = '/Assets/Peripheral' }
        @{ Cmd = 'Get-GlpiToolsPhones'; Base = 'Phone'; Route = '/Assets/Phone' }
        @{ Cmd = 'Get-GlpiToolsPrinters'; Base = 'Printer'; Route = '/Assets/Printer' }
        @{ Cmd = 'Get-GlpiToolsRacks'; Base = 'Rack'; Route = '/Assets/Rack' }
        @{ Cmd = 'Get-GlpiToolsEnclosures'; Base = 'Enclosure'; Route = '/Assets/Enclosure' }
        @{ Cmd = 'Get-GlpiToolsPdus'; Base = 'Pdu'; Route = '/Assets/PDU' }
        @{ Cmd = 'Get-GlpiToolsSoftware'; Base = 'Software'; Route = '/Assets/Software' }
        @{ Cmd = 'Get-GlpiToolsCartridgeItems'; Base = 'CartridgeItem'; Route = '/Assets/Cartridge' }
        @{ Cmd = 'Get-GlpiToolsConsumableItems'; Base = 'ConsumableItem'; Route = '/Assets/Consumable' }
    ) {
        It 'lists the items outside the trash' {
            & $Cmd -All | Out-Null
            $ExpectedFilter = Get-ExpectedTrashFilter -Route $Route
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq $Route -and $All -and $Query.filter -eq $ExpectedFilter }
        }
        It 'gets each item by id, also from the pipeline' {
            Invoke-WithParams $Cmd @{ "${Base}Id" = 2, 3 } | Out-Null
            4 | & $Cmd | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/2" }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/3" }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/4" }
        }
        It 'skips a missing item but reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ "${Base}Id" = 99 } } | Should -Not -Throw
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ "${Base}Id" = 99 } } | Should -Throw '*boom*'
        }
        It 'searches by name' {
            Invoke-WithParams $Cmd @{ "${Base}Name" = 'foo' } | Out-Null
            $NamePattern = if (Get-ExpectedTrashFilter -Route $Route) { 'name=ilike=*foo*;*' } else { 'name=ilike=*foo*' }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq $Route -and $Query.filter -like $NamePattern }
        }
        It 'refuses -Parameter values without a v3 equivalent' {
            { Invoke-WithParams $Cmd @{ "${Base}Id" = 2; Parameter = 'WithLogs' } } | Should -Throw '*-Parameter WithLogs is not supported*'
        }
    }

    Context 'asset sub-resources' {
        It 'lists the software installed on a computer' {
            Get-GlpiToolsComputerSoftwareVersions -All -ComputerId 5 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Computer/5/SoftwareInstallation' -and $All }
        }
        It 'selects records by id inside the computer' {
            Mock Invoke-GlpiToolsRequest { @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 2 }) } -ModuleName GlpiTools
            @(Get-GlpiToolsComputerSoftwareVersions -ComputerSoftwareVersionId 2 -ComputerId 5 -Raw).Count | Should -Be 1
        }
        It 'lists the versions of a software' {
            Get-GlpiToolsSoftwareVersions -All -SoftwareId 1 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Software/1/Version' -and $All }
        }
        It 'gets the financial information of an asset' {
            Get-GlpiToolsFinancialAndAdministrativeInformations -All -ItemType Pdu -ItemId 3 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/PDU/3/Infocom' }
        }
        It '<Cmd> asks for the asset with the v3' -ForEach @(
            @{ Cmd = 'Get-GlpiToolsComputerSoftwareVersions'; Message = '*-ComputerId is required*' }
            @{ Cmd = 'Get-GlpiToolsSoftwareVersions'; Message = '*-SoftwareId is required*' }
            @{ Cmd = 'Get-GlpiToolsFinancialAndAdministrativeInformations'; Message = '*-ItemType and -ItemId are required*' }
        ) {
            { & $Cmd -All } | Should -Throw $Message
        }
    }
}

Describe 'Asset cmdlets on the legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 5; name = 'x' } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'still calls apirest.php for <Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsComputers'; IdParam = 'ComputerId'; Item = 'Computer' }
        @{ Cmd = 'Get-GlpiToolsMonitors'; IdParam = 'MonitorId'; Item = 'Monitor' }
        @{ Cmd = 'Get-GlpiToolsSoftware'; IdParam = 'SoftwareId'; Item = 'Software' }
        @{ Cmd = 'Get-GlpiToolsCartridgeItems'; IdParam = 'CartridgeItemId'; Item = 'CartridgeItem' }
    ) {
        & $Cmd -All | Out-Null
        Invoke-WithParams $Cmd @{ $IdParam = 2; Raw = $true } | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -like "http://glpi/apirest.php/$Item/?range=*" }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq "http://glpi/apirest.php/$Item/2" }
    }
}

Describe 'Financial information on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
    }
    It 'returns nothing when the asset has no financial information' {
        Mock Invoke-GlpiToolsRequest {
            $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
            $PSCmdlet.ThrowTerminatingError($e)
        } -ModuleName GlpiTools
        @(Get-GlpiToolsFinancialAndAdministrativeInformations -All -ItemType Computer -ItemId 5).Count | Should -Be 0
    }
}
