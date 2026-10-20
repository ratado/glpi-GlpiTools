<#
.SYNOPSIS
    Function is getting Budget Types informations from GLPI
.DESCRIPTION
    Function is based on BudgetTypeId which you can find in GLPI website
    Returns object with property's of Budget Types
.PARAMETER All
    This parameter will return all Budget Types from GLPI
.PARAMETER BudgetTypeId
    This parameter can take pipline input, either, you can use this function with -BudgetTypeId keyword.
    Provide to this param BudgetTypeId from GLPI Budget Types Bookmark
.PARAMETER Raw
    Parameter which you can use with BudgetTypeId Parameter.
    BudgetTypeId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER BudgetTypeName
    This parameter can take pipline input, either, you can use this function with -BudgetTypeId keyword.
    Provide to this param Budget Types Name from GLPI Budget Types Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsBudgetTypes -All
    Example will return all Budget Types from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsBudgetTypes
    Function gets BudgetTypeId from GLPI from Pipline, and return Budget Types object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsBudgetTypes
    Function gets BudgetTypeId from GLPI from Pipline (u can pass many ID's like that), and return Budget Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsBudgetTypes -BudgetTypeId 326
    Function gets BudgetTypeId from GLPI which is provided through -BudgetTypeId after Function type, and return Budget Types object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsBudgetTypes -BudgetTypeId 326, 321
    Function gets Budget Types Id from GLPI which is provided through -BudgetTypeId keyword after Function type (u can provide many ID's like that), and return Budget Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsBudgetTypes -BudgetTypeName Fusion
    Example will return glpi Budget Types, but what is the most important, Budget Types will be shown exactly as you see in glpi dropdown Budget Types.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Budget Types ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Budget Types from GLPI
.NOTES
    PSP 09/2019
#>

function Get-GlpiToolsDropdownsBudgetTypes {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "BudgetTypeId")]
        [alias('BTID')]
        [string[]]$BudgetTypeId,
        [parameter(Mandatory = $false,
            ParameterSetName = "BudgetTypeId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "BudgetTypeName")]
        [alias('BTN')]
        [string]$BudgetTypeName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $BudgetTypesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Dropdowns/BudgetType' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType BudgetType -Raw
                }
                BudgetTypeId {
                    foreach ($V3ItemId in $BudgetTypeId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Dropdowns/BudgetType/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "BudgetType ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType BudgetType -Raw:$Raw
                        }
                    }
                }
                BudgetTypeName {
                    Search-GlpiToolsItems -SearchFor Budgettype -SearchType contains -SearchValue $BudgetTypeName | ConvertFrom-GlpiToolsV3Item -ItemType BudgetType -Raw
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
                    uri     = "$($PathToGlpi)/Budgettype/?range=0-9999999999999"
                }
                
                $BudgetTypesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($BudgetType in $BudgetTypesAll) {
                    $BudgetTypeHash = [ordered]@{ }
                    $BudgetTypeProperties = $BudgetType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($BudgetTypeProp in $BudgetTypeProperties) {
                        $BudgetTypeHash.Add($BudgetTypeProp.Name, $BudgetTypeProp.Value)
                    }
                    $object = [pscustomobject]$BudgetTypeHash
                    $BudgetTypesArray.Add($object)
                }
                $BudgetTypesArray
                $BudgetTypesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            BudgetTypeId { 
                foreach ( $BTId in $BudgetTypeId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Budgettype/$($BTId)"
                    }

                    Try {
                        $BudgetType = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $BudgetTypeHash = [ordered]@{ }
                            $BudgetTypeProperties = $BudgetType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($BudgetTypeProp in $BudgetTypeProperties) {
                                $BudgetTypeHash.Add($BudgetTypeProp.Name, $BudgetTypeProp.Value)
                            }
                            $object = [pscustomobject]$BudgetTypeHash
                            $BudgetTypesArray.Add($object)
                        } else {
                            $BudgetTypeHash = [ordered]@{ }
                            $BudgetTypeProperties = $BudgetType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($BudgetTypeProp in $BudgetTypeProperties) {

                                $BudgetTypePropNewValue = Get-GlpiToolsParameters -Parameter $BudgetTypeProp.Name -Value $BudgetTypeProp.Value

                                $BudgetTypeHash.Add($BudgetTypeProp.Name, $BudgetTypePropNewValue)
                            }
                            $object = [pscustomobject]$BudgetTypeHash
                            $BudgetTypesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Budget Type ID = $BTId is not found"
                        
                    }
                    $BudgetTypesArray
                    $BudgetTypesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            BudgetTypeName { 
                Search-GlpiToolsItems -SearchFor Budgettype -SearchType contains -SearchValue $BudgetTypeName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}