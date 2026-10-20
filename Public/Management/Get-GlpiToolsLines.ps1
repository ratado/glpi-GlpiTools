<#
.SYNOPSIS
    Function is getting Line informations from GLPI
.DESCRIPTION
    Function is based on LineId which you can find in GLPI website
    Returns object with property's of Line
.PARAMETER All
    This parameter will return all Line from GLPI
.PARAMETER LineId
    This parameter can take pipline input, either, you can use this function with -LineId keyword.
    Provide to this param LineId from GLPI Line Bookmark
.PARAMETER Raw
    Parameter which you can use with LineId Parameter.
    LineId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER LineName
    This parameter can take pipline input, either, you can use this function with -LineId keyword.
    Provide to this param Line Name from GLPI Line Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsLines -All
    Example will return all Line from Glpi
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsLines
    Function gets LineId from GLPI from Pipline, and return Line object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsLines
    Function gets LineId from GLPI from Pipline (u can pass many ID's like that), and return Line object
.EXAMPLE
    PS C:\> Get-GlpiToolsLines -LineId 326
    Function gets LineId from GLPI which is provided through -LineId after Function type, and return Line object
.EXAMPLE 
    PS C:\> Get-GlpiToolsLines -LineId 326, 321
    Function gets Line Id from GLPI which is provided through -LineId keyword after Function type (u can provide many ID's like that), and return Line object
.EXAMPLE
    PS C:\> Get-GlpiToolsLines -LineName Fusion
    Example will return glpi Line, but what is the most important, Line will be shown exactly as you see in glpi dropdown Line.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.INPUTS
    Line ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Line from GLPI
.NOTES
    PSP 11/2019
#>

function Get-GlpiToolsLines {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "LineId")]
        [alias('LID')]
        [string[]]$LineId,
        [parameter(Mandatory = $false,
            ParameterSetName = "LineId")]
        [switch]$Raw,
        
        [parameter(Mandatory = $true,
            ParameterSetName = "LineName")]
        [alias('LN')]
        [string]$LineName
    )
    
    begin {
        $SessionToken = $Script:SessionToken    
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $LinesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Management/Line' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Line -Raw
                }
                LineId {
                    # the v3 answer already carries the names of the related items
                    foreach ($V3ItemId in $LineId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Management/Line/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Line ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Line -Raw:$Raw
                        }
                    }
                }
                LineName {
                    Search-GlpiToolsItems -SearchFor Line -SearchType contains -SearchValue $LineName | ConvertFrom-GlpiToolsV3Item -ItemType Line -Raw
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
                    uri     = "$($PathToGlpi)/Line/?range=0-9999999999999"
                }
                
                $LinesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($Line in $LinesAll) {
                    $LineHash = [ordered]@{ }
                    $LineProperties = $Line.PSObject.Properties | Select-Object -Property Name, Value 
                                
                    foreach ($LineProp in $LineProperties) {
                        $LineHash.Add($LineProp.Name, $LineProp.Value)
                    }
                    $object = [pscustomobject]$LineHash
                    $LinesArray.Add($object)
                }
                $LinesArray
                $LinesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            LineId { 
                foreach ( $LId in $LineId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Line/$($LId)"
                    }

                    Try {
                        $Line = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $LineHash = [ordered]@{ }
                            $LineProperties = $Line.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($LineProp in $LineProperties) {
                                $LineHash.Add($LineProp.Name, $LineProp.Value)
                            }
                            $object = [pscustomobject]$LineHash
                            $LinesArray.Add($object)
                        } else {
                            $LineHash = [ordered]@{ }
                            $LineProperties = $Line.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($LineProp in $LineProperties) {

                                $LinePropNewValue = Get-GlpiToolsParameters -Parameter $LineProp.Name -Value $LineProp.Value

                                $LineHash.Add($LineProp.Name, $LinePropNewValue)
                            }
                            $object = [pscustomobject]$LineHash
                            $LinesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Line ID = $LId is not found"
                        
                    }
                    $LinesArray
                    $LinesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            LineName { 
                Search-GlpiToolsItems -SearchFor Line -SearchType contains -SearchValue $LineName
            } 
            Default { }
        }
    }
    
    end {
        
    }
}