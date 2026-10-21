<#
.SYNOPSIS
    Returns the field map of an item type of the API v3.
.DESCRIPTION
    Reads V3FieldMap.json once per session and returns the entries (v3 name, legacy name and kind)
    of the item type, or nothing when the type has no map.
.PARAMETER ItemType
    Item type as used by the module, for example Ticket.
.EXAMPLE
    PS C:\> Get-GlpiToolsV3FieldMap -ItemType Computer
    Returns the fields of the Computer map.
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    API v3 migration
#>

function Get-GlpiToolsV3FieldMap {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType
    )

    if (-not $script:GlpiToolsV3FieldMap) {
        $MapFile = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Private/V3FieldMap.json'
        $script:GlpiToolsV3FieldMap = Get-Content -Path $MapFile -Raw | ConvertFrom-Json
    }
    $script:GlpiToolsV3FieldMap.$ItemType
}
