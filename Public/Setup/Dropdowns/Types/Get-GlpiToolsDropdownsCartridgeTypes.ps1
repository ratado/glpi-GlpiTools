<#
.SYNOPSIS
    Function is getting Cartridge Types informations from GLPI
.DESCRIPTION
    Function is based on CartridgeTypeId which you can find in GLPI website
    Returns object with property's of Cartridge Types
.PARAMETER All
    This parameter will return all Cartridge Types from GLPI
.PARAMETER CartridgeTypeId
    This parameter can take pipline input, either, you can use this function with -CartridgeTypeId keyword.
    Provide to this param CartridgeTypeId from GLPI Cartridge Types Bookmark
.PARAMETER Raw
    Parameter which you can use with CartridgeTypeId Parameter.
    CartridgeTypeId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER CartridgeTypeName
    This parameter can take pipline input, either, you can use this function with -CartridgeTypeId keyword.
    Provide to this param Cartridge Types Name from GLPI Cartridge Types Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsCartridgeTypes -All
    Example will return all Cartridge Types from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsCartridgeTypes
    Function gets CartridgeTypeId from GLPI from Pipline, and return Cartridge Types object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsCartridgeTypes
    Function gets CartridgeTypeId from GLPI from Pipline (u can pass many ID's like that), and return Cartridge Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsCartridgeTypes -CartridgeTypeId 326
    Function gets CartridgeTypeId from GLPI which is provided through -CartridgeTypeId after Function type, and return Cartridge Types object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsCartridgeTypes -CartridgeTypeId 326, 321
    Function gets Cartridge Types Id from GLPI which is provided through -CartridgeTypeId keyword after Function type (u can provide many ID's like that), and return Cartridge Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsCartridgeTypes -CartridgeTypeName Fusion
    Example will return glpi Cartridge Types, but what is the most important, Cartridge Types will be shown exactly as you see in glpi dropdown Cartridge Types.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Cartridge Types ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Cartridge Types from GLPI
.NOTES
    PSP 09/2019
#>

function Get-GlpiToolsDropdownsCartridgeTypes {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "CartridgeTypeId")]
        [alias('CTID')]
        [string[]]$CartridgeTypeId,
        [parameter(Mandatory = $false,
            ParameterSetName = "CartridgeTypeId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "CartridgeTypeName")]
        [alias('CTN')]
        [string]$CartridgeTypeName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $CartridgeTypesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Dropdowns/CartridgeItemType' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType CartridgeItemType -Raw
                }
                CartridgeTypeId {
                    foreach ($V3ItemId in $CartridgeTypeId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Dropdowns/CartridgeItemType/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "CartridgeItemType ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType CartridgeItemType -Raw:$Raw
                        }
                    }
                }
                CartridgeTypeName {
                    Search-GlpiToolsItems -SearchFor cartridgeitemtype -SearchType contains -SearchValue $CartridgeTypeName | ConvertFrom-GlpiToolsV3Item -ItemType CartridgeItemType -Raw
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
                    uri     = "$($PathToGlpi)/cartridgeitemtype/?range=0-9999999999999"
                }
                
                $CartridgeTypesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($CartridgeType in $CartridgeTypesAll) {
                    $CartridgeTypeHash = [ordered]@{ }
                    $CartridgeTypeProperties = $CartridgeType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($CartridgeTypeProp in $CartridgeTypeProperties) {
                        $CartridgeTypeHash.Add($CartridgeTypeProp.Name, $CartridgeTypeProp.Value)
                    }
                    $object = [pscustomobject]$CartridgeTypeHash
                    $CartridgeTypesArray.Add($object)
                }
                $CartridgeTypesArray
                $CartridgeTypesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            CartridgeTypeId { 
                foreach ( $CTId in $CartridgeTypeId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/cartridgeitemtype/$($CTId)"
                    }

                    Try {
                        $CartridgeType = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $CartridgeTypeHash = [ordered]@{ }
                            $CartridgeTypeProperties = $CartridgeType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($CartridgeTypeProp in $CartridgeTypeProperties) {
                                $CartridgeTypeHash.Add($CartridgeTypeProp.Name, $CartridgeTypeProp.Value)
                            }
                            $object = [pscustomobject]$CartridgeTypeHash
                            $CartridgeTypesArray.Add($object)
                        } else {
                            $CartridgeTypeHash = [ordered]@{ }
                            $CartridgeTypeProperties = $CartridgeType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($CartridgeTypeProp in $CartridgeTypeProperties) {

                                $CartridgeTypePropNewValue = Get-GlpiToolsParameters -Parameter $CartridgeTypeProp.Name -Value $CartridgeTypeProp.Value

                                $CartridgeTypeHash.Add($CartridgeTypeProp.Name, $CartridgeTypePropNewValue)
                            }
                            $object = [pscustomobject]$CartridgeTypeHash
                            $CartridgeTypesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Cartridge Type ID = $CTId is not found"
                        
                    }
                    $CartridgeTypesArray
                    $CartridgeTypesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            CartridgeTypeName { 
                Search-GlpiToolsItems -SearchFor cartridgeitemtype -SearchType contains -SearchValue $CartridgeTypeName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}