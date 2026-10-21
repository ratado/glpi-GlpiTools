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

Describe 'Dropdown cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
    }

    Context '<Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectTasksTypes'; IdParam = 'ProjectTaskTypeId'; NameParam = 'ProjectTaskTypeName'; Route = '/Dropdowns/ProjectTaskType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectTypes'; IdParam = 'ProjectTypeId'; NameParam = 'ProjectTypeName'; Route = '/Dropdowns/ProjectType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsRequestSources'; IdParam = 'RequestSourceId'; NameParam = 'RequestSourceName'; Route = '/Dropdowns/RequestType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSolutionTemplates'; IdParam = 'SolutionTemplateId'; NameParam = 'SolutionTemplateName'; Route = '/Dropdowns/SolutionTemplate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSolutionTypes'; IdParam = 'SolutionTypesId'; NameParam = 'SolutionTypesName'; Route = '/Dropdowns/SolutionType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsTaskCategories'; IdParam = 'TaskCategoryId'; NameParam = 'TaskCategoryName'; Route = '/Dropdowns/TaskCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsTaskTemplates'; IdParam = 'TaskTemplateId'; NameParam = 'TaskTemplateName'; Route = '/Dropdowns/TaskTemplate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsTicketCategories'; IdParam = 'TicketCategoriesId'; NameParam = 'TicketCategoriesName'; Route = '/Dropdowns/ITILCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCalendars'; IdParam = 'CalendarId'; NameParam = 'CalendarName'; Route = '/Dropdowns/Calendar' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCloseTimes'; IdParam = 'CloseTimeId'; NameParam = 'CloseTimeName'; Route = '/Dropdowns/CloseTime' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBlacklistedMailContent'; IdParam = 'BlacklistedMailContentId'; NameParam = 'BlacklistedMailContentName'; Route = '/Dropdowns/DeniedMailContent' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBlacklists'; IdParam = 'BlacklistsId'; NameParam = 'BlacklistsName'; Route = '/Dropdowns/DenyList' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLocations'; IdParam = 'LocationsId'; NameParam = 'LocationsName'; Route = '/Dropdowns/Location' }
        @{ Cmd = 'Get-GlpiToolsDropdownsManufacturers'; IdParam = 'ManufacturerId'; NameParam = 'ManufacturerName'; Route = '/Dropdowns/Manufacturer' }
        @{ Cmd = 'Get-GlpiToolsDropdownsStatusesOfItems'; IdParam = 'StatesId'; NameParam = 'StatesName'; Route = '/Dropdowns/State' }
        @{ Cmd = 'Get-GlpiToolsDropdownsWifiNetworks'; IdParam = 'WifiNetworkId'; NameParam = 'WifiNetworkName'; Route = '/Dropdowns/WifiNetwork' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBussinessCriticities'; IdParam = 'BussinessCriticityId'; NameParam = 'BussinessCriticityName'; Route = '/Dropdowns/BusinessCriticity' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDocumentHeadings'; IdParam = 'DocumentHeadingId'; NameParam = 'DocumentHeadingName'; Route = '/Dropdowns/DocumentCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDocumentTypes'; IdParam = 'DocumentTypeId'; NameParam = 'DocumentTypeName'; Route = '/Dropdowns/DocumentType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsComputerModels'; IdParam = 'ComputerModelsId'; NameParam = 'ComputerModelsName'; Route = '/Dropdowns/ComputerModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsEnclosureModels'; IdParam = 'EnclosureModelId'; NameParam = 'EnclosureModelName'; Route = '/Dropdowns/EnclosureModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsMonitorModels'; IdParam = 'MonitorModelId'; NameParam = 'MonitorModelName'; Route = '/Dropdowns/MonitorModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkEquipmentModels'; IdParam = 'NetworkEquipmentModelId'; NameParam = 'NetworkEquipmentModelName'; Route = '/Dropdowns/NetworkEquipmentModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPeripheralModels'; IdParam = 'PeripheralModelId'; NameParam = 'PeripheralModelName'; Route = '/Dropdowns/PeripheralModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPhoneModels'; IdParam = 'PhoneModelId'; NameParam = 'PhoneModelName'; Route = '/Dropdowns/PhoneModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPrinterModels'; IdParam = 'PrinterModelId'; NameParam = 'PrinterModelName'; Route = '/Dropdowns/PrinterModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDomains'; IdParam = 'DomainId'; NameParam = 'DomainName'; Route = '/Management/Domain' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworks'; IdParam = 'NetworkId'; NameParam = 'NetworkName'; Route = '/Dropdowns/Network' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSUpdateSources'; IdParam = 'UpdateSourcesId'; NameParam = 'UpdateSourcesName'; Route = '/Dropdowns/AutoUpdateSystem' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBudgetTypes'; IdParam = 'BudgetTypeId'; NameParam = 'BudgetTypeName'; Route = '/Dropdowns/BudgetType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCartridgeTypes'; IdParam = 'CartridgeTypeId'; NameParam = 'CartridgeTypeName'; Route = '/Dropdowns/CartridgeItemType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCertificateTypes'; IdParam = 'CertificateTypeId'; NameParam = 'CertificateTypeName'; Route = '/Dropdowns/CertificateType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsComputerTypes'; IdParam = 'ComputerTypeId'; NameParam = 'ComputerTypeName'; Route = '/Dropdowns/ComputerType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsConsumableTypes'; IdParam = 'ConsumableTypeId'; NameParam = 'ConsumableTypeName'; Route = '/Dropdowns/ConsumableItemType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsContactTypes'; IdParam = 'ContactTypeId'; NameParam = 'ContactTypeName'; Route = '/Dropdowns/ContactType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsContractTypes'; IdParam = 'ContractTypeId'; NameParam = 'ContractTypeName'; Route = '/Dropdowns/ContractType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDevicesTypes'; IdParam = 'DeviceTypeId'; NameParam = 'DeviceTypeName'; Route = '/Dropdowns/PeripheralType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsFileSystemsTypes'; IdParam = 'FileSystemTypeId'; NameParam = 'FileSystemTypeName'; Route = '/Dropdowns/Filesystem' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLicenseTypes'; IdParam = 'LicenseTypeId'; NameParam = 'LicenseTypeName'; Route = '/Dropdowns/LicenseType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLineTypes'; IdParam = 'LineTypeId'; NameParam = 'LineTypeName'; Route = '/Dropdowns/LineType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsMonitorTypes'; IdParam = 'MonitorTypeId'; NameParam = 'MonitorTypeName'; Route = '/Dropdowns/MonitorType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkingEquipmentTypes'; IdParam = 'NetworkingEquipmentTypeId'; NameParam = 'NetworkingEquipmentTypeName'; Route = '/Dropdowns/NetworkEquipmentType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPhonesPowerSupplyTypes'; IdParam = 'PhonePowerSupplyTypeId'; NameParam = 'PhonePowerSupplyTypeName'; Route = '/Dropdowns/PhonePowerSupply' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPhonesTypes'; IdParam = 'PhoneTypeId'; NameParam = 'PhoneTypeName'; Route = '/Dropdowns/PhoneType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPrinterTypes'; IdParam = 'PrinterTypeId'; NameParam = 'PrinterTypeName'; Route = '/Dropdowns/PrinterType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsThirdPartyTypes'; IdParam = 'ThirdPartyTypeId'; NameParam = 'ThirdPartyTypeName'; Route = '/Dropdowns/SupplierType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsUserCategories'; IdParam = 'UserCategoryId'; NameParam = 'UserCategoryName'; Route = '/Administration/UserCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsUserTitles'; IdParam = 'UserTitleId'; NameParam = 'UserTitleName'; Route = '/Administration/UserTitle' }
        @{ Cmd = 'Get-GlpiToolsDropdownsStatesOfTheVirtualMachine'; IdParam = 'StateOfTheVirtualMachineId'; NameParam = 'StateOfTheVirtualMachineName'; Route = '/Dropdowns/VirtualMachineState' }
        @{ Cmd = 'Get-GlpiToolsDropdownsVirtualizationSystems'; IdParam = 'VirtualizationSystemId'; NameParam = 'VirtualizationSystemName'; Route = '/Dropdowns/VirtualMachineType' }
    ) {
        It 'lists, gets by id and searches by name' {
            & $Cmd -All | Out-Null
            $ExpectedFilter = Get-ExpectedTrashFilter -Route $Route
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq $Route -and $All -and $Query.filter -eq $ExpectedFilter }
            Invoke-WithParams $Cmd @{ $IdParam = 2 } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/2" }
            Invoke-WithParams $Cmd @{ $NameParam = 'foo' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq $Route -and $Query.filter -like 'name=ilike=*foo*' }
        }
        It 'skips a missing item but reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ $IdParam = 99 } } | Should -Not -Throw
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ $IdParam = 99 } } | Should -Throw '*boom*'
        }
    }

    It '<Cmd> has no v3 route' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectStates' }
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectTaskTemplates' }
        @{ Cmd = 'Get-GlpiToolsDropdownsInternetDomains' }
        @{ Cmd = 'Get-GlpiToolsDropdownsIpNetworks' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkNames' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceCaseModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceControlModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceDriveModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceGenericModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceGraphicCardModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceHardDriveModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceMemoryModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceMotherboardModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceNetworkCardModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDevicePowerSupplyModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceProcessorModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceSensorModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceSoundCardModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOtherComponentModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPduModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsRackModels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLineOperators' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkInterfaces' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkOutlets' }
        @{ Cmd = 'Get-GlpiToolsDropdownsVlan' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSArchitectures' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSEditions' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSKernelVersions' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSKernels' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSServicePacks' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSVersions' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOperatingSystems' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSoftwareCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsKnowledgeBaseCategories' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCaseTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsGenericDeviceTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsInterfaceHardDriveTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsMemoryTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPduTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsRackTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSensorTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSimcardTypes' }
        @{ Cmd = 'Get-GlpiToolsDropdownsVirtualizationModels' }
    ) {
        { & $Cmd -All } | Should -Throw "*$Cmd is not supported by the GLPI API v3*"
    }
}

