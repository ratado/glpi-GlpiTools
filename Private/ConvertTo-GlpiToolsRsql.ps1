<#
.SYNOPSIS
    Builds an RSQL filter for the API v3.
.DESCRIPTION
    Converts criteria into the RSQL string accepted by the filter parameter of the API v3 listings.
    Values are escaped following the GLPI RSQL lexer (; , ( ) and backslash), and property names are
    validated, so user input cannot add criteria to the filter.
.PARAMETER Criteria
    Criteria as hashtables with Field, Operator (default equals) and Value. Optional Link (AND or OR)
    tells how the criterion is joined to the previous one; the default is AND.
    Operators: equals, notequals, contains, startswith, endswith, lt, le, gt, ge, in, out, isnull, notnull.
.PARAMETER Filter
    Shortcut for equality criteria, joined by AND. Example: @{ name = 'foo'; is_deleted = 0 }.
.EXAMPLE
    PS C:\> ConvertTo-GlpiToolsRsql -Criteria @{ Field = 'name'; Operator = 'contains'; Value = 'DC' }
    Returns name=ilike=*DC*
.EXAMPLE
    PS C:\> ConvertTo-GlpiToolsRsql -Filter @{ name = 'a;b' }
    Returns name==a\;b
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration. In RSQL the AND (;) binds tighter than OR (,); criteria are joined in the order given.
#>

function ConvertTo-GlpiToolsRsql {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [object[]]$Criteria,

        [parameter(Mandatory = $false)]
        [hashtable]$Filter
    )

    # escapes a single value; values starting with a quote are wrapped in the other kind of quote
    $FormatValue = {
        param([string]$Value)
        if ($Value -match '^["'']') {
            if ($Value -notmatch '"') { return '"' + $Value + '"' }
            if ($Value -notmatch "'") { return "'" + $Value + "'" }
            throw "Value cannot be used in a filter: $Value"
        }
        $Value -replace '([\\;,()])', '\$1'
    }

    $All = [System.Collections.Generic.List[object]]::new()
    foreach ($Key in $Filter.Keys) {
        $All.Add(@{ Field = $Key; Operator = 'equals'; Value = $Filter[$Key] })
    }
    foreach ($Item in $Criteria) {
        $All.Add($Item)
    }

    $Operators = @{
        equals = '=='; notequals = '!='; lt = '=lt='; le = '=le='; gt = '=gt='; ge = '=ge='
        contains = '=ilike='; startswith = '=ilike='; endswith = '=ilike='
        in = '=in='; out = '=out='; isnull = '=isnull='; notnull = '=notnull='
    }

    $Result = ''
    foreach ($Item in $All) {
        $Field = [string]$Item.Field
        if ($Field -notmatch '^[a-zA-Z0-9_.]+$') {
            throw "Invalid property name in filter: $Field"
        }
        $Operator = if ($Item.Operator) { ([string]$Item.Operator).ToLower() } else { 'equals' }
        if (-not $Operators.ContainsKey($Operator)) {
            throw "Unknown filter operator: $Operator"
        }

        $Piece = switch ($Operator) {
            { $_ -in 'isnull', 'notnull' } {
                # unary operators take no value; the value is a boolean flag for the API
                "$Field$($Operators[$Operator])"
            }
            { $_ -in 'in', 'out' } {
                $List = @($Item.Value) | ForEach-Object { '"' + (([string]$_) -replace '(["\\])', '\$1') + '"' }
                "$Field$($Operators[$Operator])($($List -join ','))"
            }
            'contains' { "$Field$($Operators[$Operator])*$(& $FormatValue ([string]$Item.Value))*" }
            'startswith' { "$Field$($Operators[$Operator])$(& $FormatValue ([string]$Item.Value))*" }
            'endswith' { "$Field$($Operators[$Operator])*$(& $FormatValue ([string]$Item.Value))" }
            default { "$Field$($Operators[$Operator])$(& $FormatValue ([string]$Item.Value))" }
        }

        if ($Result -ne '') {
            $Link = if ($Item.Link) { ([string]$Item.Link).ToUpper() } else { 'AND' }
            if ($Link -notin 'AND', 'OR') {
                throw "Unknown filter link: $Link"
            }
            $Result += $(if ($Link -eq 'OR') { ',' } else { ';' })
        }
        $Result += $Piece
    }
    $Result
}
