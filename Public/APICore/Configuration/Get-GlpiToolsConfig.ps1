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
            # the decrypted object is reused while the file is unchanged; a copy is returned so callers cannot alter the cache
            $LastWrite = (Get-Item -Path $Config).LastWriteTimeUtc.Ticks
            $Cached = $script:GlpiToolsConfigCache
            if ($Cached -and $Cached.Path -eq $Config -and $Cached.LastWrite -eq $LastWrite) {
                $GlpiConfig += $Cached.Object.PSObject.Copy()
                return
            }

            $ConfigData = Get-Content $Config | ConvertFrom-Json
        
            $AppTokenDecrypt = ConvertFrom-GlpiConfigSecret -Value $ConfigData.AppToken
            $UserTokenDecrypt = ConvertFrom-GlpiConfigSecret -Value $ConfigData.UserToken
            $PathToGlpiDecrypt = ConvertFrom-GlpiConfigSecret -Value $ConfigData.PathToGlpi

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
            $script:GlpiToolsConfigCache = @{ Path = $Config; LastWrite = $LastWrite; Object = $object }
            $GlpiConfig += $object.PSObject.Copy()
            
        }
        else {
            Write-Warning -Message "I cannot find Config File, check if you used Set-GlpiToolsConfig to generate Config"
        }

    }
    
    end {
        $GlpiConfig
    }
}