<#
.SYNOPSIS
    Stops a command that has no equivalent in the GLPI API v3.
.DESCRIPTION
    Throws the standard error used when a cmdlet, or one of its parameters, cannot be run with the
    API v3. There is no fallback to the legacy API.
.PARAMETER Name
    Cmdlet or parameter name shown in the message.
.EXAMPLE
    PS C:\> Assert-GlpiToolsV3Supported -Name 'Get-GlpiToolsListSearchOptions'
    Throws "Get-GlpiToolsListSearchOptions is not supported by the GLPI API v3."
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Assert-GlpiToolsV3Supported {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$Name
    )

    throw "$Name is not supported by the GLPI API v3."
}
