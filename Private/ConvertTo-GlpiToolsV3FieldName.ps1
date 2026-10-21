<#
.SYNOPSIS
    Converts a legacy field name used in a filter into the property path of the API v3.
.DESCRIPTION
    A related item column (entities_id) becomes the id of the related object (entity.id), any other mapped
    column becomes the v3 property. Names that are not in the map are returned unchanged.
.PARAMETER ItemType
    Item type of the filter, for example Ticket.
.PARAMETER Name
    Legacy column name.
.EXAMPLE
    PS C:\> ConvertTo-GlpiToolsV3FieldName -ItemType Ticket -Name entities_id
    Returns entity.id.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function ConvertTo-GlpiToolsV3FieldName {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $true)]
        [string]$Name
    )

    $FieldMap = Get-GlpiToolsV3FieldMap -ItemType $ItemType
    # a name that is already a v3 property stays as it is
    if (-not $FieldMap -or ($FieldMap | Where-Object { $_.v3 -eq $Name })) {
        return $Name
    }
    $Field = $FieldMap | Where-Object { $_.v1 -eq $Name } | Select-Object -First 1
    if (-not $Field) {
        return $Name
    }
    if ($Field.kind -eq 'dropdown') {
        return "$($Field.v3).id"
    }
    $Field.v3
}
