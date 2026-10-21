<#
.SYNOPSIS
    Returns the version of the running PowerShell.
.DESCRIPTION
    Thin wrapper over $PSVersionTable so that the version can be replaced in tests.
.EXAMPLE
    PS C:\> Get-GlpiToolsPowerShellVersion
    Returns the PowerShell version, for example 7.4.1.
.INPUTS
    None
.OUTPUTS
    System.Version
.NOTES
    API v3 migration
#>

function Get-GlpiToolsPowerShellVersion {
    [CmdletBinding()]
    param ()

    [version]$PSVersionTable.PSVersion.ToString().Split('-')[0]
}
