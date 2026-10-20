<#
.SYNOPSIS
    Function is getting Pdu informations from GLPI
.DESCRIPTION
    Function is based on PduID which you can find in GLPI website
    Returns object with property's of Pdu
.PARAMETER All
    This parameter will return all Pdus from GLPI
.PARAMETER PduId
    This parameter can take pipline input, either, you can use this function with -PduId keyword.
    Provide to this param Pdu ID from GLPI Pdus Bookmark
.PARAMETER Raw
    Parameter which you can use with PduId Parameter.
    PduId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER PduName
    Provide to this param Pdu Name from GLPI Pdus Bookmark
.PARAMETER SearchInTrash
    Parameter which you can use with PduName Parameter.
    If you want Search for Pdu name in trash, that parameter allow you to do it.
.PARAMETER Parameter
    Parameter which you can use with PduId Parameter. 
    If you want to get additional parameter of Pdu object like, disks, or logs, use this parameter.
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsPdus
    Function gets PduID from GLPI from Pipline, and return Pdu object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsPdus
    Function gets PduID from GLPI from Pipline (u can pass many ID's like that), and return Pdu object
.EXAMPLE
    PS C:\> Get-GlpiToolsPdus -PduId 326
    Function gets PduID from GLPI which is provided through -PduId after Function type, and return Pdu object
.EXAMPLE 
    PS C:\> Get-GlpiToolsPdus -PduId 326, 321
    Function gets PduID from GLPI which is provided through -PduId keyword after Function type (u can provide many ID's like that), and return Pdu object
.EXAMPLE
    PS C:\> Get-GlpiToolsPdus -PduId 234 -Raw
    Example will show Pdu with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> 234 | Get-GlpiToolsPdus -Raw
    Example will show Pdu with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> Get-GlpiToolsPdus -PduName glpi
    Example will return glpi Pdu, but what is the most important, Pdu will be shown exacly as you see in glpi Pdus tab.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.EXAMPLE
    PS C:\> Get-GlpiToolsPdus -PduName glpi -SearchInTrash Yes
    Example will return glpi Pdu, but from trash
.INPUTS
    Pdu ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Pdus from GLPI
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsPdus {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,

        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "PduId")]
        [alias('PID')]
        [string[]]$PduId,
        [parameter(Mandatory = $false,
            ParameterSetName = "PduId")]
        [switch]$Raw,

        [parameter(Mandatory = $true,
            ParameterSetName = "PduName")]
        [alias('PN')]
        [string]$PduName,
        [parameter(Mandatory = $false,
            ParameterSetName = "PduName")]
        [alias('SIT')]
        [ValidateSet("Yes", "No")]
        [string]$SearchInTrash = "No",

        [parameter(Mandatory = $false,
            ParameterSetName = "PduId")]
        [alias('Param')]
        [ValidateSet("ExpandDropdowns",
            "GetHateoas",
            "GetSha1",
            "WithDevices",
            "WithDisks",
            "WithSoftwares",
            "WithConnections",
            "WithNetworkports",
            "WithInfocoms",
            "WithContracts",
            "WithDocuments",
            "WithTickets",
            "WithProblems",
            "WithChanges",
            "WithNotes",
            "WithLogs")]
        [string]$Parameter
    )
    
    begin {

        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi
        $SessionToken = $Script:SessionToken

        $AppToken = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty PathToGlpi
        $SessionToken = Get-GlpiToolsSessionToken -Verbose:$false | Select-Object -ExpandProperty SessionToken

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $PduObjectArray = [System.Collections.Generic.List[PSObject]]::New()

        switch ($Parameter) {
            ExpandDropdowns { $ParamValue = "?expand_dropdowns=true" }
            GetHateoas { $ParamValue = "?get_hateoas=true" }
            GetSha1 { $ParamValue = "?get_sha1=true" }
            WithDevices { $ParamValue = "?with_devices=true" }
            WithDisks { $ParamValue = "?with_disks=true" }
            WithSoftwares { $ParamValue = "?with_softwares=true" }
            WithConnections { $ParamValue = "?with_connections=true" }
            WithNetworkports { $ParamValue = "?with_networkports=true" }
            WithInfocoms { $ParamValue = "?with_infocoms=true" }
            WithContracts { $ParamValue = "?with_contracts=true" }
            WithDocuments { $ParamValue = "?with_documents=true" }
            WithTickets { $ParamValue = "?with_tickets=true" } 
            WithProblems { $ParamValue = "?with_problems=true" }
            WithChanges { $ParamValue = "?with_changes=true" }
            WithNotes { $ParamValue = "?with_notes=true" } 
            WithLogs { $ParamValue = "?with_logs=true" }
            Default { $ParamValue = "" }
        }

    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/PDU' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Pdu -Raw
                }
                PduId {
                    # the v3 answer already carries the names of the related items; only the extras that exist in the v3 are supported
                    if ($Parameter -and $Parameter -ne 'ExpandDropdowns') {
                        Assert-GlpiToolsV3Supported -Name "-Parameter $Parameter"
                    }
                    foreach ($V3ItemId in $PduId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Assets/PDU/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Pdu ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Pdu -Raw:$Raw
                        }
                    }
                }
                PduName {
                    Search-GlpiToolsItems -SearchFor Pdu -SearchType contains -SearchValue $PduName -SearchInTrash $SearchInTrash | ConvertFrom-GlpiToolsV3Item -ItemType Pdu -Raw
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
                    uri     = "$($PathToGlpi)/Pdu/?range=0-9999999999999"
                }
                
                $GlpiPduAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiPdu in $GlpiPduAll) {
                    $PduHash = [ordered]@{ }
                            $PduProperties = $GlpiPdu.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($PduProp in $PduProperties) {
                                $PduHash.Add($PduProp.Name, $PduProp.Value)
                            }
                            $object = [pscustomobject]$PduHash
                            $PduObjectArray.Add($object)
                }
                $PduObjectArray
                $PduObjectArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            PduId { 
                foreach ( $PId in $PduId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Pdu/$($PId)$ParamValue"
                    }

                    Try {
                        $GlpiPdu = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $PduHash = [ordered]@{ }
                            $PduProperties = $GlpiPdu.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($PduProp in $PduProperties) {
                                $PduHash.Add($PduProp.Name, $PduProp.Value)
                            }
                            $object = [pscustomobject]$PduHash
                            $PduObjectArray.Add($object)
                        } else {
                            $PduHash = [ordered]@{ }
                            $PduProperties = $GlpiPdu.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($PduProp in $PduProperties) {

                                $PduPropNewValue = Get-GlpiToolsParameters -Parameter $PduProp.Name -Value $PduProp.Value

                                $PduHash.Add($PduProp.Name, $PduPropNewValue)
                            }
                            $object = [pscustomobject]$PduHash
                            $PduObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Pdu ID = $PId is not found"
                        
                    }
                    $PduObjectArray
                    $PduObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            PduName { 
                Search-GlpiToolsItems -SearchFor Pdu -SearchType contains -SearchValue $PduName -SearchInTrash $SearchInTrash
            }
            Default {
                
            }
        }
    }
    
    end {
    
    }
}