<#
.SYNOPSIS
    Returns the field map of an item type of the API v3.
.DESCRIPTION
    Reads V3FieldMap.json once per session and returns the entries (v3 name, legacy name and kind)
    of the item type, or nothing when the type has no map.
.PARAMETER ItemType
    Item type as used by the module, for example Ticket.
.PARAMETER ByRoute
    When the name has no map of its own, uses the map of another name that has the same route in the API v3
    (ticketrecurrent finds the map of RecurringTicket).
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
        [string]$ItemType,

        [parameter(Mandatory = $false)]
        [switch]$ByRoute
    )

    if (-not $script:GlpiToolsV3FieldMap) {
        $MapFile = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Private/V3FieldMap.json'
        $script:GlpiToolsV3FieldMap = Get-Content -Path $MapFile -Raw | ConvertFrom-Json
    }
    $Map = $script:GlpiToolsV3FieldMap.$ItemType
    if ($Map -or -not $ByRoute) {
        return $Map
    }

    # a name with no route has no alias either
    try {
        $Route = Get-GlpiToolsV3Route -ItemType $ItemType
    } catch {
        return
    }
    foreach ($Alias in $script:GlpiToolsV3Routes.PSObject.Properties) {
        if ($Alias.Value -eq $Route -and $script:GlpiToolsV3FieldMap.PSObject.Properties[$Alias.Name]) {
            return $script:GlpiToolsV3FieldMap.($Alias.Name)
        }
    }
}
