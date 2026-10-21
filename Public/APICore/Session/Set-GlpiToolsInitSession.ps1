<#
.SYNOPSIS
    Function which init API session.
.DESCRIPTION
    Function gets nesessery information from Config file, then initialize session, and return object with session_token property.
    With API v3 it requests an OAuth access token (password grant) instead and keeps it, with its expiry, as the session.
.EXAMPLE
    PS C:\Users\Wojtek> Set-GlpiToolsInitSession
    Run command like that and you will initiate session with API GLPI
.INPUTS
    None, inside script Function uses Get-GlpiToolsConfig to get data from Config. 
.OUTPUTS
    SessionToken parameter
.NOTES
    PSP 12/2018
#>

function Set-GlpiToolsInitSession {
    [CmdletBinding()]
    param (
        
    )
    
    begin {

        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $UserToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty UserToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi
    }
    
    process {
        # API v3: OAuth password grant, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            $SessionToken = Update-GlpiToolsAccessToken -NewSession
            return
        }

        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'Authorization' = "user_token $($UserToken)"
                'App-Token'     = $AppToken 
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/initSession/" 
        }
        $InitSession = Invoke-GlpiToolsRequestApi -Params $params
        
        $SessionHash = [ordered]@{
            'SessionToken' = $InitSession.session_token
        }
        $object = New-Object -TypeName PSCustomObject -Property $SessionHash
        $SessionToken += $object
		
		Set-GlpiToolsSessionToken -SessionToken $InitSession.session_token
        
    }
    
    end {
        $SessionToken
    }
}