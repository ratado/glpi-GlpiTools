<#
.SYNOPSIS
    Returns the API flavour configured for the module.
.DESCRIPTION
    Reads the config file and returns v1 (legacy REST API) or v3 (REST API v3 of GLPI 12).
    Configurations saved before the API v3 support have no ApiVersion field and are v1.
.EXAMPLE
    PS C:\> if ((Get-GlpiToolsApiVersion) -eq 'v3') { ... }
    Branches the request logic by API flavour.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function Get-GlpiToolsApiVersion {
    [CmdletBinding()]
    param ()

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue

    if ($GlpiConfig -and $GlpiConfig.ApiVersion -eq 'v3') {
        'v3'
    } else {
        'v1'
    }
}
