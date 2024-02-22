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
        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/getActiveEntities/"
        }
            
        $ActiveEntities = Invoke-RestMethod @params

        $ActiveEntities.active_entity
    }
    
    end {
        
    }
}