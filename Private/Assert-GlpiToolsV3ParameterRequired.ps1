<#
.SYNOPSIS
    Stops a command that was called without a parameter that only the GLPI API v3 requires.
.DESCRIPTION
    Some commands need an extra parameter with the API v3 (for example the computer of its installed software),
    which the legacy API does not have. When any of the parameters is missing, throws a terminating error with the
    ID GlpiTools.V3ParameterRequired. Because the error ends the command, it is reported once per call, even
    when IDs come from the pipeline.
.PARAMETER Name
    Names of the required parameters, without the dash.
.PARAMETER BoundParameters
    Parameters bound in the calling command ($PSBoundParameters).
.EXAMPLE
    PS C:\> Assert-GlpiToolsV3ParameterRequired -Name 'ComputerId' -BoundParameters $PSBoundParameters
    Throws "The parameter -ComputerId is required with the GLPI API v3." when -ComputerId was not used.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Assert-GlpiToolsV3ParameterRequired {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string[]]$Name,

        [parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BoundParameters
    )

    # nothing to report when every required parameter was informed
    $Missing = @($Name | Where-Object { -not $BoundParameters.ContainsKey($_) })
    if ($Missing.Count -eq 0) {
        return
    }

    # the message names all the required parameters, as the legacy-aware callers show them to the user
    if ($Name.Count -eq 1) {
        $Text = "The parameter -$($Name[0]) is required with the GLPI API v3."
    } else {
        $Text = "The parameters -$($Name[0..($Name.Count - 2)] -join ', -') and -$($Name[-1]) are required with the GLPI API v3."
    }
    # throwing the record keeps the error ID, which a caller can test
    throw [System.Management.Automation.ErrorRecord]::new([System.ArgumentException]::new($Text), 'GlpiTools.V3ParameterRequired', [System.Management.Automation.ErrorCategory]::InvalidArgument, $Missing -join ',')
}
