<#
.SYNOPSIS
    Function is getting User Categories informations from GLPI
.DESCRIPTION
    Function is based on UserCategoryId which you can find in GLPI website
    Returns object with property's of User Categories
.PARAMETER All
    This parameter will return all User Categories from GLPI
.PARAMETER UserCategoryId
    This parameter can take pipline input, either, you can use this function with -UserCategoryId keyword.
    Provide to this param UserCategoryId from GLPI User Categories Bookmark
.PARAMETER Raw
    Parameter which you can use with UserCategoryId Parameter.
    UserCategoryId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER UserCategoryName
    This parameter can take pipline input, either, you can use this function with -UserCategoryId keyword.
    Provide to this param User Categories Name from GLPI User Categories Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsUserCategories -All
    Example will return all User Categories from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsUserCategories
    Function gets UserCategoryId from GLPI from Pipline, and return User Categories object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsUserCategories
    Function gets UserCategoryId from GLPI from Pipline (u can pass many ID's like that), and return User Categories object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsUserCategories -UserCategoryId 326
    Function gets UserCategoryId from GLPI which is provided through -UserCategoryId after Function type, and return User Categories object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsUserCategories -UserCategoryId 326, 321
    Function gets User CategoriesId from GLPI which is provided through -UserCategoryId keyword after Function type (u can provide many ID's like that), and return User Categories object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsUserCategories -UserCategoryName Fusion
    Example will return glpi User Categories, but what is the most important, User Categories will be shown exactly as you see in glpi dropdown User Categories.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    User Categories ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of User Categories from GLPI
.NOTES
    PSP 08/2019
#>

function Get-GlpiToolsDropdownsUserCategories {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "UserCategoryId")]
        [alias('UCID')]
        [string[]]$UserCategoryId,
        [parameter(Mandatory = $false,
            ParameterSetName = "UserCategoryId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "UserCategoryName")]
        [alias('UCN')]
        [string]$UserCategoryName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $UserCategoryArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Administration/UserCategory' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType UserCategory -Raw
                }
                UserCategoryId {
                    foreach ($V3ItemId in $UserCategoryId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Administration/UserCategory/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "UserCategory ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType UserCategory -Raw:$Raw
                        }
                    }
                }
                UserCategoryName {
                    Search-GlpiToolsItems -SearchFor Usercategory -SearchType contains -SearchValue $UserCategoryName | ConvertFrom-GlpiToolsV3Item -ItemType UserCategory -Raw
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
                    uri     = "$($PathToGlpi)/UserCategory/?range=0-9999999999999"
                }
                
                $UserCategoriesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($UserCategory in $UserCategoriesAll) {
                    $UserCategoryHash = [ordered]@{ }
                    $UserCategoryProperties = $UserCategory.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($UserCategoryProp in $UserCategoryProperties) {
                        $UserCategoryHash.Add($UserCategoryProp.Name, $UserCategoryProp.Value)
                    }
                    $object = [pscustomobject]$UserCategoryHash
                    $UserCategoryArray.Add($object)
                }
                $UserCategoryArray
                $UserCategoryArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            UserCategoryId { 
                foreach ( $UCId in $UserCategoryId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/UserCategory/$($UCId)"
                    }

                    Try {
                        $UserCategory = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $UserCategoryHash = [ordered]@{ }
                            $UserCategoryProperties = $UserCategory.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($UserCategoryProp in $UserCategoryProperties) {
                                $UserCategoryHash.Add($UserCategoryProp.Name, $UserCategoryProp.Value)
                            }
                            $object = [pscustomobject]$UserCategoryHash
                            $UserCategoryArray.Add($object)
                        } else {
                            $UserCategoryHash = [ordered]@{ }
                            $UserCategoryProperties = $UserCategory.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($UserCategoryProp in $UserCategoryProperties) {

                                $UserCategoryPropNewValue = Get-GlpiToolsParameters -Parameter $UserCategoryProp.Name -Value $UserCategoryProp.Value

                                $UserCategoryHash.Add($UserCategoryProp.Name, $UserCategoryPropNewValue)
                            }
                            $object = [pscustomobject]$UserCategoryHash
                            $UserCategoryArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "User Categories ID = $UCId is not found"
                        
                    }
                    $UserCategoryArray
                    $UserCategoryArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            UserCategoryName { 
                Search-GlpiToolsItems -SearchFor Usercategory -SearchType contains -SearchValue $UserCategoryName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}