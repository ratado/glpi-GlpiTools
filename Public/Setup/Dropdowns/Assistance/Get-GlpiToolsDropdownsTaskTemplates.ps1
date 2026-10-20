<#
.SYNOPSIS
    Function is getting Task Templates informations from GLPI
.DESCRIPTION
    Function is based on TaskTemplateId which you can find in GLPI website
    Returns object with property's of Task Templates
.PARAMETER All
    This parameter will return all Task Templates from GLPI
.PARAMETER TaskTemplateId
    This parameter can take pipline input, either, you can use this function with -TaskTemplateId keyword.
    Provide to this param TaskTemplateId from GLPI Task Templates Bookmark
.PARAMETER Raw
    Parameter which you can use with TaskTemplateId Parameter.
    TaskTemplateId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER TaskTemplateName
    This parameter can take pipline input, either, you can use this function with -TaskTemplateId keyword.
    Provide to this param Task Templates Name from GLPI Task Templates Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsTaskTemplates -All
    Example will return all Task Templates from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsDropdownsTaskTemplates
    Function gets TaskTemplateId from GLPI from Pipline, and return Task Templates object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsDropdownsTaskTemplates
    Function gets TaskTemplateId from GLPI from Pipline (u can pass many ID's like that), and return Task Templates object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsTaskTemplates -TaskTemplateId 326
    Function gets TaskTemplateId from GLPI which is provided through -TaskTemplateId after Function type, and return Task Templates object
.EXAMPLE 
    PS C:\> Get-GlpiToolsDropdownsTaskTemplates -TaskTemplateId 326, 321
    Function gets Task Templates Id from GLPI which is provided through -TaskTemplateId keyword after Function type (u can provide many ID's like that), and return Task Templates object
.EXAMPLE
    PS C:\> Get-GlpiToolsDropdownsTaskTemplates -TaskTemplateName Fusion
    Example will return glpi Task Templates, but what is the most important, Task Templates will be shown exactly as you see in glpi dropdown Task Templates.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Task Templates ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Task Templates from GLPI
.NOTES
    PSP 09/2019
#>

function Get-GlpiToolsDropdownsTaskTemplates {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "TaskTemplateId")]
        [alias('TTID')]
        [string[]]$TaskTemplateId,
        [parameter(Mandatory = $false,
            ParameterSetName = "TaskTemplateId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "TaskTemplateName")]
        [alias('TTN')]
        [string]$TaskTemplateName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $TaskTemplateArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Dropdowns/TaskTemplate' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType TaskTemplate -Raw
                }
                TaskTemplateId {
                    foreach ($V3ItemId in $TaskTemplateId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Dropdowns/TaskTemplate/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "TaskTemplate ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names only where the legacy command converts them
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType TaskTemplate -Raw:$Raw
                        }
                    }
                }
                TaskTemplateName {
                    Search-GlpiToolsItems -SearchFor tasktemplate -SearchType contains -SearchValue $TaskTemplateName | ConvertFrom-GlpiToolsV3Item -ItemType TaskTemplate -Raw
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
                    uri     = "$($PathToGlpi)/tasktemplate/?range=0-9999999999999"
                }
                
                $TaskTemplateAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($TaskTemplate in $TaskTemplateAll) {
                    $TaskTemplateHash = [ordered]@{ }
                    $TaskTemplateProperties = $TaskTemplate.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($TaskTemplateProp in $TaskTemplateProperties) {
                        $TaskTemplateHash.Add($TaskTemplateProp.Name, $TaskTemplateProp.Value)
                    }
                    $object = [pscustomobject]$TaskTemplateHash
                    $TaskTemplateArray.Add($object)
                }
                $TaskTemplateArray
                $TaskTemplateArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            TaskTemplateId { 
                foreach ( $TTId in $TaskTemplateId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/tasktemplate/$($TTId)"
                    }

                    Try {
                        $TaskTemplate = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $TaskTemplateHash = [ordered]@{ }
                            $TaskTemplateProperties = $TaskTemplate.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($TaskTemplateProp in $TaskTemplateProperties) {
                                $TaskTemplateHash.Add($TaskTemplateProp.Name, $TaskTemplateProp.Value)
                            }
                            $object = [pscustomobject]$TaskTemplateHash
                            $TaskTemplateArray.Add($object)
                        } else {
                            $TaskTemplateHash = [ordered]@{ }
                            $TaskTemplateProperties = $TaskTemplate.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($TaskTemplateProp in $TaskTemplateProperties) {

                                $TaskTemplatePropNewValue = Get-GlpiToolsParameters -Parameter $TaskTemplateProp.Name -Value $TaskTemplateProp.Value

                                $TaskTemplateHash.Add($TaskTemplateProp.Name, $TaskTemplatePropNewValue)
                            }
                            $object = [pscustomobject]$TaskTemplateHash
                            $TaskTemplateArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Task Template ID = $TTId is not found"
                        
                    }
                    $TaskTemplateArray
                    $TaskTemplateArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            TaskTemplateName { 
                Search-GlpiToolsItems -SearchFor tasktemplate -SearchType contains -SearchValue $TaskTemplateName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}