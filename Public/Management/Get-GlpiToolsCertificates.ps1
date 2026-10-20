<#
.SYNOPSIS
    Function is getting Certificate informations from GLPI
.DESCRIPTION
    Function is based on CertificateId which you can find in GLPI website
    Returns object with property's of Certificate
.PARAMETER All
    This parameter will return all Certificate from GLPI
.PARAMETER CertificateId
    This parameter can take pipCertificate input, either, you can use this function with -CertificateId keyword.
    Provide to this param CertificateId from GLPI Certificate Bookmark
.PARAMETER Raw
    Parameter which you can use with CertificateId Parameter.
    CertificateId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER CertificateName
    This parameter can take pipCertificate input, either, you can use this function with -CertificateId keyword.
    Provide to this param Certificate Name from GLPI Certificate Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsCertificates -All
    Example will return all Certificate from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsCertificates
    Function gets CertificateId from GLPI from PipCertificate, and return Certificate object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsCertificates
    Function gets CertificateId from GLPI from PipCertificate (u can pass many ID's like that), and return Certificate object
.EXAMPLE
    PS C:\> Get-GlpiToolsCertificates -CertificateId 326
    Function gets CertificateId from GLPI which is provided through -CertificateId after Function type, and return Certificate object
.EXAMPLE 
    PS C:\> Get-GlpiToolsCertificates -CertificateId 326, 321
    Function gets Certificate Id from GLPI which is provided through -CertificateId keyword after Function type (u can provide many ID's like that), and return Certificate object
.EXAMPLE
    PS C:\> Get-GlpiToolsCertificates -CertificateName Fusion
    Example will return glpi Certificate, but what is the most important, Certificate will be shown exactly as you see in glpi dropdown Certificate.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Certificate ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Certificate from GLPI
.NOTES
    PSP 11/2019
#>

function Get-GlpiToolsCertificates {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeLine = $true,
            ParameterSetName = "CertificateId")]
        [alias('CID')]
        [string[]]$CertificateId,
        [parameter(Mandatory = $false,
            ParameterSetName = "CertificateId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "CertificateName")]
        [alias('CN')]
        [string]$CertificateName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $CertificatesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/Certificate' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Certificate -Raw
                }
                CertificateId {
                    # the v3 answer already carries the names of the related items
                    foreach ($V3ItemId in $CertificateId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Assets/Certificate/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Certificate ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Certificate -Raw:$Raw
                        }
                    }
                }
                CertificateName {
                    Search-GlpiToolsItems -SearchFor Certificate -SearchType contains -SearchValue $CertificateName | ConvertFrom-GlpiToolsV3Item -ItemType Certificate -Raw
                }
            }
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
                    uri     = "$($PathToGlpi)/Certificate/?range=0-9999999999999"
                }
                
                $CertificatesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($Certificate in $CertificatesAll) {
                    $CertificateHash = [ordered]@{ }
                    $CertificateProperties = $Certificate.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($CertificateProp in $CertificateProperties) {
                        $CertificateHash.Add($CertificateProp.Name, $CertificateProp.Value)
                    }
                    $object = [pscustomobject]$CertificateHash
                    $CertificatesArray.Add($object)
                }
                $CertificatesArray
                $CertificatesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            CertificateId { 
                foreach ( $CId in $CertificateId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Certificate/$($CId)"
                    }

                    Try {
                        $Certificate = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $CertificateHash = [ordered]@{ }
                            $CertificateProperties = $Certificate.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($CertificateProp in $CertificateProperties) {
                                $CertificateHash.Add($CertificateProp.Name, $CertificateProp.Value)
                            }
                            $object = [pscustomobject]$CertificateHash
                            $CertificatesArray.Add($object)
                        } else {
                            $CertificateHash = [ordered]@{ }
                            $CertificateProperties = $Certificate.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($CertificateProp in $CertificateProperties) {

                                $CertificatePropNewValue = Get-GlpiToolsParameters -Parameter $CertificateProp.Name -Value $CertificateProp.Value

                                $CertificateHash.Add($CertificateProp.Name, $CertificatePropNewValue)
                            }
                            $object = [pscustomobject]$CertificateHash
                            $CertificatesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Certificate ID = $CId is not found"
                        
                    }
                    $CertificatesArray
                    $CertificatesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            CertificateName { 
                Search-GlpiToolsItems -SearchFor Certificate -SearchType contains -SearchValue $CertificateName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}