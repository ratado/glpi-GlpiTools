<#
.SYNOPSIS
    Set GLPI Session Token.
.DESCRIPTION
    This function stores session token in Powershell session.
.PARAMETER SessionToken
    SessionToken getted after initSession (access token on API v3).
.PARAMETER RefreshToken
    OAuth refresh token, kept as SecureString in the session. API v3 only.
.PARAMETER ExpiresAt
    UTC date and time when the access token must be renewed. API v3 only.
.PARAMETER TokenType
    OAuth token type, usually Bearer. API v3 only.
.EXAMPLE
    PS C:\Users\Wojtek> Set-GlpiToolsSessionToken -SessionToken 'dsahu2uh2uh32gt43tf434t'
    This example show how to set GLPI Session Token
.INPUTS
    None, you cannot pipe objects to Set-GlpiToolsConfig
.OUTPUTS
    None
.NOTES
    PSP 12/2018
#>

function Set-GlpiToolsSessionToken {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [string]$SessionToken,
        [parameter(Mandatory = $false)]
        [string]$RefreshToken,
        [parameter(Mandatory = $false)]
        [datetime]$ExpiresAt,
        [parameter(Mandatory = $false)]
        [string]$TokenType,
		[parameter(Mandatory = $false)]
        [switch]$ResetToken=$false
    )
    
    begin {
		
    }

    process {
		
		if($ResetToken){
			$global:GlpiToolsSessionToken = $null
			# the entity and profile chosen for API v3 requests belong to the session
			$global:GlpiToolsContext = $null
		}
        else {		
			$SessionHash = [ordered]@{
				'SessionToken' = $SessionToken
			}
			# the API v3 fields are added only when informed, so the legacy session object is unchanged
			# the refresh token lives for a long time, so it is stored as SecureString and does not show up when the session is printed
			if ($RefreshToken) { $SessionHash['RefreshToken'] = ConvertTo-SecureString -String $RefreshToken -AsPlainText -Force }
			if ($PSBoundParameters.ContainsKey('ExpiresAt')) { $SessionHash['ExpiresAt'] = $ExpiresAt }
			if ($PSBoundParameters.ContainsKey('TokenType')) { $SessionHash['TokenType'] = $TokenType }
			$global:GlpiToolsSessionToken = New-Object -TypeName PSCustomObject -Property $SessionHash
		}
    }
    
    end {
        
    }
}