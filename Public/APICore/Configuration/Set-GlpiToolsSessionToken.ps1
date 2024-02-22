<#
.SYNOPSIS
    Set GLPI Session Token.
.DESCRIPTION
    This function stores session token in Powershell session.
.PARAMETER SessionToken
    SessionToken getted after initSession.
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
        [switch]$ResetToken=$false
    )
    
    begin {
		
    }

    process {
		
		if($ResetToken){
			$global:GlpiToolsSessionToken = $null
		}
        else {		
			$SessionHash = [ordered]@{
				'SessionToken' = $SessionToken
			}
			$global:GlpiToolsSessionToken = New-Object -TypeName PSCustomObject -Property $SessionHash
		}
    }
    
    end {
        
    }
}