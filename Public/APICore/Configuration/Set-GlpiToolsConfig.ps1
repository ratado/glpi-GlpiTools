<#
.SYNOPSIS
    Set GLPI Configuration File.
.DESCRIPTION
    This function preparing config file for GLPI API. Two API flavours are supported:
    the legacy REST API (v1, App-Token and User-Token) and the REST API v3 of GLPI 12
    (OAuth2 password grant).
.PARAMETER AppToken
    Application Token, you can find Token in API Settings at your GLPI website. Legacy API only.
.PARAMETER UserToken
    User Token, you can find inside user account settings. Legacy API only.
.PARAMETER PathToGlpi
    Path To GLPI. For the legacy API it is the apirest.php URL; for API v3 it is the site URL
    (the full .../api.php/v3.0 URL is accepted too).
.PARAMETER ApiVersion
    API flavour used by the module: v1 (default) or v3.
.PARAMETER ClientId
    OAuth client identifier created in GLPI (Setup > OAuth clients). API v3 only.
.PARAMETER ClientSecret
    OAuth client secret, as string or SecureString. API v3 only.
.PARAMETER Username
    GLPI user name used by the password grant. API v3 only.
.PARAMETER Password
    GLPI user password, as string or SecureString. API v3 only.
.PARAMETER Scope
    OAuth scopes requested at the token endpoint, separated by space. Default is api. API v3 only.
.PARAMETER SkipCertificateCheck
    Stores the option to ignore TLS certificate validation (self-signed certificates). Off by default.
.EXAMPLE
    PS C:\Users\Wojtek> Set-GlpiToolsConfig -AppToken 'dsahu2uh2uh32gt43tf434t' -UserToken 'sdasg3123hg3t1ftf21t3' -PathToGlpi 'http://pathtoglpi/glpi'
    This example show how to set GLPI config file for the legacy API
.EXAMPLE
    PS C:\> Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId 'abc' -ClientSecret 'def' -Username 'glpi' -Password 'secret'
    This example show how to set GLPI config file for the API v3 (password grant)
.INPUTS
    None, you cannot pipe objects to Set-GlpiToolsConfig
.OUTPUTS
    None
.NOTES
    PSP 12/2018
#>

function Set-GlpiToolsConfig {
    [CmdletBinding(DefaultParameterSetName = 'Legacy')]
    param (
        [parameter(Mandatory = $true, ParameterSetName = 'Legacy')]
        [string]$AppToken,
        [parameter(Mandatory = $true, ParameterSetName = 'Legacy')]
        [string]$UserToken,
        [parameter(Mandatory = $true, ParameterSetName = 'Legacy')]
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [string]$PathToGlpi,
        [parameter(Mandatory = $false, ParameterSetName = 'Legacy')]
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateSet('v1', 'v3')]
        [string]$ApiVersion = 'v1',
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [string]$ClientId,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateScript({ $_ -is [string] -or $_ -is [securestring] })]
        [object]$ClientSecret,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [string]$Username,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateScript({ $_ -is [string] -or $_ -is [securestring] })]
        [object]$Password,
        [parameter(Mandatory = $false, ParameterSetName = 'V3Password')]
        [string]$Scope = 'api',
        [parameter(Mandatory = $false)]
        [switch]$SkipCertificateCheck
    )
    
    begin {

        if ($IsLinux) {
            $ConfigFile = "Configuration.json"
            $ConfigPath = "$env:HOME/.config/GlpiToolsConfig\"
            $Config = Join-Path -Path $ConfigPath -ChildPath $ConfigFile
        } else {
            $ConfigFile = "Configuration.json"
            $ConfigPath = "$env:LOCALAPPDATA\GlpiToolsConfig\"
            $Config = Join-Path -Path $ConfigPath -ChildPath $ConfigFile
        }

        # the legacy set accepts only the v1 flavour
        if ($PSCmdlet.ParameterSetName -eq 'Legacy' -and $ApiVersion -ne 'v1') {
            throw "ApiVersion '$ApiVersion' requires the OAuth parameters (ClientId, ClientSecret, Username, Password)."
        }
        # the v3 set accepts only the v3 flavour
        if ($PSCmdlet.ParameterSetName -eq 'V3Password' -and $ApiVersion -ne 'v3') {
            throw "OAuth parameters require -ApiVersion v3."
        }

        if (!(Test-Path $ConfigPath)) {
            New-Item -Path $ConfigPath -ItemType Directory | Out-Null
        } else {
            try {
                Remove-Item -Path $Config -ErrorAction Stop    
            } catch {
                
            }
        }
    }

    process {
        $PathToGlpiSS = ConvertTo-SecureString -String $PathToGlpi -AsPlainText -Force 
        $PathToGlpiEncrypt = ConvertFrom-SecureString -SecureString $PathToGlpiSS 

        if ($PSCmdlet.ParameterSetName -eq 'V3Password') {
            # secrets are stored encrypted, the same way as the legacy tokens
            $ClientIdEncrypt = ConvertFrom-SecureString -SecureString (Encrypt-GlpiConfigSettings -string $ClientId)
            $ClientSecretEncrypt = ConvertFrom-SecureString -SecureString (Encrypt-GlpiConfigSettings -string $ClientSecret)
            $UsernameEncrypt = ConvertFrom-SecureString -SecureString (Encrypt-GlpiConfigSettings -string $Username)
            $PasswordEncrypt = ConvertFrom-SecureString -SecureString (Encrypt-GlpiConfigSettings -string $Password)
        } else {
            $AppTokenSS = ConvertTo-SecureString -String $AppToken -AsPlainText -Force 
            $UserTokenSS = ConvertTo-SecureString -String $UserToken -AsPlainText -Force 
            
            $AppTokenEncrypt = ConvertFrom-SecureString -SecureString $AppTokenSS 
            $UserTokenEncrypt = ConvertFrom-SecureString -SecureString $UserTokenSS 
        }
    }
    
    end {
        if ($PSCmdlet.ParameterSetName -eq 'V3Password') {
            $ConfigHash = [ordered]@{
                'ApiVersion'           = 'v3'
                'AuthMode'             = 'Password'
                'PathToGlpi'           = $PathToGlpiEncrypt
                'ClientId'             = $ClientIdEncrypt
                'ClientSecret'         = $ClientSecretEncrypt
                'Username'             = $UsernameEncrypt
                'Password'             = $PasswordEncrypt
                'Scope'                = $Scope
                'SkipCertificateCheck' = [bool]$SkipCertificateCheck
            }
        } else {
            $ConfigHash = [ordered]@{
                'ApiVersion'           = 'v1'
                'AppToken'             = $AppTokenEncrypt
                'UserToken'            = $UserTokenEncrypt
                'PathToGlpi'           = $PathToGlpiEncrypt
                'SkipCertificateCheck' = [bool]$SkipCertificateCheck
            }
        }
        $ConfigHash | ConvertTo-Json | Out-File -FilePath $Config

        # restrict the file to the owner, since the protection of ConvertFrom-SecureString is weaker on Linux
        if ($IsLinux) {
            try {
                # the config path may contain a literal backslash, so the provider resolves it first
                [System.IO.File]::SetUnixFileMode((Get-Item -Path $Config).FullName, [System.IO.UnixFileMode]'UserRead, UserWrite')
            } catch {
                Write-Verbose "Could not restrict permissions of $Config"
            }
        }

        # drop any session opened with a previous configuration
        Set-GlpiToolsSessionToken -ResetToken
    }
}
