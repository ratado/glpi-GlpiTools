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
.PARAMETER OutputFormat
    Format of the objects returned by the commands: Legacy (default) keeps the properties and values of the
    legacy API; Native returns the objects as the API v3 sends them. API v3 only; Set-GlpiToolsOutputFormat
    changes it later without informing the credentials again. When omitted, the format already stored is kept.
.PARAMETER SkipCertificateCheck
    Stores the option to ignore TLS certificate validation (self-signed certificates). Off by default.
    Applied to every request made through the module.
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
        [parameter(Mandatory = $false)]
        [ValidateSet('v1', 'v3')]
        [string]$ApiVersion,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateNotNullOrEmpty()]
        [string]$ClientId,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateScript({ ($_ -is [string] -and $_ -ne '') -or ($_ -is [securestring] -and $_.Length -gt 0) })]
        [object]$ClientSecret,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        [parameter(Mandatory = $true, ParameterSetName = 'V3Password')]
        [ValidateScript({ ($_ -is [string] -and $_ -ne '') -or ($_ -is [securestring] -and $_.Length -gt 0) })]
        [object]$Password,
        [parameter(Mandatory = $false, ParameterSetName = 'V3Password')]
        [string]$Scope = 'api',
        [parameter(Mandatory = $false, ParameterSetName = 'V3Password')]
        [ValidateSet('Legacy', 'Native')]
        [string]$OutputFormat,
        [parameter(Mandatory = $false)]
        [switch]$SkipCertificateCheck
    )
    
    begin {

        $ConfigPath = Get-GlpiToolsConfigPath -Directory
        $Config = Get-GlpiToolsConfigPath

        # the legacy set accepts only the v1 flavour
        if ($PSCmdlet.ParameterSetName -eq 'Legacy' -and $ApiVersion -eq 'v3') {
            throw "-ApiVersion v3 requires -ClientId, -ClientSecret, -Username and -Password."
        }
        # the OAuth set accepts only the v3 flavour
        if ($PSCmdlet.ParameterSetName -eq 'V3Password' -and $ApiVersion -eq 'v1') {
            throw "-ApiVersion v1 cannot be combined with the OAuth parameters (-ClientId, -ClientSecret, -Username, -Password)."
        }

        # the password grant sends the account password and the client secret in the body of the token request
        if (($PSCmdlet.ParameterSetName -eq 'V3Password' -or $ApiVersion -eq 'v3') -and $PathToGlpi -like 'http://*') {
            Write-Warning -Message "The GLPI address uses http://, so the credentials are sent without encryption. Use https:// whenever possible."
        }

        # close the legacy session opened with the previous configuration, while its settings are still on disk
        if ($global:GlpiToolsSessionToken -and (Test-Path -Path $Config) -and (Get-GlpiToolsApiVersion) -eq 'v1') {
            try {
                Set-GlpiToolsKillSession | Out-Null
            } catch {
                Write-Verbose "Could not close the previous session on the server"
            }
        }

        if (!(Test-Path $ConfigPath)) {
            New-Item -Path $ConfigPath -ItemType Directory | Out-Null
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
        # rewriting the file keeps the output format chosen before, unless -OutputFormat is informed
        $ChosenFormat = 'Legacy'
        if ($PSBoundParameters.ContainsKey('OutputFormat')) {
            $ChosenFormat = $OutputFormat
        } elseif (Test-Path -Path $Config) {
            $PreviousConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
            if ($PreviousConfig.ApiVersion -eq 'v3' -and $PreviousConfig.OutputFormat -eq 'Native') { $ChosenFormat = 'Native' }
        }

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
                'OutputFormat'         = $ChosenFormat
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
        # the previous file is replaced only after the new content is ready
        Remove-Item -Path $Config -ErrorAction SilentlyContinue

        # create the file empty and restrict it to the owner before any secret is written, since the protection of ConvertFrom-SecureString is weaker on Linux
        New-Item -Path $Config -ItemType File -Force | Out-Null
        if ($IsLinux) {
            try {
                # the config path may contain a literal backslash, so the provider resolves it first
                [System.IO.File]::SetUnixFileMode((Get-Item -LiteralPath $Config).FullName, [System.IO.UnixFileMode]'UserRead, UserWrite')
                [System.IO.File]::SetUnixFileMode((Get-Item -LiteralPath $ConfigPath).FullName, [System.IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
            } catch {
                Write-Warning "Could not restrict permissions of $Config"
            }
        }
        $ConfigHash | ConvertTo-Json | Out-File -FilePath $Config

        # the stored configuration changed, so the cached copy is discarded
        $script:GlpiToolsConfigCache = $null

        # drop the local token of the previous configuration
        Set-GlpiToolsSessionToken -ResetToken
    }
}
