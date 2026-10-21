<#
.SYNOPSIS
    Converts a related item of the API v3 into the value shown by the legacy API.
.DESCRIPTION
    A relation of the API v3 is an object with id and name. With -Raw, or when the legacy API
    leaves the field as ID, the result is the ID; otherwise it is the requested name property.
    An empty relation is 0 for an ID and an empty value for a name.
.PARAMETER Relation
    Object of the API v3 with the id and the names, or null.
.PARAMETER Named
    Property used as name: id, name, completename or username.
.PARAMETER Raw
    Returns the ID.
.EXAMPLE
    PS C:\> ConvertTo-GlpiToolsV3Relation -Relation $Ticket.entity -Named completename
    Returns the complete name of the entity.
.INPUTS
    None
.OUTPUTS
    Integer or string
.NOTES
    API v3 migration
#>

function ConvertTo-GlpiToolsV3Relation {
    [CmdletBinding()]
    param (
        $Relation,
        [string]$Named,
        [switch]$Raw
    )

    # the legacy API shows an empty relation as 0 (ID) or as an empty value (name)
    if ($Raw -or $Named -eq 'id') {
        if ($null -eq $Relation) { return 0 }
        return [int]$Relation.id
    }
    if ($null -eq $Relation) { return $null }
    # the complete name is used when the item has one, otherwise the plain name
    $Name = $Relation.$Named
    if ($null -eq $Name -and $Named -eq 'completename') { $Name = $Relation.name }
    $Name
}
