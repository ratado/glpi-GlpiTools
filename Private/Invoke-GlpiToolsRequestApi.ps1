<#
.SYNOPSIS
    Function that invoke the request for server API
.DESCRIPTION
    Function that invoke the server API and return the result, catching the exceptions
.EXAMPLE
    PS C:\> Check-GlpiToolsRequestApi -Params $myparams
    Example will return the Invoke-RestMethod result
.PARAMETER Params
    Parameter which is used to provide plugin name to check in function
.INPUTS
    Params
.OUTPUTS
    The same of Invoke-RestMethod and $GLPIToolsErrorOutput variable
.NOTES
    PSP 04/2019
#>

function Invoke-GlpiToolsRequestApi {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [hashtable]$Params
    )
    
    begin {

        $global:GLPIToolsErrorOutput = $null
    }
    
    process {

        # this function reaches the legacy API only; a command without a v3 branch must not send the v3 token there
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            $Text = "The command that was run has no GLPI API v3 branch, so it cannot use the configured API v3. Run Set-GlpiToolsConfig with the legacy tokens to use it."
            throw [System.Management.Automation.ErrorRecord]::new([System.NotSupportedException]::new($Text), 'GlpiTools.LegacyCallWithV3', [System.Management.Automation.ErrorCategory]::NotImplemented, $Params.uri)
        }

        # honour the certificate option stored by Set-GlpiToolsConfig, without touching the caller's hashtable
        $Params = $Params.Clone()
        $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
        if ($GlpiConfig -and $GlpiConfig.SkipCertificateCheck -and -not $Params.ContainsKey('SkipCertificateCheck')) {
            $Params['SkipCertificateCheck'] = $true
        }

        try {
			$result = Invoke-RestMethod @Params -ErrorVariable ErrResp
		}
		catch {
			# PowerShell 7 puts the body of the answer in ErrorDetails; Windows PowerShell 5.1 only in the response stream
			$ErrBody = $_.ErrorDetails.Message
			if (-not $ErrBody -and $null -ne $_.Exception.Response -and $_.Exception.Response.PSObject.Methods['GetResponseStream']) {
				$streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
				$ErrBody = $streamReader.ReadToEnd()
				$streamReader.Close()
			}
			$ErrDetail = @("UNKNOWN ERROR", "No information")
			if ($ErrBody) {
				try { $ErrDetail = @($ErrBody | ConvertFrom-Json) } catch { $ErrDetail = @("UNKNOWN ERROR", $ErrBody) }
			}
			Write-Output "Error: $ErrDetail "
			
			$global:GLPIToolsErrorOutput = @{
				"Code" = $ErrDetail[0]
				"Details" = $ErrDetail[1]
				"ExceptionInfo" = $ErrResp
				
			}
		
		throw $_.Exception
		}
		
		
    }
    
    end {
		
		return $result
        
    }
}