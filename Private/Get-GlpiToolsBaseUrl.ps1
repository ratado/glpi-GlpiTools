<#
.SYNOPSIS
    Builds the URLs of the configured GLPI API.
.DESCRIPTION
    For API v3 the PathToGlpi stored in the config may be the site URL or the full API URL
    (.../api.php/v3.0). This function normalizes it and returns the requested URL.
    For the legacy API it returns the stored PathToGlpi unchanged.
.PARAMETER Type
    Api returns the base URL of the API; Token returns the OAuth token endpoint; Site returns the site URL.
.EXAMPLE
    PS C:\> Get-GlpiToolsBaseUrl -Type Token
    Returns https://glpi.example.com/api.php/token for a v3 configuration.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function Get-GlpiToolsBaseUrl {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [ValidateSet('Api', 'Token', 'Site')]
        [string]$Type = 'Api'
    )

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
    $Path = [string]$GlpiConfig.PathToGlpi

    # the legacy API uses the stored URL as it is
    if ($GlpiConfig.ApiVersion -ne 'v3') {
        return $Path
    }

    # reduce the stored value to the site URL, whether it is the site or the full API address
    $Site = $Path.Trim().TrimEnd('/') -replace '/api\.php(/v[0-9.]+)?(/token)?$', ''

    switch ($Type) {
        'Site' { $Site }
        'Token' { "$Site/api.php/token" }
        default { "$Site/api.php/v3.0" }
    }
}
