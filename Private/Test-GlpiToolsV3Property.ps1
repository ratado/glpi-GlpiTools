<#
.SYNOPSIS
    Tells whether a property exists in the API v3 schema of an item type.
.DESCRIPTION
    Accepts dotted paths such as entity.name. Returns $true or $false when the schema answers, and nothing
    when it cannot be determined (document unavailable, or a related item whose schema is not detailed).
.PARAMETER ItemType
    Item type as used by the module, for example Ticket.
.PARAMETER Name
    Property name or dotted path.
.PARAMETER Schema
    Schema already read with Get-GlpiToolsV3Schema, to check several properties with one lookup.
.EXAMPLE
    PS C:\> Test-GlpiToolsV3Property -ItemType Ticket -Name entity.name
    Returns True when Ticket has the property entity with the property name.
.INPUTS
    None
.OUTPUTS
    Boolean
.NOTES
    API v3 migration
#>

function Test-GlpiToolsV3Property {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $true)]
        [string]$Name,

        [parameter(Mandatory = $false)]
        [psobject]$Schema
    )

    if (-not $PSBoundParameters.ContainsKey('Schema')) {
        $Schema = Get-GlpiToolsV3Schema -ItemType $ItemType
    }
    if (-not $Schema -or -not $Schema.Properties) {
        return
    }

    $Properties = $Schema.Properties
    $Segments = $Name.Split('.')
    for ($Index = 0; $Index -lt $Segments.Count; $Index++) {
        $Property = $Properties.PSObject.Properties[$Segments[$Index]]
        if (-not $Property) {
            return $false
        }
        if ($Index -eq $Segments.Count - 1) {
            return $true
        }
        # go one level down: inline properties first, then the full schema of the related item
        $Node = $Property.Value
        if ($Node.type -eq 'array' -and $Node.items) { $Node = $Node.items }
        $Next = $Node.properties
        if (-not $Next -and $Node.'x-full-schema') {
            $Next = $Schema.Schemas.($Node.'x-full-schema').properties
        }
        if (-not $Next) {
            return
        }
        $Properties = $Next
    }
}
