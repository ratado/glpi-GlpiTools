<#
.SYNOPSIS
    Function Return the current $CFG_GLPI.
.DESCRIPTION
    Function Return the current $CFG_GLPI.
.EXAMPLE
    PS C:\> Get-GlpiToolsSystemConfig
    Example will show current cfg_glpi configuration.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsSystemConfig {
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
            # the settings come as a list of name/value pairs; credentials are not returned
            $V3Settings = [ordered]@{}
            foreach ($V3Setting in (Invoke-GlpiToolsRequest -Method Get -Resource '/Setup/Config' -All | Where-Object { $_.context -eq 'core' -and $_.name -notmatch 'passw|secret|token|key' })) {
                $V3Settings[$V3Setting.name] = $V3Setting.value
            }
            [pscustomobject]$V3Settings
            return
        }

        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/getGlpiConfig/"
        }
            
        $GlpiConfig = Invoke-GlpiToolsRequestApi -Params $params

        $GlpiConfig.cfg_glpi
    }
    
    end {
        
    }
}