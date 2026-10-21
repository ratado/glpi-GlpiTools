<#
.SYNOPSIS
    Tells from the field map, without any request, whether an item type has a property in the API v3.
.DESCRIPTION
    The maps were built from the schemas of the API, so a type whose map lacks a property does not have it
    (for example the dropdowns have no is_deleted). Returns $true or $false when the type has a map and nothing
    when it has none.
.PARAMETER ItemType
    Item type as used by the module, or another name with the same route.
.PARAMETER Name
    v3 property name.
.EXAMPLE
    PS C:\> Test-GlpiToolsV3MappedProperty -ItemType RSSFeed -Name is_deleted
    Returns False.
.INPUTS
    None
.OUTPUTS
    Boolean
.NOTES
    API v3 migration
#>

function Test-GlpiToolsV3MappedProperty {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $true)]
        [string]$Name
    )

    $FieldMap = Get-GlpiToolsV3FieldMap -ItemType $ItemType -ByRoute
    if (-not $FieldMap) {
        return
    }
    [bool]($FieldMap | Where-Object { $_.v3 -eq $Name })
}
