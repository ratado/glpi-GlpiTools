<#
.SYNOPSIS
    Function Return the current active profile.
.DESCRIPTION
    Function Return the current active profile.
.EXAMPLE
    PS C:\> Get-GlpiToolsActiveProfile
    Function Return the current active profile.
.INPUTS
    None
.OUTPUTS
    Function returns PSCustomObject with property's of Active Profile current logged user in GLPI
.NOTES
    PSP 04/2019
#>

function Get-GlpiToolsActiveProfile {
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
            (Invoke-GlpiToolsRequest -Method Get -Resource '/session').active_profile
            return
        }

        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/getActiveProfile/"
        }
            
        $ActiveProfile = Invoke-GlpiToolsRequestApi -Params $params

        $ActiveProfile.active_profile
    }
    
    end {
        
    }
}