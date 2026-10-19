<#
.SYNOPSIS
    Get GLPI Configuration File.
.DESCRIPTION
    This function getting data inside GLPI config file, to use it with other functions
    and show stored values.
.EXAMPLE
    PS C:\Users\Wojtek> Get-GlpiToolsConfig
    Running script like that, shows you current config data, including the API flavour
    (ApiVersion v1 or v3) and the OAuth fields used by API v3 (null when not in use).
.INPUTS
    None
.OUTPUTS
    Function creates PSCustomObject 
.NOTES
    PSP 12/2018
#>

function Get-GlpiToolsConfig {
    [CmdletBinding()]
    param (
        
    )
    
    begin {

        if ($IsLinux) {
            $GlpiConfig = @()
            $ConfigFile = "Configuration.json"
            $ConfigPath = "$env:HOME/.config/GlpiToolsConfig\"
            $Config = Join-Path -Path $ConfigPath -ChildPath $ConfigFile
        } else {
            $GlpiConfig = @()
            $ConfigFile = "Configuration.json"
            $ConfigPath = "$env:LOCALAPPDATA\GlpiToolsConfig\"
            $Config = Join-Path -Path $ConfigPath -ChildPath $ConfigFile 
        }

    }
    
    process {

        if (Test-Path -Path $Config) {
            $ConfigData = Get-Content $Config | ConvertFrom-Json
        
            $AppTokenSS = if ($ConfigData.AppToken) { ConvertTo-SecureString $ConfigData.AppToken } else { New-Object System.Security.SecureString }
            $UserTokenSS = if ($ConfigData.UserToken) { ConvertTo-SecureString $ConfigData.UserToken } else { New-Object System.Security.SecureString }
            $PathToGlpiSS = ConvertTo-SecureString $ConfigData.PathToGlpi

            if ($IsLinux) {
                $AppTokenDecrypt = [System.Runtime.InteropServices.marshal]::PtrToStringUni([System.Runtime.InteropServices.marshal]::SecureStringToGlobalAllocUnicode($AppTokenSS))
                $UserTokenDecrypt = [System.Runtime.InteropServices.marshal]::PtrToStringUni([System.Runtime.InteropServices.marshal]::SecureStringToGlobalAllocUnicode($UserTokenSS))
                $PathToGlpiDecrypt = [System.Runtime.InteropServices.marshal]::PtrToStringUni([System.Runtime.InteropServices.marshal]::SecureStringToGlobalAllocUnicode($PathToGlpiSS))
            } else {
                $AppTokenDecrypt = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($AppTokenSS))
                $UserTokenDecrypt = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($UserTokenSS))
                $PathToGlpiDecrypt = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($PathToGlpiSS))
            }
            
            $ConfigHash = [ordered]@{
                'AppToken' = $AppTokenDecrypt
                'UserToken' = $UserTokenDecrypt
                'PathToGlpi' = $PathToGlpiDecrypt
                'ApiVersion' = $(if ($ConfigData.ApiVersion) { $ConfigData.ApiVersion } else { 'v1' })
                'AuthMode' = $ConfigData.AuthMode
                'ClientId' = ConvertFrom-GlpiConfigSecret -Value $ConfigData.ClientId
                'ClientSecret' = ConvertFrom-GlpiConfigSecret -Value $ConfigData.ClientSecret
                'Username' = ConvertFrom-GlpiConfigSecret -Value $ConfigData.Username
                'Password' = ConvertFrom-GlpiConfigSecret -Value $ConfigData.Password
                'Scope' = $ConfigData.Scope
                'SkipCertificateCheck' = [bool]$ConfigData.SkipCertificateCheck
            }

            $object = New-Object -TypeName PSCustomObject -Property $ConfigHash
            $GlpiConfig += $object 
            
        }
        else {
            Write-Warning -Message "I cannot find Config File, check if you used Set-GlpiToolsConfig to generate Config"
        }

    }
    
    end {
        $GlpiConfig
    }
}