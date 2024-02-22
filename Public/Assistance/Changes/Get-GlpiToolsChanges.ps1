<#
.SYNOPSIS
    Function is getting Change informations from GLPI
.DESCRIPTION
    Function is based on ChangeID which you can find in GLPI website
    Returns object with property's of Change
.PARAMETER All
    This parameter will return all Changes from GLPI
.PARAMETER ChangeId
    This parameter can take pipline input, either, you can use this function with -ChangeId keyword.
    Provide to this param Change ID from GLPI Changes Bookmark
.PARAMETER Raw
    Parameter which you can use with ChangeId Parameter.
    ChangeId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER ChangeName
    Provide to this param Change Name from GLPI Changes Bookmark
.PARAMETER SearchInTrash
    Parameter which you can use with ChangeName Parameter.
    If you want Search for Change name in trash, that parameter allow you to do it.
.PARAMETER Parameter
    Parameter which you can use with ChangeId Parameter. 
    If you want to get additional parameter of Change object like, disks, or logs, use this parameter.
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsChanges
    Function gets ChangeID from GLPI from Pipline, and return Change object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsChanges
    Function gets ChangeID from GLPI from Pipline (u can pass many ID's like that), and return Change object
.EXAMPLE
    PS C:\> Get-GlpiToolsChanges -ChangeId 326
    Function gets ChangeID from GLPI which is provided through -ChangeId after Function type, and return Change object
.EXAMPLE 
    PS C:\> Get-GlpiToolsChanges -ChangeId 326, 321
    Function gets ChangeID from GLPI which is provided through -ChangeId keyword after Function type (u can provide many ID's like that), and return Change object
.EXAMPLE
    PS C:\> Get-GlpiToolsChanges -ChangeId 234 -Raw
    Example will show Change with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> 234 | Get-GlpiToolsChanges -Raw
    Example will show Change with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> Get-GlpiToolsChanges -ChangeName glpi
    Example will return glpi Change, but what is the most important, Change will be shown exacly as you see in glpi Changes tab.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.EXAMPLE
    PS C:\> Get-GlpiToolsChanges -ChangeName glpi -SearchInTrash Yes
    Example will return glpi Change, but from trash
.INPUTS
    Change ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Changes from GLPI
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsChanges {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,

        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "ChangeId")]
        [alias('CID')]
        [string[]]$ChangeId,
        [parameter(Mandatory = $false,
            ParameterSetName = "ChangeId")]
        [switch]$Raw,

        [parameter(Mandatory = $true,
            ParameterSetName = "ChangeName")]
        [alias('CN')]
        [string]$ChangeName,
        [parameter(Mandatory = $false,
            ParameterSetName = "ChangeName")]
        [alias('SIT')]
        [ValidateSet("Yes", "No")]
        [string]$SearchInTrash = "No",

        [parameter(Mandatory = $false,
            ParameterSetName = "ChangeId")]
        [alias('Param')]
        [ValidateSet("ExpandDropdowns",
            "GetHateoas",
            "GetSha1",
            "WithDevices",
            "WithInfocoms",
            "WithContracts",
            "WithDocuments",
            "WithChanges",
            "WithChanges",
            "WithChanges",
            "WithNotes",
            "WithLogs")]
        [string]$Parameter
    )
    
    begin {

        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi
        $SessionToken = $Script:SessionToken

        $AppToken = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty PathToGlpi
        $SessionToken = Get-GlpiToolsSessionToken -Verbose:$false | Select-Object -ExpandProperty SessionToken

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $ChangeObjectArray = [System.Collections.Generic.List[PSObject]]::New()

        switch ($Parameter) {
            ExpandDropdowns { $ParamValue = "?expand_dropdowns=true" }
            GetHateoas { $ParamValue = "?get_hateoas=true" }
            GetSha1 { $ParamValue = "?get_sha1=true" }
            WithDevices { $ParamValue = "?with_devices=true" }
            WithInfocoms { $ParamValue = "?with_infocoms=true" }
            WithContracts { $ParamValue = "?with_contracts=true" }
            WithDocuments { $ParamValue = "?with_documents=true" }
            WithChanges { $ParamValue = "?with_Changes=true" } 
            WithChanges { $ParamValue = "?with_Changes=true" }
            WithChanges { $ParamValue = "?with_changes=true" }
            WithNotes { $ParamValue = "?with_notes=true" } 
            WithLogs { $ParamValue = "?with_logs=true" }
            Default { $ParamValue = "" }
        }

    }
    
    process {
        switch ($ChoosenParam) {
            All { 
                $params = @{
                    headers = @{
                        'Content-Type'  = 'application/json'
                        'App-Token'     = $AppToken
                        'Session-Token' = $SessionToken
                    }
                    method  = 'get'
                    uri     = "$($PathToGlpi)/Change/?range=0-9999999999999"
                }
                
                $GlpiChangeAll = Invoke-RestMethod @params -Verbose:$false

                foreach ($GlpiChange in $GlpiChangeAll) {
                    $ChangeHash = [ordered]@{ }
                            $ChangeProperties = $GlpiChange.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ChangeProp in $ChangeProperties) {
                                $ChangeHash.Add($ChangeProp.Name, $ChangeProp.Value)
                            }
                            $object = [pscustomobject]$ChangeHash
                            $ChangeObjectArray.Add($object)
                }
                $ChangeObjectArray
                $ChangeObjectArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            ChangeId { 
                foreach ( $CId in $ChangeId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Change/$($CId)$ParamValue"
                    }

                    Try {
                        $GlpiChange = Invoke-RestMethod @params -ErrorAction Stop

                        if ($Raw) {
                            $ChangeHash = [ordered]@{ }
                            $ChangeProperties = $GlpiChange.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ChangeProp in $ChangeProperties) {
                                $ChangeHash.Add($ChangeProp.Name, $ChangeProp.Value)
                            }
                            $object = [pscustomobject]$ChangeHash
                            $ChangeObjectArray.Add($object)
                        } else {
                            $ChangeHash = [ordered]@{ }
                            $ChangeProperties = $GlpiChange.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ChangeProp in $ChangeProperties) {

                                $ChangePropNewValue = Get-GlpiToolsParameters -Parameter $ChangeProp.Name -Value $ChangeProp.Value

                                $ChangeHash.Add($ChangeProp.Name, $ChangePropNewValue)
                            }
                            $object = [pscustomobject]$ChangeHash
                            $ChangeObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Change ID = $CId is not found"
                        
                    }
                    $ChangeObjectArray
                    $ChangeObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            ChangeName { 
                Search-GlpiToolsItems -SearchFor Change -SearchType contains -SearchValue $ChangeName -SearchInTrash $SearchInTrash
            }
            Default {
                
            }
        }
    }
    
    end {
    
    }
}