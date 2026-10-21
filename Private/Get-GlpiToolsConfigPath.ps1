<#
.SYNOPSIS
    Returns the path of the configuration file of the module.
.DESCRIPTION
    The file is Configuration.json inside GlpiToolsConfig, under $env:HOME/.config on Linux and under
    $env:LOCALAPPDATA on Windows.
.EXAMPLE
    PS C:\> Get-GlpiToolsConfigPath
    Returns the full path of Configuration.json.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function Get-GlpiToolsConfigPath {
    [CmdletBinding()]
    param ()

    if ($IsLinux) {
        Join-Path -Path "$env:HOME/.config/GlpiToolsConfig\" -ChildPath 'Configuration.json'
    } else {
        Join-Path -Path "$env:LOCALAPPDATA\GlpiToolsConfig\" -ChildPath 'Configuration.json'
    }
}
