<#
.SYNOPSIS
    Function is getting Locations informations from GLPI
.DESCRIPTION
    Function is based on LocationsID which you can find in GLPI website
    Returns object with property's of Locations
.PARAMETER All
    This parameter will return all Locations from GLPI
.PARAMETER LocationsId
    This parameter can take pipline input, either, you can use this function with -LocationsId keyword.
    Provide to this param Locations ID from GLPI Locations Bookmark
.PARAMETER Raw
    Parameter which you can use with LocationsId Parameter.
    LocationsId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER LocationsName
    This parameter can take pipline input, either, you can use this function with -LocationsName keyword.
    Provide to this param Locations Name from GLPI Locations Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsLocations -All
    Example will return all Locations from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsLocations
    Function gets LocationsId from GLPI from Pipline, and return Locations object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsLocations
    Function gets LocationsId from GLPI from Pipline (u can pass many ID's like that), and return Locations object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsLocations -LocationsId 326
    Function gets LocationsId from GLPI which is provided through -LocationsId after Function type, and return Locations object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsLocations -LocationsId 326, 321
    Function gets LocationsId from GLPI which is provided through -LocationsId keyword after Function type (u can provide many ID's like that), and return Locations object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsLocations -LocationsName Fusion
    Example will return glpi location, but what is the most important, location will be shown exactly as you see in glpi dropdown Locations.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Locations ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Locations from GLPI
.NOTES
    PSP 06/2019
#>

function Get-GlpiToolsDropdownsLocations {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "LocationsId")]
        [alias('LID')]
        [string[]]$LocationsId,
        [parameter(Mandatory = $false,
            ParameterSetName = "LocationsId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "LocationsName")]
        [alias('LN')]
        [string]$LocationsName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $LocationsArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Dropdowns/Location' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Location -Raw
                }
                LocationsId {
                    foreach ($V3ItemId in $LocationsId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Dropdowns/Location/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Location ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Location -Raw
                        }
                    }
                }
                LocationsName {
                    Search-GlpiToolsItems -SearchFor Location -SearchType contains -SearchValue $LocationsName | ConvertFrom-GlpiToolsV3Item -ItemType Location -Raw
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
                    uri     = "$($PathToGlpi)/Location/?range=0-9999999999999"
                }
                
                $GlpiLocationsAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($LocationModel in $GlpiLocationsAll) {
                    $LocationHash = [ordered]@{ }
                    $LocationProperties = $LocationModel.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($LocationProp in $LocationProperties) {
                        $LocationHash.Add($LocationProp.Name, $LocationProp.Value)
                    }
                    $object = [pscustomobject]$LocationHash
                    $LocationsArray.Add($object)
                }
                $LocationsArray
                $LocationsArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            LocationsId { 
                foreach ( $LId in $LocationsId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Location/$($LId)"
                    }

                    Try {
                        $LocationModel = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $LocationHash = [ordered]@{ }
                            $LocationProperties = $LocationModel.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($LocationProp in $LocationProperties) {
                                $LocationHash.Add($LocationProp.Name, $LocationProp.Value)
                            }
                            $object = [pscustomobject]$LocationHash
                            $LocationsArray.Add($object)
                        } else {
                            $LocationHash = [ordered]@{ }
                            $LocationProperties = $LocationModel.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($LocationProp in $LocationProperties) {

                                switch ($LocationProp.Name) {
                                    Default { $LocationPropNewValue = $LocationProp.Value }
                                }

                                $LocationHash.Add($LocationProp.Name, $LocationPropNewValue)
                            }
                            $object = [pscustomobject]$LocationHash
                            $LocationsArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Location ID = $LId is not found"
                        
                    }
                    $LocationsArray
                    $LocationsArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            LocationsName { 
                Search-GlpiToolsItems -SearchFor Location -SearchType contains -SearchValue $LocationsName 
            } 
            Default { }
        }
    }
    
    end {
        
    }
}