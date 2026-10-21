<#
.SYNOPSIS
    Decrypts a value stored in the GLPI config file.
.DESCRIPTION
    Converts the encrypted string saved by Set-GlpiToolsConfig back to plain text, using the
    decryption branch that matches the operating system. Returns $null for empty values.
.PARAMETER Value
    Encrypted string read from Configuration.json.
.EXAMPLE
    PS C:\> ConvertFrom-GlpiConfigSecret -Value $ConfigData.ClientSecret
    Returns the plain text of the stored client secret.
.INPUTS
    None
.OUTPUTS
    String
.NOTES
    API v3 migration
#>

function ConvertFrom-GlpiConfigSecret {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return $null
    }

    $SecureValue = ConvertTo-SecureString $Value

    # the unmanaged copy is zeroed and freed as soon as the text is read
    if ($IsLinux) {
        $Pointer = [System.Runtime.InteropServices.marshal]::SecureStringToGlobalAllocUnicode($SecureValue)
        try { [System.Runtime.InteropServices.marshal]::PtrToStringUni($Pointer) } finally { [System.Runtime.InteropServices.marshal]::ZeroFreeGlobalAllocUnicode($Pointer) }
    } else {
        $Pointer = [System.Runtime.InteropServices.marshal]::SecureStringToBSTR($SecureValue)
        try { [System.Runtime.InteropServices.marshal]::PtrToStringAuto($Pointer) } finally { [System.Runtime.InteropServices.marshal]::ZeroFreeBSTR($Pointer) }
    }
}
