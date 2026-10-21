<#
.SYNOPSIS
    Function that check if GLPI Plugin is Enable in GLPI
.DESCRIPTION
    Function that check if GLPI Plugin is Enable, if not, will throw error, if yes, will continue fuction execution
.EXAMPLE
    PS C:\> Check-GlpiToolsPluginExist -InvocationCommand "Get-GlpiToolsFusionInventoryAgent"
    Example will return True if plugin is Enabled in GLPI or False if not. \
.PARAMETER InvocationCommand
    Parameter which is used to provide plugin name to check in function
.INPUTS
    InvocationCommand
.OUTPUTS
    Boolean, True if Plugin is Enabled, False if not
.NOTES
    PSP 04/2019
#>

function Check-GlpiToolsPluginExist {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [string]$InvocationCommand
    )
    
    begin {

        # the state is text ("Enabled") in the legacy format and the number 1 in the native format of the API v3
        $GlpiAvailablePlugins = Get-GlpiToolsPlugins | Where-Object { $_.State -eq "Enabled" -or [string]$_.State -eq "1" }

    }
    
    process {

        foreach ($Plugin in $GlpiAvailablePlugins) {
            $name = $Plugin.name -replace " ",""
            if ($InvocationCommand -match $name) {
                $check = " "
            } else {
                
            }
        }

        if ($check) {
            return $true
        } else {
            return $false
        }
    }
    
    end {
        
    }
}