Describe 'Dropdown cmdlets on the legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 5; name = 'x' } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'still calls apirest.php for <Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectStates'; IdParam = 'ProjectStateId'; Item = 'projectstate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectTaskTemplates'; IdParam = 'ProjectTaskTemplateId'; Item = 'projecttasktemplate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectTasksTypes'; IdParam = 'ProjectTaskTypeId'; Item = 'projecttasktype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsProjectTypes'; IdParam = 'ProjectTypeId'; Item = 'projecttype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsRequestSources'; IdParam = 'RequestSourceId'; Item = 'requesttype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSolutionTemplates'; IdParam = 'SolutionTemplateId'; Item = 'solutiontemplate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSolutionTypes'; IdParam = 'SolutionTypesId'; Item = 'solutiontype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsTaskCategories'; IdParam = 'TaskCategoryId'; Item = 'taskcategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsTaskTemplates'; IdParam = 'TaskTemplateId'; Item = 'tasktemplate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsTicketCategories'; IdParam = 'TicketCategoriesId'; Item = 'itilcategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCalendars'; IdParam = 'CalendarId'; Item = 'calendar' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCloseTimes'; IdParam = 'CloseTimeId'; Item = 'holiday' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBlacklistedMailContent'; IdParam = 'BlacklistedMailContentId'; Item = 'Blacklistedmailcontent' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBlacklists'; IdParam = 'BlacklistsId'; Item = 'Blacklist' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLocations'; IdParam = 'LocationsId'; Item = 'Location' }
        @{ Cmd = 'Get-GlpiToolsDropdownsManufacturers'; IdParam = 'ManufacturerId'; Item = 'Manufacturer' }
        @{ Cmd = 'Get-GlpiToolsDropdownsStatusesOfItems'; IdParam = 'StatesId'; Item = 'State' }
        @{ Cmd = 'Get-GlpiToolsDropdownsInternetDomains'; IdParam = 'InternetDomainId'; Item = 'fqdn' }
        @{ Cmd = 'Get-GlpiToolsDropdownsIpNetworks'; IdParam = 'IpNetworkId'; Item = 'ipnetwork' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkNames'; IdParam = 'NetworkNameId'; Item = 'networkname' }
        @{ Cmd = 'Get-GlpiToolsDropdownsWifiNetworks'; IdParam = 'WifiNetworkId'; Item = 'wifinetwork' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBussinessCriticities'; IdParam = 'BussinessCriticityId'; Item = 'businesscriticity' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDocumentHeadings'; IdParam = 'DocumentHeadingId'; Item = 'documentcategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDocumentTypes'; IdParam = 'DocumentTypeId'; Item = 'documenttype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsComputerModels'; IdParam = 'ComputerModelsId'; Item = 'ComputerModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceCaseModels'; IdParam = 'DeviceCaseModelId'; Item = 'devicecasemodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceControlModels'; IdParam = 'DeviceControlModelId'; Item = 'devicecontrolmodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceDriveModels'; IdParam = 'DeviceDriveModelId'; Item = 'devicedrivemodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceGenericModels'; IdParam = 'DeviceGenericModelId'; Item = 'devicegenericmodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceGraphicCardModels'; IdParam = 'DeviceGraphicCardModelId'; Item = 'devicegraphiccardmodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceHardDriveModels'; IdParam = 'DeviceHardDriveModelId'; Item = 'DeviceHardDriveModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceMemoryModels'; IdParam = 'DeviceMemoryModelId'; Item = 'DeviceMemoryModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceMotherboardModels'; IdParam = 'DeviceMotherboardModelId'; Item = 'DeviceMotherBoardModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceNetworkCardModels'; IdParam = 'DeviceNetworkCardModelId'; Item = 'DeviceNetworkCardModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDevicePowerSupplyModels'; IdParam = 'DevicePowerSupplyModelId'; Item = 'DevicePowerSupplyModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceProcessorModels'; IdParam = 'DeviceProcessorModelId'; Item = 'DeviceProcessorModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceSensorModels'; IdParam = 'DeviceSensorModelId'; Item = 'DeviceSensorModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDeviceSoundCardModels'; IdParam = 'DeviceSoundCardModelId'; Item = 'DeviceSoundCardModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsEnclosureModels'; IdParam = 'EnclosureModelId'; Item = 'enclosuremodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsMonitorModels'; IdParam = 'MonitorModelId'; Item = 'MonitorModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkEquipmentModels'; IdParam = 'NetworkEquipmentModelId'; Item = 'networkequipmentmodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOtherComponentModels'; IdParam = 'OtherComponentModelId'; Item = 'DevicePciModel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPduModels'; IdParam = 'PduModelId'; Item = 'pdumodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPeripheralModels'; IdParam = 'PeripheralModelId'; Item = 'peripheralmodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPhoneModels'; IdParam = 'PhoneModelId'; Item = 'phonemodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPrinterModels'; IdParam = 'PrinterModelId'; Item = 'printermodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsRackModels'; IdParam = 'RackModelId'; Item = 'rackmodel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDomains'; IdParam = 'DomainId'; Item = 'Domain' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLineOperators'; IdParam = 'LineOperatorId'; Item = 'lineoperator' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkInterfaces'; IdParam = 'NetworkInterfaceId'; Item = 'networkinterface' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkOutlets'; IdParam = 'NetworkOutletId'; Item = 'netpoint' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworks'; IdParam = 'NetworkId'; Item = 'Network' }
        @{ Cmd = 'Get-GlpiToolsDropdownsVlan'; IdParam = 'VlanId'; Item = 'vlan' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSArchitectures'; IdParam = 'OSArchitectureId'; Item = 'operatingsystemarchitecture' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSEditions'; IdParam = 'OSEditionId'; Item = 'operatingsystemedition' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSKernelVersions'; IdParam = 'OSKernelVersionId'; Item = 'Operatingsystemkernelversion' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSKernels'; IdParam = 'OSKernelId'; Item = 'operatingsystemkernel' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSServicePacks'; IdParam = 'OSServicePackId'; Item = 'OperatingSystemServicePack' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSUpdateSources'; IdParam = 'UpdateSourcesId'; Item = 'autoupdatesystem' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOSVersions'; IdParam = 'OSVersionId'; Item = 'operatingsystemversion' }
        @{ Cmd = 'Get-GlpiToolsDropdownsOperatingSystems'; IdParam = 'OperatingSystemId'; Item = 'OperatingSystem' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSoftwareCategory'; IdParam = 'SoftwareCategoryId'; Item = 'SoftwareCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsKnowledgeBaseCategories'; IdParam = 'KnowledgeBaseCategoryId'; Item = 'knowbaseitemcategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsBudgetTypes'; IdParam = 'BudgetTypeId'; Item = 'Budgettype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCartridgeTypes'; IdParam = 'CartridgeTypeId'; Item = 'cartridgeitemtype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCaseTypes'; IdParam = 'CaseTypeId'; Item = 'DeviceCaseType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsCertificateTypes'; IdParam = 'CertificateTypeId'; Item = 'certificatetype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsComputerTypes'; IdParam = 'ComputerTypeId'; Item = 'ComputerType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsConsumableTypes'; IdParam = 'ConsumableTypeId'; Item = 'consumableitemtype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsContactTypes'; IdParam = 'ContactTypeId'; Item = 'contacttype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsContractTypes'; IdParam = 'ContractTypeId'; Item = 'contracttype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsDevicesTypes'; IdParam = 'DeviceTypeId'; Item = 'peripheraltype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsFileSystemsTypes'; IdParam = 'FileSystemTypeId'; Item = 'filesystem' }
        @{ Cmd = 'Get-GlpiToolsDropdownsGenericDeviceTypes'; IdParam = 'GenericDeviceTypeId'; Item = 'DeviceGenericType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsInterfaceHardDriveTypes'; IdParam = 'InterfaceHardDriveTypeId'; Item = 'interfacetype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLicenseTypes'; IdParam = 'LicenseTypeId'; Item = 'softwarelicensetype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsLineTypes'; IdParam = 'LineTypeId'; Item = 'Linetype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsMemoryTypes'; IdParam = 'MemoryTypeId'; Item = 'DeviceMemoryType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsMonitorTypes'; IdParam = 'MonitorTypeId'; Item = 'monitortype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsNetworkingEquipmentTypes'; IdParam = 'NetworkingEquipmentTypeId'; Item = 'networkequipmenttype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPduTypes'; IdParam = 'PduTypeId'; Item = 'pdutype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPhonesPowerSupplyTypes'; IdParam = 'PhonePowerSupplyTypeId'; Item = 'phonepowersupply' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPhonesTypes'; IdParam = 'PhoneTypeId'; Item = 'phonetype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsPrinterTypes'; IdParam = 'PrinterTypeId'; Item = 'printertype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsRackTypes'; IdParam = 'RackTypeId'; Item = 'Racktype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSensorTypes'; IdParam = 'SensorTypeId'; Item = 'DeviceSensorType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsSimcardTypes'; IdParam = 'SimcardTypeId'; Item = 'DeviceSimcardType' }
        @{ Cmd = 'Get-GlpiToolsDropdownsThirdPartyTypes'; IdParam = 'ThirdPartyTypeId'; Item = 'suppliertype' }
        @{ Cmd = 'Get-GlpiToolsDropdownsUserCategories'; IdParam = 'UserCategoryId'; Item = 'UserCategory' }
        @{ Cmd = 'Get-GlpiToolsDropdownsUserTitles'; IdParam = 'UserTitleId'; Item = 'UserTitle' }
        @{ Cmd = 'Get-GlpiToolsDropdownsStatesOfTheVirtualMachine'; IdParam = 'StateOfTheVirtualMachineId'; Item = 'virtualmachinestate' }
        @{ Cmd = 'Get-GlpiToolsDropdownsVirtualizationModels'; IdParam = 'VirtualizationModelId'; Item = 'virtualmachinesystem' }
        @{ Cmd = 'Get-GlpiToolsDropdownsVirtualizationSystems'; IdParam = 'VirtualizationSystemId'; Item = 'virtualmachinetype' }
    ) {
        & $Cmd -All | Out-Null
        Invoke-WithParams $Cmd @{ $IdParam = 2 } | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -like "http://glpi/apirest.php/$Item/?range=*" }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq "http://glpi/apirest.php/$Item/2" }
    }
}
