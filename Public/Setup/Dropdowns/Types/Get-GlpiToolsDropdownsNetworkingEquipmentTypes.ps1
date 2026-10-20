<#
.SYNOPSIS
    Function is getting Networking Equipment Types informations from GLPI
.DESCRIPTION
    Function is based on NetworkingEquipmentTypeId which you can find in GLPI website
    Returns object with property's of Networking Equipment Types
.PARAMETER All
    This parameter will return all Networking Equipment Types from GLPI
.PARAMETER NetworkingEquipmentTypeId
    This parameter can take pipline input, either, you can use this function with -NetworkingEquipmentTypeId keyword.
    Provide to this param NetworkingEquipmentTypeId from GLPI Networking Equipment Types Bookmark
.PARAMETER Raw
    Parameter which you can use with NetworkingEquipmentTypeId Parameter.
    NetworkingEquipmentTypeId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER NetworkingEquipmentTypeName
    This parameter can take pipline input, either, you can use this function with -NetworkingEquipmentTypeId keyword.
    Provide to this param Networking Equipment Types Name from GLPI Networking Equipment Types Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsNetworkingEquipmentTypes -All
    Example will return all Networking Equipment Types from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsNetworkingEquipmentTypes
    Function gets NetworkingEquipmentTypeId from GLPI from Pipline, and return Networking Equipment Types object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsNetworkingEquipmentTypes
    Function gets NetworkingEquipmentTypeId from GLPI from Pipline (u can pass many ID's like that), and return Networking Equipment Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsNetworkingEquipmentTypes -NetworkingEquipmentTypeId 326
    Function gets NetworkingEquipmentTypeId from GLPI which is provided through -NetworkingEquipmentTypeId after Function type, and return Networking Equipment Types object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsNetworkingEquipmentTypes -NetworkingEquipmentTypeId 326, 321
    Function gets Networking Equipment Types Id from GLPI which is provided through -NetworkingEquipmentTypeId keyword after Function type (u can provide many ID's like that), and return Networking Equipment Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsNetworkingEquipmentTypes -NetworkingEquipmentTypeName Fusion
    Example will return glpi Networking Equipment Types, but what is the most important, Networking Equipment Types will be shown exactly as you see in glpi dropdown Networking Equipment Types.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Networking Equipment Types ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Networking Equipment Types from GLPI
.NOTES
    PSP 09/2019
#>

function Get-GlpiToolsDropdownsNetworkingEquipmentTypes {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "NetworkingEquipmentTypeId")]
        [alias('NETID')]
        [string[]]$NetworkingEquipmentTypeId,
        [parameter(Mandatory = $false,
            ParameterSetName = "NetworkingEquipmentTypeId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "NetworkingEquipmentTypeName")]
        [alias('NETN')]
        [string]$NetworkingEquipmentTypeName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $NetworkingEquipmentTypesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Dropdowns/NetworkEquipmentType' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType NetworkEquipmentType -Raw
                }
                NetworkingEquipmentTypeId {
                    foreach ($V3ItemId in $NetworkingEquipmentTypeId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Dropdowns/NetworkEquipmentType/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "NetworkEquipmentType ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType NetworkEquipmentType -Raw:$Raw
                        }
                    }
                }
                NetworkingEquipmentTypeName {
                    Search-GlpiToolsItems -SearchFor networkequipmenttype -SearchType contains -SearchValue $NetworkingEquipmentTypeName | ConvertFrom-GlpiToolsV3Item -ItemType NetworkEquipmentType -Raw
                }
            }
            return
        }

        switch ($ChoosenParam) {
            All { 
                $params = @{
                    headers = @{
                        'Content-Type'  = 'application/json'
                        'App-Token'     = $AppToken
                        'Session-Token' = $SessionToken
                    }
                    method  = 'get'
                    uri     = "$($PathToGlpi)/networkequipmenttype/?range=0-9999999999999"
                }
                
                $NetworkingEquipmentTypesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($NetworkingEquipmentType in $NetworkingEquipmentTypesAll) {
                    $NetworkingEquipmentTypeHash = [ordered]@{ }
                    $NetworkingEquipmentTypeProperties = $NetworkingEquipmentType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($NetworkingEquipmentTypeProp in $NetworkingEquipmentTypeProperties) {
                        $NetworkingEquipmentTypeHash.Add($NetworkingEquipmentTypeProp.Name, $NetworkingEquipmentTypeProp.Value)
                    }
                    $object = [pscustomobject]$NetworkingEquipmentTypeHash
                    $NetworkingEquipmentTypesArray.Add($object)
                }
                $NetworkingEquipmentTypesArray
                $NetworkingEquipmentTypesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            NetworkingEquipmentTypeId { 
                foreach ( $NETId in $NetworkingEquipmentTypeId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/networkequipmenttype/$($NETId)"
                    }

                    Try {
                        $NetworkingEquipmentType = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $NetworkingEquipmentTypeHash = [ordered]@{ }
                            $NetworkingEquipmentTypeProperties = $NetworkingEquipmentType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($NetworkingEquipmentTypeProp in $NetworkingEquipmentTypeProperties) {
                                $NetworkingEquipmentTypeHash.Add($NetworkingEquipmentTypeProp.Name, $NetworkingEquipmentTypeProp.Value)
                            }
                            $object = [pscustomobject]$NetworkingEquipmentTypeHash
                            $NetworkingEquipmentTypesArray.Add($object)
                        } else {
                            $NetworkingEquipmentTypeHash = [ordered]@{ }
                            $NetworkingEquipmentTypeProperties = $NetworkingEquipmentType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($NetworkingEquipmentTypeProp in $NetworkingEquipmentTypeProperties) {

                                $NetworkingEquipmentTypePropNewValue = Get-GlpiToolsParameters -Parameter $NetworkingEquipmentTypeProp.Name -Value $NetworkingEquipmentTypeProp.Value

                                $NetworkingEquipmentTypeHash.Add($NetworkingEquipmentTypeProp.Name, $NetworkingEquipmentTypePropNewValue)
                            }
                            $object = [pscustomobject]$NetworkingEquipmentTypeHash
                            $NetworkingEquipmentTypesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Networking Equipment Type ID = $NETId is not found"
                        
                    }
                    $NetworkingEquipmentTypesArray
                    $NetworkingEquipmentTypesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            NetworkingEquipmentTypeName { 
                Search-GlpiToolsItems -SearchFor networkequipmenttype -SearchType contains -SearchValue $NetworkingEquipmentTypeName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}