<#
.SYNOPSIS
    Obtains or renews the OAuth access token of the API v3.
.DESCRIPTION
    Uses the refresh token of the current session when there is one, and falls back to the
    password grant when it is missing or rejected. The new token is stored in the session
    (Set-GlpiToolsSessionToken) and the session object is returned.
.PARAMETER NewSession
    Skips the refresh token and always uses the password grant.
.EXAMPLE
    PS C:\> Update-GlpiToolsAccessToken
    Renews the expired token of the current session.
.INPUTS
    None
.OUTPUTS
    PSCustomObject with SessionToken, RefreshToken, ExpiresAt and TokenType
.NOTES
    API v3 migration
#>

function Update-GlpiToolsAccessToken {
    # only in-memory module state changes, there is nothing to confirm
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [switch]$NewSession
    )

    # the OAuth requests of the API v3 need PowerShell 7
    Assert-GlpiToolsPowerShell7 -Feature 'The GLPI API v3'

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
    $Response = $null

    # try the refresh token first; a rejected one is not an error, the password grant follows
    $Current = $global:GlpiToolsSessionToken
    $OldRefreshToken = $null
    if ($Current.RefreshToken) {
        # the refresh token is kept as SecureString in the session
        $OldRefreshToken = [System.Net.NetworkCredential]::new('', $Current.RefreshToken).Password
    }
    if (-not $NewSession -and $OldRefreshToken) {
        try {
            $Response = Invoke-GlpiToolsTokenRequest -Body @{
                grant_type    = 'refresh_token'
                refresh_token = $OldRefreshToken
                client_id     = $GlpiConfig.ClientId
                client_secret = $GlpiConfig.ClientSecret
            }
        } catch {
            # only a rejected grant falls back to the password; network and server failures are reported as they are
            if ($_.FullyQualifiedErrorId -notlike 'GlpiOAuth.invalid_grant*') {
                throw
            }
            Write-Verbose "Refresh token was not accepted, using the password grant"
        }
    }

    if (-not $Response) {
        $Response = Invoke-GlpiToolsTokenRequest -Body @{
            grant_type    = 'password'
            client_id     = $GlpiConfig.ClientId
            client_secret = $GlpiConfig.ClientSecret
            username      = $GlpiConfig.Username
            password      = $GlpiConfig.Password
            scope         = $GlpiConfig.Scope
        }
    }

    # expiry is kept early (60 seconds, or half of a short lifetime), so a token is never used right at its limit
    $Lifetime = if ([int]$Response.expires_in -gt 0) { [int]$Response.expires_in } else { 3600 }
    $ExpiresAt = [datetime]::UtcNow.AddSeconds($Lifetime - [math]::Min(60, $Lifetime / 2))

    # a response without a new refresh token keeps the previous one
    $NewRefreshToken = if ($Response.refresh_token) { $Response.refresh_token } else { $OldRefreshToken }

    Set-GlpiToolsSessionToken -SessionToken $Response.access_token -RefreshToken $NewRefreshToken -ExpiresAt $ExpiresAt -TokenType $Response.token_type
    $global:GlpiToolsSessionToken
}
