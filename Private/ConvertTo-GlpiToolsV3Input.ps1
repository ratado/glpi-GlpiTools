<#
.SYNOPSIS
    Converts legacy field names and values into the ones accepted by the API v3.
.DESCRIPTION
    With OutputFormat Native nothing is converted: the fields must already use the v3 names, and an unknown one
    stops the command with GlpiTools.V3InvalidField.
    The legacy API names a related item by its column (entities_id = 1); the API v3 takes an object
    (entity = @{ id = 1 }). Keys that are already v3 names, and keys with no map entry, are sent as they are,
    so v3 payloads keep working. Item types without a map are returned unchanged.
.PARAMETER ItemType
    Item type of the payload, for example Ticket.
.PARAMETER InputObject
    Hashtable with the fields to send.
.EXAMPLE
    PS C:\> ConvertTo-GlpiToolsV3Input -ItemType Ticket -InputObject @{ name = 'a'; entities_id = 1 }
    Returns @{ name = 'a'; entity = @{ id = 1 } }.
.INPUTS
    None
.OUTPUTS
    System.Collections.Hashtable
.NOTES
    API v3 migration
#>

function ConvertTo-GlpiToolsV3Input {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$InputObject
    )

    # the native format sends the fields as given, but refuses the ones the API v3 does not know, since it would ignore them silently
    if ((Get-GlpiToolsOutputFormat) -eq 'Native') {
        foreach ($Key in $InputObject.Keys) {
            if ((Test-GlpiToolsV3Property -ItemType $ItemType -Name ([string]$Key)) -eq $false) {
                $Text = "'$Key' is not a property of $ItemType in the GLPI API v3.$(Get-GlpiToolsV3FieldHint -ItemType $ItemType -Name ([string]$Key) -Context Body)"
                # throwing the record keeps the error ID, which a caller can test
                throw [System.Management.Automation.ErrorRecord]::new([System.ArgumentException]::new($Text), 'GlpiTools.V3InvalidField', [System.Management.Automation.ErrorCategory]::InvalidArgument, $Key)
            }
        }
        return $InputObject
    }

    $FieldMap = Get-GlpiToolsV3FieldMap -ItemType $ItemType
    if (-not $FieldMap) {
        Write-Verbose -Message "There is no field map for '$ItemType'; the fields are sent as given."
        return $InputObject
    }

    # a related item is sent as an object with the id, whatever form the legacy value had
    $ToRelation = {
        param($Value)
        if ($Value -is [System.Collections.IDictionary] -or $Value -is [pscustomobject]) { return $Value }
        if ("$Value" -match '^\d+$') { return @{ id = [int]$Value } }
        $Value
    }

    $Result = @{ }
    foreach ($Key in $InputObject.Keys) {
        $Value = $InputObject[$Key]
        # a key that is already a v3 name is not touched
        if ($FieldMap | Where-Object { $_.v3 -eq $Key }) {
            $Result[$Key] = $Value
            continue
        }
        $Field = $FieldMap | Where-Object { $_.v1 -eq $Key } | Select-Object -First 1
        if (-not $Field) {
            $Result[$Key] = $Value
            continue
        }
        $Result[$Field.v3] = switch ($Field.kind) {
            'dropdown' { & $ToRelation $Value }
            'list' { , @($Value | ForEach-Object { & $ToRelation $_ }) }
            'bool' { if ("$Value" -match '^[01]$') { [bool][int]"$Value" } else { $Value } }
            default { $Value }
        }
    }
    $Result
}
