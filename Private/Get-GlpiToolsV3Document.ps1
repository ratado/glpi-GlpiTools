<#
.SYNOPSIS
    Downloads the OpenAPI document of the GLPI API v3.
.DESCRIPTION
    Reads /api.php/doc.json of the configured site, which is public. Returns the parsed document,
    or nothing when it cannot be read; the callers treat that as "schema unknown".
.EXAMPLE
    PS C:\> Get-GlpiToolsV3Document
    Returns the OpenAPI document (paths and components) of the configured GLPI.
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    API v3 migration
#>

function Get-GlpiToolsV3Document {
    [CmdletBinding()]
    param ()

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
    $Params = @{
        Uri     = "$(Get-GlpiToolsBaseUrl -Type Site)/api.php/doc.json"
        Method  = 'Get'
        Headers = @{ 'Accept' = 'application/json' }
    }
    if ($GlpiConfig.SkipCertificateCheck) {
        $Params.SkipCertificateCheck = $true
    }
    try {
        Invoke-GlpiToolsRestMethod @Params
    } catch {
        Write-Verbose -Message "The API v3 document could not be read: $($_.Exception.Message)"
    }
}
