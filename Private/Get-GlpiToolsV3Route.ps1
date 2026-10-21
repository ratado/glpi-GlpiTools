<#
.SYNOPSIS
    Returns the API v3 route of a GLPI item type.
.DESCRIPTION
    Translates the item type names used by the legacy API (Ticket, Computer, Location...) into the
    collection route of the API v3 (/Assistance/Ticket, /Assets/Computer...), using V3Routes.json.
    The map was built from the routes published by the GLPI instance (/api.php/doc.json).
    Item types with no route throw an error, there is no fallback to the legacy API.
.PARAMETER ItemType
    Item type name, case insensitive.
.EXAMPLE
    PS C:\> Get-GlpiToolsV3Route -ItemType Computer
    Returns /Assets/Computer.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function Get-GlpiToolsV3Route {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType
    )

    # the map is read once per session
    if (-not $script:GlpiToolsV3Routes) {
        $RoutesFile = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Private/V3Routes.json'
        $script:GlpiToolsV3Routes = Get-Content -Path $RoutesFile -Raw | ConvertFrom-Json
    }
    $Routes = $script:GlpiToolsV3Routes

    $Route = $Routes.PSObject.Properties[$ItemType.ToLower()].Value
    if (-not $Route) {
        throw "Item type '$ItemType' is not supported by the GLPI API v3."
    }
    $Route
}
