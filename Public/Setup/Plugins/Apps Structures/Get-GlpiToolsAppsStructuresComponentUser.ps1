<#
.SYNOPSIS
    Function to show Apps Structures Users from GLPI
.DESCRIPTION
    Function to show Apps Structures Users from GLPI. Function will show all Users from Apps Structures.
.PARAMETER All
    Switch parameter, if you will choose, you will get All available Apps User.
.PARAMETER AppsStructureComponentUserId
    Int parameter, you can provide here number of Apps Structure User. It is ID which you can find in GLPI or with parameter -All.
    Can take pipeline input.
.PARAMETER Raw
    Switch parameter. In default output has converted id to humanreadable format, that parameter can disable it and return raw object with id's.
.EXAMPLE
    PS C:\> Get-GlpiToolsAppsStructuresComponentUser -All
    Example will show All Apps Structures Users
.EXAMPLE
    PS C:\> Get-GlpiToolsAppsStructuresComponentUser -AppsStructureComponentUserId 2
    Example will show Apps Structure User which id is 2. Object will have converted values.
.EXAMPLE
    PS C:\> Get-GlpiToolsAppsStructuresComponentUser -AppsStructureComponentUserId 2 -Raw
    Example will show Apps Structure User which id is 2. Object will not have converted values.
.EXAMPLE
    PS C:\> 2 | Get-GlpiToolsAppsStructuresComponentUser
    Example will show Apps Structure User which id is 2. Object will have converted values.
.EXAMPLE
    PS C:\> 2 | Get-GlpiToolsAppsStructuresComponentUser -Raw
    Example will show Apps Structure User which id is 2. Object will not have converted values.
.INPUTS
    Inputs (if any)
.OUTPUTS
    Function returns PSCustomObject
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsAppsStructuresComponentUser {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            ParameterSetName = "All")]
        [switch]$All,

        [parameter(Mandatory = $false,
            ValueFromPipeline = $true,
            ParameterSetName = "AppsStructureComponentUserId")]
        [alias('ASCUID')]
        [int[]]$AppsStructureComponentUserId
    )
    
    begin {
        $InvocationCommand = $MyInvocation.MyCommand.Name

        if (Check-GlpiToolsPluginExist -InvocationCommand $InvocationCommand) {

        }
        else {
            throw "You don't have this plugin Enabled in GLPI"
        }

        $SessionToken = $Script:SessionToken
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi
    
        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $ComponentUserArray = [System.Collections.Generic.List[PSObject]]::New()
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
                    uri     = "$($PathToGlpi)/PluginArchiswSwcomponentUser/?range=0-9999999999999"
                }
                
                $GlpiComponentUserAll = Invoke-RestMethod @params -Verbose:$false
        
                foreach ($GlpiComponentUser in $GlpiComponentUserAll) {
                    $ComponentUserHash = [ordered]@{ }
                    $ComponentUserProperties = $GlpiComponentUser.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($ComponentUserProp in $ComponentUserProperties) {
                        $ComponentUserHash.Add($ComponentUserProp.Name, $ComponentUserProp.Value)
                    }
                    $object = [pscustomobject]$ComponentUserHash
                    $ComponentUserArray.Add($object)
                }
                $ComponentUserArray
                $ComponentUserArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            AppsStructureComponentUserId {
                foreach ($ASCUid in $AppsStructureComponentUserId) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/PluginArchiswSwcomponentUser/$($ASCUid)/?range=0-9999999999999"
                    }
                    
                    try {
                        $GlpiComponentUserAll = Invoke-RestMethod @params -Verbose:$false
            
                        foreach ($GlpiComponentUser in $GlpiComponentUserAll) {
                            $ComponentUserHash = [ordered]@{ }
                            $ComponentUserProperties = $GlpiComponentUser.PSObject.Properties | Select-Object -Property Name, Value 
                                        
                            foreach ($ComponentUserProp in $ComponentUserProperties) {
                                $ComponentUserHash.Add($ComponentUserProp.Name, $ComponentUserProp.Value)
                            }
                            $object = [pscustomobject]$ComponentUserHash
                            $ComponentUserArray.Add($object)
                        }
                        $ComponentUserArray
                        $ComponentUserArray = [System.Collections.Generic.List[PSObject]]::New()
                    
                    }
                    catch {
                        Write-Verbose -Message "Component User ID = $ASCUid is not found"
                    }
                }
            }
            Default { }
        }
    }
    
    end {
        
    }
}