<#
.SYNOPSIS
    Function Return all the Entities associated to logged user.
.DESCRIPTION
    Function Return all the Entities associated to logged user.
.PARAMETER IsRecursive
    This parameter will enable display sub entities of the active entity. Parameter is optional
.EXAMPLE
    PS C:\> Get-GlpiToolsMyEntities
    Command Return all the Entities associated to logged user.
.INPUTS
    None
.OUTPUTS
    Function returns PSCustomObject with property's of Entities results from GLPI
.NOTES
    PSP 04/2019
#>

function Get-GlpiToolsMyEntities {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [alias('IR')]
        [switch]$IsRecursive
    )
    
    begin {
        $SessionToken = $Script:SessionToken
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $EntitiesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            if ($IsRecursive) {
                # every entity of the tree the user can see
                $V3Flatten = {
                    param($Nodes)
                    foreach ($Node in $Nodes) {
                        [pscustomobject][ordered]@{ 'id' = $Node.key; 'name' = $Node.label }
                        & $V3Flatten $Node.children
                    }
                }
                & $V3Flatten (Invoke-GlpiToolsRequest -Method Get -Resource '/Session/EntityTree' -NoContext)
            } else {
                # only the entities directly assigned to the profiles of the user
                $V3Session = Invoke-GlpiToolsRequest -Method Get -Resource '/session' -NoContext
                $V3Session.profiles.PSObject.Properties.Value.entities | Sort-Object -Property id -Unique | ForEach-Object {
                    [pscustomobject][ordered]@{ 'id' = $_.id; 'name' = $_.name }
                }
            }
            return
        }

		
		if ($IsRecursive) {
            $IsRecursiveState = "true"
        } else {
            $IsRecursiveState = "false"
        }

        $GetActiveEntities = @{
            'is_recursive'    = $IsRecursiveState
        } 


		
        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'GET'
            uri     = "$($PathToGlpi)/getMyEntities/"
			body	= $GetActiveEntities
        }
  
        $MyEntities = Invoke-GlpiToolsRequestApi -Params $params

        foreach ($GlpiEntities in $MyEntities.myentities) {
            $EntitiesHash = [ordered]@{ }
                    $EntitiesProperties = $GlpiEntities.PSObject.Properties | Select-Object -Property Name, Value 
                        
                    foreach ($EntitiesProp in $EntitiesProperties) {
                        $EntitiesHash.Add($EntitiesProp.Name, $EntitiesProp.Value)
                    }
                    $object = [pscustomobject]$EntitiesHash
                    $EntitiesArray.Add($object)
        }
        $EntitiesArray
        $EntitiesArray = [System.Collections.Generic.List[PSObject]]::New()
		
    }
    
    end {
        
    }
}