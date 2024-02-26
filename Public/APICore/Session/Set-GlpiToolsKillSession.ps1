<#
.SYNOPSIS
    Function which kill API session.
.DESCRIPTION
    Function gets nesessery information from Config file, and Function Set-GlpiToolsInitSession, then kill session.
.PARAMETER SessionToken
    This parameter have to be passed from Set-GlpiToolsInitSession
.EXAMPLE
    PS C:\Users\Wojtek> $SessionToken | Set-GlpiToolsKillSession
    Run command like that and you will kill session with API GLPI
.EXAMPLE
    PS C:\Users\Wojtek> 
    Run command like that and you will kill session with API GLPI
.INPUTS
    SessionToken from Set-GlpiToolsInitSession
.OUTPUTS
    None
.NOTES
    PSP 12/2018
#>

function Set-GlpiToolsKillSession {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [string]$SessionToken
    )
    
    begin {

        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi
		if($null -eq $PSBoundParameters['SessionToken']) {
			$SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
		}
		
    }
    
    process {
        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/killSession/" 
        }
        Invoke-GlpiToolsRequestApi -Params $params | Out-Null
    }
    
    end {
		Set-GlpiToolsSessionToken -ResetToken
    }
}