<#
.SYNOPSIS
    Function Return the current active entities.
.DESCRIPTION
    Function Return the current active entities.
.EXAMPLE
    PS C:\> Get-GlpiToolsActiveProfile
    Function Return the current active entities.
.INPUTS
    None
.OUTPUTS
    Function returns PSCustomObject with property's of Active entities current logged user in GLPI
.NOTES
    PSP 04/2019
#>

function Get-GlpiToolsActiveEntities {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
        $SessionToken = $Script:SessionToken
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            $V3Session = Invoke-GlpiToolsRequest -Method Get -Resource '/session'
            $V3Context = $global:GlpiToolsContext
            [pscustomobject][ordered]@{
                'id'                      = $(if ($null -ne $V3Context.EntityId) { $V3Context.EntityId } else { $V3Session.default_entity })
                'active_entity_recursive' = [bool]$V3Context.EntityRecursive
                'selected_entities'       = @($V3Session.active_entities.PSObject.Properties.Name | ForEach-Object { [int]$_ })
            }
            return
        }

        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/getActiveEntities/"
        }
            
        $ActiveEntities = Invoke-GlpiToolsRequestApi -Params $params

        $ActiveEntities.active_entity
    }
    
    end {
        
    }
}