<#
.SYNOPSIS
    Sends a request to the OAuth token endpoint of GLPI.
.DESCRIPTION
    Posts the grant to <site>/api.php/token as form data and returns the token response.
    Failures are turned into short messages that never include the request body, so secrets
    are not exposed in errors or verbose output.
.PARAMETER Body
    Form fields of the grant (grant_type, client_id, client_secret, ...).
.EXAMPLE
    PS C:\> Invoke-GlpiToolsTokenRequest -Body @{ grant_type = 'password'; ... }
    Returns the object with access_token, refresh_token and expires_in.
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    API v3 migration
#>

function Invoke-GlpiToolsTokenRequest {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [hashtable]$Body
    )

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue

    $params = @{
        method      = 'post'
        uri         = Get-GlpiToolsBaseUrl -Type Token
        body        = $Body
        contentType = 'application/x-www-form-urlencoded'
    }
    if ($GlpiConfig.SkipCertificateCheck) {
        $params['SkipCertificateCheck'] = $true
    }

    try {
        Invoke-RestMethod @params
    } catch {
        # keep the caught error: inside the switch the automatic variable is the switch value
        $Caught = $_
        # read the OAuth error from the response body, if there is one
        $OAuthError = $null
        if ($Caught.ErrorDetails.Message) {
            try { $OAuthError = $Caught.ErrorDetails.Message | ConvertFrom-Json } catch { $OAuthError = $null }
        }
        $Message = switch ($OAuthError.error) {
            'invalid_client' { "GLPI rejected the OAuth client (invalid_client). Check ClientId and ClientSecret in Set-GlpiToolsConfig." }
            'invalid_grant' { "GLPI rejected the credentials or the refresh token (invalid_grant): $($OAuthError.error_description)" }
            'invalid_scope' { "GLPI rejected the requested scope (invalid_scope). Check the scopes enabled for the OAuth client." }
            default {
                if ($OAuthError.error) { "GLPI token request failed ($($OAuthError.error)): $($OAuthError.error_description)" }
                else { "GLPI token request failed: $($Caught.Exception.Message)" }
            }
        }
        # the error id lets callers tell a rejected grant from a network or server failure
        $ErrorId = if ($OAuthError.error) { "GlpiOAuth.$($OAuthError.error)" } else { 'GlpiOAuth.RequestFailed' }
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new([System.Exception]::new($Message), $ErrorId, [System.Management.Automation.ErrorCategory]::AuthenticationError, $null))
    }
}
