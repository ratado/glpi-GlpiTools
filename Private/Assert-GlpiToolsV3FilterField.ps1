<#
.SYNOPSIS
    Stops a search that filters by a property the API v3 does not have.
.DESCRIPTION
    The API v3 ignores an unknown property in the filter and returns every record, which looks like a
    successful search. This function refuses it, listing the properties of the item type. When the schema
    cannot be read nothing is refused, so a missing document never blocks a search.
.PARAMETER ItemType
    Item type as used by the module, for example Ticket.
.PARAMETER Field
    Property names or dotted paths used by the filter.
.EXAMPLE
    PS C:\> Assert-GlpiToolsV3FilterField -ItemType Ticket -Field name, titulo
    Throws GlpiTools.V3InvalidFilterField naming titulo.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Assert-GlpiToolsV3FilterField {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $false)]
        [string[]]$Field
    )

    # one lookup of the schema serves every field
    $Schema = Get-GlpiToolsV3Schema -ItemType $ItemType
    foreach ($Name in $Field) {
        if ((Test-GlpiToolsV3Property -ItemType $ItemType -Name $Name -Schema $Schema) -eq $false) {
            $Valid = $Schema.Properties.PSObject.Properties.Name -join ', '
            $Hint = Get-GlpiToolsV3FieldHint -ItemType $ItemType -Name $Name -Context Filter
            $Text = "'$Name' is not a property of $ItemType in the GLPI API v3.$Hint Valid properties: $Valid."
            # throwing the record keeps the error ID, which a caller can test
            throw [System.Management.Automation.ErrorRecord]::new([System.ArgumentException]::new($Text), 'GlpiTools.V3InvalidFilterField', [System.Management.Automation.ErrorCategory]::InvalidArgument, $Name)
        }
    }
}
