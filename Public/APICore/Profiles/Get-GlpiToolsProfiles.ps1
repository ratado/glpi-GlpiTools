<#
.SYNOPSIS
    Function is getting Profile informations from GLPI
.DESCRIPTION
    Function is based on ProfileID which you can find in GLPI website
    Returns object with property's of Profile
.PARAMETER All
    This parameter will return all Profiles from GLPI
.PARAMETER ProfileId
    This parameter can take pipline input, either, you can use this function with -ProfileId keyword.
    Provide to this param Profile ID from GLPI Profile Bookmark
.PARAMETER Raw
    Parameter which you can use with ProfileId Parameter.
    ProfileId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER ProfileName
    This parameter can take pipline input, either, you can use this function with -ProfileName keyword.
    Provide to this param Profile Name from GLPI Profiles Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsProfiles -All
    Example will show all profiles.
.EXAMPLE
    PS C:\> Get-GlpiToolsProfiles -ProfileName Admin
    Example will return every profile which contains Admin keyword
.INPUTS
    Profile ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Profiles from GLPI
.NOTES
    PSP 04/2019
#>

function Get-GlpiToolsProfiles {
    [CmdletBinding()]
    param (

        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
		
		[parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "ProfileId")]
        [alias('PID')]
        [string[]]$ProfileId,
        [parameter(Mandatory = $false,
            ParameterSetName = "ProfileId")]
        [switch]$Raw,

        [parameter(Mandatory = $true,
            ParameterSetName = "ProfileName")]
        [alias('PN')]
        [string]$ProfileName

    )
    
    begin {
        $SessionToken = $Script:SessionToken
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys
        
        $ProfileObjectArray = [System.Collections.Generic.List[PSObject]]::New()

    }
    
    process {

        switch ($ChoosenParam) {
            All { 
                $params = @{
                    headers = @{
                        'Content-Type'  = 'application/json'
                        'App-Token'     = $AppToken
                        'Session-Token' = $SessionToken
                    }
                    method  = 'get'
                    uri     = "$($PathToGlpi)/Profile/?range=0-9999999999999"
                }
                
                $GlpiProfileAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiProfile in $GlpiProfileAll) {
                    $ProfileHash = [ordered]@{ }
                    $ProfileProperties = $GlpiProfile.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($ProfileProp in $ProfileProperties) {
                        $ProfileHash.Add($ProfileProp.Name, $ProfileProp.Value)
                    }
                    $object = [pscustomobject]$ProfileHash
                    $ProfileObjectArray.Add($object)
                }
                $ProfileObjectArray
                $ProfileObjectArray = [System.Collections.Generic.List[PSObject]]::New()
            }
			ProfileId { 
                foreach ( $PId in $ProfileId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Profile/$($PId)"
                    }

                    Try {
                        $GlpiProfile = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $ProfileHash = [ordered]@{ }
                            $ProfileProperties = $GlpiProfile.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ProfileProp in $ProfileProperties) {
                                $ProfileHash.Add($ProfileProp.Name, $ProfileProp.Value)
                            }
                            $object = [pscustomobject]$ProfileHash
                            $ProfileObjectArray.Add($object)
                        } else {
                            $ProfileHash = [ordered]@{ }
                            $ProfileProperties = $GlpiProfile.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($ProfileProp in $ProfileProperties) {
                                
                                $ProfilePropNewValue = Get-GlpiToolsParameters -Parameter $ProfileProp.Name -Value $ProfileProp.Value

                                $ProfileHash.Add($ProfileProp.Name, $ProfilePropNewValue)
                            }
                            $object = [pscustomobject]$ProfileHash
                            $ProfileObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Profile ID = $PId is not found"
                        
                    }
                    $ProfileObjectArray
                    $ProfileObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            ProfileName { 
                Search-GlpiToolsItems -SearchFor Profile -SearchType contains -SearchValue $ProfileName
            }
            Default {
                
            }
        }
    }
    
    end {
        
    }
}