<#
.SYNOPSIS
    Suggests the API v3 name of a field written with its legacy name.
.DESCRIPTION
    When the name is a legacy column in the field map of the item type, returns a short sentence with the v3
    name (entities_id becomes entity.id in a filter, and entity in a body). Returns an empty string otherwise.
.PARAMETER ItemType
    Item type of the field, for example Ticket.
.PARAMETER Name
    Name as the caller wrote it.
.PARAMETER Context
    Filter when the name is used to search, Body when it is sent to create or change an item.
.EXAMPLE
    PS C:\> Get-GlpiToolsV3FieldHint -ItemType Ticket -Name entities_id -Context Filter
    Returns " Did you mean 'entity.id'?".
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function Get-GlpiToolsV3FieldHint {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $true)]
        [string]$Name,

        [parameter(Mandatory = $true)]
        [ValidateSet('Filter', 'Body')]
        [string]$Context
    )

    $FieldMap = Get-GlpiToolsV3FieldMap -ItemType $ItemType
    $Field = $FieldMap | Where-Object { $_.v1 -eq $Name } | Select-Object -First 1
    if (-not $Field) {
        return ''
    }
    if ($Field.kind -eq 'dropdown' -and $Context -eq 'Filter') {
        return " Did you mean '$($Field.v3).id'?"
    }
    if ($Field.kind -eq 'dropdown') {
        return " Did you mean '$($Field.v3)' (an object such as @{ id = 1 })?"
    }
    " Did you mean '$($Field.v3)'?"
}
