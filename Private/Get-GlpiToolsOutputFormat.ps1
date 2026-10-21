<#
.SYNOPSIS
    Returns the output format of the commands: Legacy or Native.
.DESCRIPTION
    Native is returned only when the configuration is for the API v3 and OutputFormat is Native. Every other
    case, including configurations written by older versions, is Legacy. It is the single place that decides
    the format, so the commands do not repeat the check.
.EXAMPLE
    PS C:\> Get-GlpiToolsOutputFormat
    Returns Legacy or Native.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function Get-GlpiToolsOutputFormat {
    [CmdletBinding()]
    param ()

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
    if ($GlpiConfig.ApiVersion -eq 'v3' -and $GlpiConfig.OutputFormat -eq 'Native') {
        return 'Native'
    }
    'Legacy'
}
