<#
.SYNOPSIS
    Returns the path of the configuration file of the module.
.DESCRIPTION
    The file is Configuration.json inside GlpiToolsConfig, under $env:HOME/.config on Linux and under
    $env:LOCALAPPDATA on Windows. It is the only place that knows the location of the configuration.
.PARAMETER Directory
    Returns the folder that holds the file instead of the file.
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
    param (
        [parameter(Mandatory = $false)]
        [switch]$Directory
    )

    if ($IsLinux) {
        $ConfigPath = "$env:HOME/.config/GlpiToolsConfig\"
    } else {
        $ConfigPath = "$env:LOCALAPPDATA\GlpiToolsConfig\"
    }
    if ($Directory) {
        return $ConfigPath
    }
    Join-Path -Path $ConfigPath -ChildPath 'Configuration.json'
}
