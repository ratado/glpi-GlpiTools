<#
.SYNOPSIS
    Stops a feature that needs PowerShell 7 when it runs on an older version.
.DESCRIPTION
    The API v3 and the option to skip the certificate check depend on Invoke-RestMethod and
    Invoke-WebRequest features that only exist in PowerShell 7. The legacy API (v1) keeps working
    on Windows PowerShell 5.1.
.PARAMETER Feature
    Feature name shown in the message.
.EXAMPLE
    PS C:\> Assert-GlpiToolsPowerShell7 -Feature 'The GLPI API v3'
    Throws on Windows PowerShell 5.1 and returns nothing on PowerShell 7.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Assert-GlpiToolsPowerShell7 {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$Feature
    )

    $Version = Get-GlpiToolsPowerShellVersion
    if ($Version.Major -ge 7) {
        return
    }

    $Text = "$Feature requires PowerShell 7 or later (running $Version). Install PowerShell 7 or keep using the legacy API (v1)."
    # throwing the record keeps the error ID, which a caller can test
    throw [System.Management.Automation.ErrorRecord]::new([System.PlatformNotSupportedException]::new($Text), 'GlpiTools.PowerShell7Required', [System.Management.Automation.ErrorCategory]::NotImplemented, $Feature)
}
