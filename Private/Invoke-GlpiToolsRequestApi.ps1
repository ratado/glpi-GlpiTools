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

        try {
			$result = Invoke-RestMethod @Params -ErrorVariable ErrResp
		}
		catch {
			if($_.Exception.Response -ne $null) {
				$streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
				$ErrDetail = $streamReader.ReadToEnd() | ConvertFrom-Json
				$streamReader.Close()
			}
			else { $ErrDetail = {"UNKNOWN ERROR",  "No information" }}
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