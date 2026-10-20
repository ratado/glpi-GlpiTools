<#
.SYNOPSIS
    Function is getting Project Types informations from GLPI
.DESCRIPTION
    Function is based on ProjectTypeId which you can find in GLPI website
    Returns object with property's of Project Types
.PARAMETER All
    This parameter will return all Project Types from GLPI
.PARAMETER ProjectTypeId
    This parameter can take pipline input, either, you can use this function with -ProjectTypeId keyword.
    Provide to this param ProjectTypeId from GLPI Project Types Bookmark
.PARAMETER Raw
    Parameter which you can use with ProjectTypeId Parameter.
    ProjectTypeId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER ProjectTypeName
    This parameter can take pipline input, either, you can use this function with -ProjectTypeId keyword.
    Provide to this param Project Types Name from GLPI Project Types Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsProjectTypes -All
    Example will return all Project Types from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsProjectTypes
    Function gets ProjectTypeId from GLPI from Pipline, and return Project Types object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsProjectTypes
    Function gets ProjectTypeId from GLPI from Pipline (u can pass many ID's like that), and return Project Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsProjectTypes -ProjectTypeId 326
    Function gets ProjectTypeId from GLPI which is provided through -ProjectTypeId after Function type, and return Project Types object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsProjectTypes -ProjectTypeId 326, 321
    Function gets Project Types Id from GLPI which is provided through -ProjectTypeId keyword after Function type (u can provide many ID's like that), and return Project Types object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsProjectTypes -ProjectTypeName Fusion
    Example will return glpi Project Types, but what is the most important, Project Types will be shown exactly as you see in glpi dropdown Project Types.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Project Types ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Project Types from GLPI
.NOTES
    PSP 09/2019
#>

function Get-GlpiToolsDropdownsProjectTypes {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "ProjectTypeId")]
        [alias('PTID')]
        [string[]]$ProjectTypeId,
        [parameter(Mandatory = $false,
            ParameterSetName = "ProjectTypeId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "ProjectTypeName")]
        [alias('PTN')]
        [string]$ProjectTypeName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $ProjectTypesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Dropdowns/ProjectType' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType ProjectType -Raw
                }
                ProjectTypeId {
                    foreach ($V3ItemId in $ProjectTypeId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Dropdowns/ProjectType/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "ProjectType ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType ProjectType -Raw:$Raw
                        }
                    }
                }
                ProjectTypeName {
                    Search-GlpiToolsItems -SearchFor projecttype -SearchType contains -SearchValue $ProjectTypeName | ConvertFrom-GlpiToolsV3Item -ItemType ProjectType -Raw
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
                    uri     = "$($PathToGlpi)/projecttype/?range=0-9999999999999"
                }
                
                $ProjectTypesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($ProjectType in $ProjectTypesAll) {
                    $ProjectTypeHash = [ordered]@{ }
                    $ProjectTypeProperties = $ProjectType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($ProjectTypeProp in $ProjectTypeProperties) {
                        $ProjectTypeHash.Add($ProjectTypeProp.Name, $ProjectTypeProp.Value)
                    }
                    $object = [pscustomobject]$ProjectTypeHash
                    $ProjectTypesArray.Add($object)
                }
                $ProjectTypesArray
                $ProjectTypesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            ProjectTypeId { 
                foreach ( $PTId in $ProjectTypeId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/projecttype/$($PTId)"
                    }

                    Try {
                        $ProjectType = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $ProjectTypeHash = [ordered]@{ }
                            $ProjectTypeProperties = $ProjectType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ProjectTypeProp in $ProjectTypeProperties) {
                                $ProjectTypeHash.Add($ProjectTypeProp.Name, $ProjectTypeProp.Value)
                            }
                            $object = [pscustomobject]$ProjectTypeHash
                            $ProjectTypesArray.Add($object)
                        } else {
                            $ProjectTypeHash = [ordered]@{ }
                            $ProjectTypeProperties = $ProjectType.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ProjectTypeProp in $ProjectTypeProperties) {

                                $ProjectTypePropNewValue = Get-GlpiToolsParameters -Parameter $ProjectTypeProp.Name -Value $ProjectTypeProp.Value

                                $ProjectTypeHash.Add($ProjectTypeProp.Name, $ProjectTypePropNewValue)
                            }
                            $object = [pscustomobject]$ProjectTypeHash
                            $ProjectTypesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Project Type ID = $PTId is not found"
                        
                    }
                    $ProjectTypesArray
                    $ProjectTypesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            ProjectTypeName { 
                Search-GlpiToolsItems -SearchFor projecttype -SearchType contains -SearchValue $ProjectTypeName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}