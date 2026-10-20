<#
.SYNOPSIS
    Function is getting Contract informations from GLPI
.DESCRIPTION
    Function is based on ContractId which you can find in GLPI website
    Returns object with property's of Contract
.PARAMETER All
    This parameter will return all Contract from GLPI
.PARAMETER ContractId
    This parameter can take pipline input, either, you can use this function with -ContractId keyword.
    Provide to this param ContractId from GLPI Contract Bookmark
.PARAMETER Raw
    Parameter which you can use with ContractId Parameter.
    ContractId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER ContractName
    This parameter can take pipline input, either, you can use this function with -ContractId keyword.
    Provide to this param Contract Name from GLPI Contract Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsContracts -All
    Example will return all Contract from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsContracts
    Function gets ContractId from GLPI from Pipline, and return Contract object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsContracts
    Function gets ContractId from GLPI from Pipline (u can pass many ID's like that), and return Contract object
.EXAMPLE
    PS C:\> Get-GlpiToolsContracts -ContractId 326
    Function gets ContractId from GLPI which is provided through -ContractId after Function type, and return Contract object
.EXAMPLE 
    PS C:\> Get-GlpiToolsContracts -ContractId 326, 321
    Function gets Contract Id from GLPI which is provided through -ContractId keyword after Function type (u can provide many ID's like that), and return Contract object
.EXAMPLE
    PS C:\> Get-GlpiToolsContracts -ContractName Fusion
    Example will return glpi Contract, but what is the most important, Contract will be shown exactly as you see in glpi dropdown Contract.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Contract ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Contract from GLPI
.NOTES
    PSP 11/2019
#>

function Get-GlpiToolsContracts {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "ContractId")]
        [alias('CID')]
        [string[]]$ContractId,
        [parameter(Mandatory = $false,
            ParameterSetName = "ContractId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "ContractName")]
        [alias('CN')]
        [string]$ContractName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $ContractsArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Management/Contract' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Contract -Raw
                }
                ContractId {
                    # the v3 answer already carries the names of the related items
                    foreach ($V3ItemId in $ContractId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Management/Contract/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Contract ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Contract -Raw:$Raw
                        }
                    }
                }
                ContractName {
                    Search-GlpiToolsItems -SearchFor Contract -SearchType contains -SearchValue $ContractName | ConvertFrom-GlpiToolsV3Item -ItemType Contract -Raw
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
                    uri     = "$($PathToGlpi)/Contract/?range=0-9999999999999"
                }
                
                $ContractsAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($Contract in $ContractsAll) {
                    $ContractHash = [ordered]@{ }
                    $ContractProperties = $Contract.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($ContractProp in $ContractProperties) {
                        $ContractHash.Add($ContractProp.Name, $ContractProp.Value)
                    }
                    $object = [pscustomobject]$ContractHash
                    $ContractsArray.Add($object)
                }
                $ContractsArray
                $ContractsArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            ContractId { 
                foreach ( $CId in $ContractId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Contract/$($CId)"
                    }

                    Try {
                        $Contract = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $ContractHash = [ordered]@{ }
                            $ContractProperties = $Contract.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ContractProp in $ContractProperties) {
                                $ContractHash.Add($ContractProp.Name, $ContractProp.Value)
                            }
                            $object = [pscustomobject]$ContractHash
                            $ContractsArray.Add($object)
                        } else {
                            $ContractHash = [ordered]@{ }
                            $ContractProperties = $Contract.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ContractProp in $ContractProperties) {

                                $ContractPropNewValue = Get-GlpiToolsParameters -Parameter $ContractProp.Name -Value $ContractProp.Value

                                $ContractHash.Add($ContractProp.Name, $ContractPropNewValue)
                            }
                            $object = [pscustomobject]$ContractHash
                            $ContractsArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Contract ID = $CId is not found"
                        
                    }
                    $ContractsArray
                    $ContractsArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            ContractName { 
                Search-GlpiToolsItems -SearchFor Contract -SearchType contains -SearchValue $ContractName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}