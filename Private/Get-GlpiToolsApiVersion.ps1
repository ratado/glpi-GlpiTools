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

    # only the plain ApiVersion field is read, so no secret is decrypted on every call
    if ($IsLinux) {
        $Config = Join-Path -Path "$env:HOME/.config/GlpiToolsConfig\" -ChildPath 'Configuration.json'
    } else {
        $Config = Join-Path -Path "$env:LOCALAPPDATA\GlpiToolsConfig\" -ChildPath 'Configuration.json'
    }

    if (Test-Path -Path $Config) {
        try {
            $ConfigData = Get-Content -Path $Config -Raw | ConvertFrom-Json
        } catch {
            return 'v1'
        }
        if ($ConfigData.ApiVersion -eq 'v3') {
            return 'v3'
        }
    }
    'v1'
}
