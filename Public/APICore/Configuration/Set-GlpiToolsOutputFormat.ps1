<#
.SYNOPSIS
    Changes the output format of the commands when the configuration is for the API v3.
.DESCRIPTION
    Legacy returns the properties and values of the legacy API. Native returns the objects as the API v3
    sends them (related items as objects, v3 property names). Only this field of the configuration file is
    changed, so the credentials do not have to be informed again and the open session is kept.
.PARAMETER Format
    Legacy (default of the module) or Native.
.EXAMPLE
    PS C:\> Set-GlpiToolsOutputFormat -Format Native
    The commands return the objects as the API v3 sends them.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Set-GlpiToolsOutputFormat {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [parameter(Mandatory = $true)]
        [ValidateSet('Legacy', 'Native')]
        [string]$Format
    )

    begin {
        $Config = Get-GlpiToolsConfigPath
    }

    process {
        if (-not (Test-Path -Path $Config)) {
            throw "I cannot find Config File, check if you used Set-GlpiToolsConfig to generate Config"
        }
        # the format exists only for the API v3
        if ((Get-GlpiToolsApiVersion) -ne 'v3') {
            throw "The output format can be changed only when the configuration is for the GLPI API v3."
        }

        # only this field is replaced, the encrypted values are kept as they are
        $ConfigData = Get-Content -Path $Config -Raw | ConvertFrom-Json
        $ConfigData | Add-Member -NotePropertyName 'OutputFormat' -NotePropertyValue $Format -Force
        if ($PSCmdlet.ShouldProcess($Config, "Set the output format to $Format")) {
            $ConfigData | ConvertTo-Json | Out-File -FilePath $Config

            # the stored configuration changed, so the cached copy is discarded
            $script:GlpiToolsConfigCache = $null
        }
    }
}
