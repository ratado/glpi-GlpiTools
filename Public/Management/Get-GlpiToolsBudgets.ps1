<#
.SYNOPSIS
    Function is getting Budget informations from GLPI
.DESCRIPTION
    Function is based on BudgetId which you can find in GLPI website
    Returns object with property's of Budget
.PARAMETER All
    This parameter will return all Budget from GLPI
.PARAMETER BudgetId
    This parameter can take pipline input, either, you can use this function with -BudgetId keyword.
    Provide to this param BudgetId from GLPI Budget Bookmark
.PARAMETER Raw
    Parameter which you can use with BudgetId Parameter.
    BudgetId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER BudgetName
    This parameter can take pipline input, either, you can use this function with -BudgetId keyword.
    Provide to this param Budget Name from GLPI Budget Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsBudgets -All
    Example will return all Budget from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsBudgets
    Function gets BudgetId from GLPI from Pipline, and return Budget object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsBudgets
    Function gets BudgetId from GLPI from Pipline (u can pass many ID's like that), and return Budget object
.EXAMPLE
    PS C:\> Get-GlpiToolsBudgets -BudgetId 326
    Function gets BudgetId from GLPI which is provided through -BudgetId after Function type, and return Budget object
.EXAMPLE 
    PS C:\> Get-GlpiToolsBudgets -BudgetId 326, 321
    Function gets Budget Id from GLPI which is provided through -BudgetId keyword after Function type (u can provide many ID's like that), and return Budget object
.EXAMPLE
    PS C:\> Get-GlpiToolsBudgets -BudgetName Fusion
    Example will return glpi Budget, but what is the most important, Budget will be shown exactly as you see in glpi dropdown Budget.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Budget ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Budget from GLPI
.NOTES
    PSP 11/2019
#>

function Get-GlpiToolsBudgets {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "BudgetId")]
        [alias('BID')]
        [string[]]$BudgetId,
        [parameter(Mandatory = $false,
            ParameterSetName = "BudgetId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "BudgetName")]
        [alias('BN')]
        [string]$BudgetName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $BudgetsArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Management/Budget' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Budget -Raw
                }
                BudgetId {
                    # the v3 answer already carries the names of the related items
                    foreach ($V3ItemId in $BudgetId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Management/Budget/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Budget ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Budget -Raw:$Raw
                        }
                    }
                }
                BudgetName {
                    Search-GlpiToolsItems -SearchFor budget -SearchType contains -SearchValue $BudgetName | ConvertFrom-GlpiToolsV3Item -ItemType Budget -Raw
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
                    uri     = "$($PathToGlpi)/budget/?range=0-9999999999999"
                }
                
                $BudgetsAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($Budget in $BudgetsAll) {
                    $BudgetHash = [ordered]@{ }
                    $BudgetProperties = $Budget.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($BudgetProp in $BudgetProperties) {
                        $BudgetHash.Add($BudgetProp.Name, $BudgetProp.Value)
                    }
                    $object = [pscustomobject]$BudgetHash
                    $BudgetsArray.Add($object)
                }
                $BudgetsArray
                $BudgetsArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            BudgetId { 
                foreach ( $BId in $BudgetId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/budget/$($BId)"
                    }

                    Try {
                        $Budget = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $BudgetHash = [ordered]@{ }
                            $BudgetProperties = $Budget.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($BudgetProp in $BudgetProperties) {
                                $BudgetHash.Add($BudgetProp.Name, $BudgetProp.Value)
                            }
                            $object = [pscustomobject]$BudgetHash
                            $BudgetsArray.Add($object)
                        } else {
                            $BudgetHash = [ordered]@{ }
                            $BudgetProperties = $Budget.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($BudgetProp in $BudgetProperties) {

                                $BudgetPropNewValue = Get-GlpiToolsParameters -Parameter $BudgetProp.Name -Value $BudgetProp.Value

                                $BudgetHash.Add($BudgetProp.Name, $BudgetPropNewValue)
                            }
                            $object = [pscustomobject]$BudgetHash
                            $BudgetsArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Budget ID = $BId is not found"
                        
                    }
                    $BudgetsArray
                    $BudgetsArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            BudgetName { 
                Search-GlpiToolsItems -SearchFor budget -SearchType contains -SearchValue $BudgetName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}