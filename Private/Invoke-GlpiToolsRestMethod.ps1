<#
.SYNOPSIS
    Sends a request to the GLPI API v3 and returns the deserialized answer, keeping the wall time of the dates.
.DESCRIPTION
    Works like Invoke-RestMethod, but reads the answer as text. The time zone offset of the ISO 8601
    dates is removed before the JSON is converted, so the dates keep the time that the GLPI server sent
    instead of being moved to the time zone of this computer. Answers that are not JSON are returned as they are.
.PARAMETER Uri
    Address of the request.
.PARAMETER Method
    HTTP method.
.PARAMETER Headers
    Request headers.
.PARAMETER Body
    Request body.
.PARAMETER ContentType
    Content type of the body.
.PARAMETER SkipCertificateCheck
    Does not validate the TLS certificate.
.PARAMETER ResponseHeadersVariable
    Name of the variable, in the scope of the caller, that receives the response headers.
.EXAMPLE
    PS C:\> Invoke-GlpiToolsRestMethod -Uri https://glpi/api.php/v3.0/Assistance/Ticket/2 -Method Get -Headers $Headers
    Returns the ticket 2 with the dates as sent by the server.
.INPUTS
    None
.OUTPUTS
    The deserialized answer
.NOTES
    API v3 migration
#>

function Invoke-GlpiToolsRestMethod {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$Uri,

        [parameter(Mandatory = $true)]
        [string]$Method,

        [parameter(Mandatory = $false)]
        [hashtable]$Headers,

        [parameter(Mandatory = $false)]
        $Body,

        [parameter(Mandatory = $false)]
        [string]$ContentType,

        [parameter(Mandatory = $false)]
        [switch]$SkipCertificateCheck,

        [parameter(Mandatory = $false)]
        [string]$ResponseHeadersVariable
    )

    $params = @{
        Uri             = $Uri
        Method          = $Method
        Headers         = $Headers
        UseBasicParsing = $true
    }
    if ($null -ne $Body) { $params['Body'] = $Body }
    if ($ContentType) { $params['ContentType'] = $ContentType }
    if ($SkipCertificateCheck) { $params['SkipCertificateCheck'] = $true }

    $Response = Invoke-WebRequest @params
    if ($ResponseHeadersVariable) {
        Set-Variable -Name $ResponseHeadersVariable -Value $Response.Headers -Scope 1
    }

    $ResponseType = [string]($Response.Headers['Content-Type'] | Select-Object -First 1)
    if ($ResponseType -notmatch 'json') {
        return $Response.Content
    }
    $Text = [string]$Response.Content
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    # a date with offset would be moved to the local time zone, so only the wall time is kept
    $Text = $Text -replace '("\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})"', '$1"'
    $Text | ConvertFrom-Json
}
