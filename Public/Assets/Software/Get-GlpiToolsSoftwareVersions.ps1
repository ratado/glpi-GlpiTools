<#
.SYNOPSIS
    Function is getting Software Version informations from GLPI
.DESCRIPTION
    Function is based on Software Version ID which you can find in GLPI website
    Returns object with property's of Software Version
.PARAMETER All
    This parameter will return all Software Versions from GLPI
.PARAMETER SoftwareVersionId
    This parameter can take pipline input, either, you can use this function with -SoftwareVersionId keyword.
    Provide to this param Software Version ID from GLPI
.PARAMETER Raw
    Parameter which you can use with SoftwareVersionId Parameter.
    SoftwareVersionId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER SoftwareId
    Software whose versions are listed. Required with the GLPI API v3, ignored by the legacy API.
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsSoftwareVersions
    Function gets SoftwareVersionID from GLPI from Pipline, and return Software Version object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsSoftwareVersions
    Function gets SoftwareVersionID from GLPI from Pipline (u can pass many ID's like that), and return Software Version object
.EXAMPLE
    PS C:\> Get-GlpiToolsSoftwareVersions -SoftwareVersionId 326
    Function gets SoftwareVersionID from GLPI which is provided through -SoftwareVersionId after Function type, and return Software Version object
.EXAMPLE 
    PS C:\> Get-GlpiToolsSoftwareVersions -SoftwareVersionId 326, 321
    Function gets SoftwareVersionID from GLPI which is provided through -SoftwareVersionId keyword after Function type (u can provide many ID's like that), and return Software Version object
.EXAMPLE
    PS C:\> Get-GlpiToolsSoftwareVersions -SoftwareVersionId 234 -Raw
    Example will show Software Version with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> 234 | Get-GlpiToolsSoftwareVersions -Raw
    Example will show Software Version with id 234, but without any parameter converted
.INPUTS
    Software Version ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Software Versions from GLPI
.NOTES
    PSP 08/2019
#>

function Get-GlpiToolsSoftwareVersions {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,


        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "SoftwareVersionId")]
        [alias('SVID')]
        [string[]]$SoftwareVersionId,
        [parameter(Mandatory = $false,
            ParameterSetName = "SoftwareVersionId")]
        [switch]$Raw,

        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [parameter(Mandatory = $false,
            ParameterSetName = "SoftwareVersionId")]
        [int]$SoftwareId
    )
    
    begin {

        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi
        $SessionToken = $Script:SessionToken

        $AppToken = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty PathToGlpi
        $SessionToken = Get-GlpiToolsSessionToken -Verbose:$false | Select-Object -ExpandProperty SessionToken

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $SoftwareVersionObjectArray = [System.Collections.Generic.List[PSObject]]::New()

    }
    
    process {
        # API v3: these records are sub-resources of an asset, so the asset is informed with a parameter that only the v3 uses
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            if (-not $PSBoundParameters.ContainsKey('SoftwareId')) {
                throw 'The parameter -SoftwareId is required with the GLPI API v3.'
            }
            $V3Items = @(Invoke-GlpiToolsRequest -Method Get -Resource "/Assets/Software/$SoftwareId/Version" -All | Where-Object { $_ })
            if ($PSCmdlet.ParameterSetName -eq 'SoftwareVersionId') {
                # the legacy ID parameter selects records of the list
                $V3Items = @($V3Items | Where-Object { [string]$_.id -in @($SoftwareVersionId) })
            }
            $V3Items | ConvertFrom-GlpiToolsV3Item -ItemType SoftwareVersion -Raw:$Raw
            return
        }

        switch ($ChoosenParam) {
            All {
                
                $params = @{
                    headers = @{
                        'Content-Type'  = 'application/json'
                        'App-Token'     = $AppToken
                        'Session-Token' = $SessionToken
                    }
                    method  = 'get'
                    uri     = "$($PathToGlpi)/SoftwareVersion/?range=0-9999999999999"
                }
                
                $GlpiSoftwareVersionAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiSoftwareVersion in $GlpiSoftwareVersionAll) {
                    $SoftwareVersionHash = [ordered]@{ }
                            $SoftwareVersionProperties = $GlpiSoftwareVersion.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($SoftwareVersionProp in $SoftwareVersionProperties) {
                                $SoftwareVersionHash.Add($SoftwareVersionProp.Name, $SoftwareVersionProp.Value)
                            }
                            $object = [pscustomobject]$SoftwareVersionHash
                            $SoftwareVersionObjectArray.Add($object)
                }
                $SoftwareVersionObjectArray
                $SoftwareVersionObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                
            }
            SoftwareVersionId { 
                foreach ( $SVid in $SoftwareVersionId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/SoftwareVersion/$($SVId)"
                    }

                    Try {
                        $GlpiSoftwareVersion = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $SoftwareVersionHash = [ordered]@{ }
                            $SoftwareVersionProperties = $GlpiSoftwareVersion.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($SoftwareVersionProp in $SoftwareVersionProperties) {
                                $SoftwareVersionHash.Add($SoftwareVersionProp.Name, $SoftwareVersionProp.Value)
                            }
                            $object = [pscustomobject]$SoftwareVersionHash
                            $SoftwareVersionObjectArray.Add($object)
                        } else {
                            $SoftwareVersionHash = [ordered]@{ }
                            $SoftwareVersionProperties = $GlpiSoftwareVersion.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($SoftwareVersionProp in $SoftwareVersionProperties) {
                                
                                $SoftwareVersionPropNewValue = Get-GlpiToolsParameters -Parameter $SoftwareVersionProp.Name -Value $SoftwareVersionProp.Value

                                $SoftwareVersionHash.Add($SoftwareVersionProp.Name, $SoftwareVersionPropNewValue)
                            }
                            $object = [pscustomobject]$SoftwareVersionHash
                            $SoftwareVersionObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Software Version ID = $SVId is not found"
                        
                    }
                    $SoftwareVersionObjectArray
                    $SoftwareVersionObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            Default {
                
            }
        }
    }
    
    end {
    
    }
}