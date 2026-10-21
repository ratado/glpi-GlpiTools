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
    $Config = Get-GlpiToolsConfigPath

    if (Test-Path -Path $Config) {
        # the answer is reused while the file is unchanged, because every command asks for it several times
        $LastWrite = (Get-Item -Path $Config).LastWriteTimeUtc.Ticks
        $Cached = $script:GlpiToolsApiVersionCache
        if ($Cached -and $Cached.Path -eq $Config -and $Cached.LastWrite -eq $LastWrite) {
            return $Cached.Version
        }
        $Version = 'v1'
        try {
            $ConfigData = Get-Content -Path $Config -Raw | ConvertFrom-Json
            if ($ConfigData.ApiVersion -eq 'v3') { $Version = 'v3' }
        } catch {
            return 'v1'
        }
        $script:GlpiToolsApiVersionCache = @{ Path = $Config; LastWrite = $LastWrite; Version = $Version }
        return $Version
    }
    'v1'
}
