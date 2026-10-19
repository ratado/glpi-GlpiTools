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
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [switch]$NewSession
    )

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
    $Response = $null

    # try the refresh token first; a rejected one is not an error, the password grant follows
    $Current = $global:GlpiToolsSessionToken
    if (-not $NewSession -and $Current.RefreshToken) {
        try {
            $Response = Invoke-GlpiToolsTokenRequest -Body @{
                grant_type    = 'refresh_token'
                refresh_token = $Current.RefreshToken
                client_id     = $GlpiConfig.ClientId
                client_secret = $GlpiConfig.ClientSecret
            }
        } catch {
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

    # expiry is kept 60 seconds early, so a token is never used right at its limit
    $ExpiresAt = [datetime]::UtcNow.AddSeconds([int]$Response.expires_in - 60)

    Set-GlpiToolsSessionToken -SessionToken $Response.access_token -RefreshToken $Response.refresh_token -ExpiresAt $ExpiresAt -TokenType $Response.token_type
    $global:GlpiToolsSessionToken
}
