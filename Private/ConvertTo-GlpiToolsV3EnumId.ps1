<#
.SYNOPSIS
    Converts a readable option of a ticket command into the numeric value used by GLPI.
.DESCRIPTION
    The v3 branches of the ticket commands call this function inside the process block, because values that
    arrive from the pipeline by property name are not bound yet when the begin block runs.
.PARAMETER Kind
    Level (urgency, impact, priority), Type (incident or request), TaskState or Validation.
.PARAMETER Value
    Readable name or number given by the user.
.EXAMPLE
    PS C:\> ConvertTo-GlpiToolsV3EnumId -Kind Level -Value 'High'
    Returns 4.
.OUTPUTS
    Int32, or nothing when the value is not known for a TaskState.
.NOTES
    Private helper of the API v3 branches.
#>
function ConvertTo-GlpiToolsV3EnumId {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateSet('Level', 'Type', 'TaskState', 'Validation')]
        [string]$Kind,
        [parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    # the names accepted by each kind, the same ones the legacy begin blocks translate
    $Names = @{
        Level      = @{ 'Very low' = 1; 'Low' = 2; 'Medium' = 3; 'High' = 4; 'Very High' = 5 }
        Type       = @{ 'Incident' = 1; 'Request' = 2 }
        TaskState  = @{ 'Todo' = 1; 'Information' = 0; 'Done' = 2 }
        Validation = @{ 'None' = 1; 'Waiting' = 2; 'Granted' = 3; 'Refused' = 4 }
    }
    $Key = [string]$Value
    if ($Names[$Kind].ContainsKey($Key)) {
        return $Names[$Kind][$Key]
    }
    # numbers are used as they are; an unknown validation falls back to None like the legacy code
    if ($Kind -eq 'Validation') { return 1 }
    if ($Kind -ne 'TaskState' -and $Key -match '^\d+$') { return [int]$Key }
}
