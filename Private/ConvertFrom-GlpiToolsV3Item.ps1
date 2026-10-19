<#
.SYNOPSIS
    Converts an item returned by the API v3 into the object format returned by the legacy API.
.DESCRIPTION
    Uses V3FieldMap.json to rename the properties, flatten the related items (object with id and name)
    and format dates and booleans exactly as the legacy API does. With -Raw the related items become
    their ID; without it, they become the name that the legacy conversion shows. Properties without
    an equivalent in the legacy API are left out, except the ones starting with an underscore
    (added by the cmdlets) and the team of the item, which are appended at the end.
.PARAMETER InputObject
    Item returned by the API v3.
.PARAMETER ItemType
    Key of the field map, for example Ticket.
.PARAMETER Raw
    Keeps the related items as ID, like -Raw of the cmdlets.
.EXAMPLE
    PS C:\> Invoke-GlpiToolsRequest -Method Get -Resource /Assistance/Ticket/2 | ConvertFrom-GlpiToolsV3Item -ItemType Ticket -Raw
    Returns the ticket 2 with the properties of the legacy API and IDs in the related items.
.INPUTS
    Item returned by the API v3
.OUTPUTS
    PSCustomObject with the properties of the legacy API
.NOTES
    API v3 migration
#>

function ConvertFrom-GlpiToolsV3Item {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true)]
        [psobject]$InputObject,

        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $false)]
        [switch]$Raw
    )

    begin {
        # the field map is read once per session
        if (-not $script:GlpiToolsV3FieldMap) {
            $MapFile = Join-Path -Path $MyInvocation.MyCommand.Module.ModuleBase -ChildPath 'Private/V3FieldMap.json'
            $script:GlpiToolsV3FieldMap = Get-Content -Path $MapFile -Raw | ConvertFrom-Json
        }
        $FieldMap = $script:GlpiToolsV3FieldMap.$ItemType
        if (-not $FieldMap) {
            throw "There is no field map for the item type '$ItemType'."
        }
    }

    process {
        $Item = [ordered]@{ }
        foreach ($Field in $FieldMap) {
            # a property missing in the answer has no equivalent value, so it is not invented
            if ($null -eq $InputObject.PSObject.Properties[$Field.v3]) { continue }
            $Value = $InputObject.($Field.v3)

            switch ($Field.kind) {
                date {
                    # the wall time of the ISO 8601 text is kept, as the legacy API shows the server time
                    if ($Value -is [datetime]) {
                        $Value = $Value.ToString('yyyy-MM-dd HH:mm:ss', [cultureinfo]::InvariantCulture)
                    } elseif ($Value -match '^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})') {
                        $Value = "$($Matches[1]) $($Matches[2])"
                    }
                }
                bool {
                    $Value = [int][bool]$Value
                }
                decimal {
                    # the legacy API sends decimals as text with four places
                    if ($null -ne $Value -and "$Value" -ne '') {
                        $Value = ([decimal]$Value).ToString('0.0000', [cultureinfo]::InvariantCulture)
                    }
                }
                dropdown {
                    $Value = ConvertTo-GlpiToolsV3Relation -Relation $Value -Named $Field.named -Raw:$Raw
                }
                list {
                    # a list of relations becomes a list of IDs or names
                    $Value = @($Value | ForEach-Object { ConvertTo-GlpiToolsV3Relation -Relation $_ -Named $Field.named -Raw:$Raw })
                }
            }
            $Item[$Field.v1] = $Value
        }

        # the team has no legacy counterpart but is useful, so it is appended
        if ($null -ne $InputObject.PSObject.Properties['team']) {
            $Item['team'] = $InputObject.team
        }
        # properties added by the cmdlets are kept
        foreach ($Property in $InputObject.PSObject.Properties) {
            if ($Property.Name.StartsWith('_')) { $Item[$Property.Name] = $Property.Value }
        }

        [pscustomobject]$Item
    }
}
