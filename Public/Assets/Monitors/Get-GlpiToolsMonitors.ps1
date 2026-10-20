<#
.SYNOPSIS
    Function is getting Monitor informations from GLPI
.DESCRIPTION
    Function is based on MonitorID which you can find in GLPI website
    Returns object with property's of Monitor
.PARAMETER All
    This parameter will return all Monitors from GLPI
.PARAMETER MonitorId
    This parameter can take pipline input, either, you can use this function with -MonitorId keyword.
    Provide to this param Monitor ID from GLPI Monitors Bookmark
.PARAMETER Raw
    Parameter which you can use with MonitorId Parameter.
    MonitorId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER MonitorName
    Provide to this param Monitor Name from GLPI Monitors Bookmark
.PARAMETER SearchInTrash
    Parameter which you can use with MonitorName Parameter.
    If you want Search for Monitor name in trash, that parameter allow you to do it.
.PARAMETER Parameter
    Parameter which you can use with MonitorId Parameter. 
    If you want to get additional parameter of Monitor object like, disks, or logs, use this parameter.
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsMonitors
    Function gets MonitorID from GLPI from Pipline, and return Monitor object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsMonitors
    Function gets MonitorID from GLPI from Pipline (u can pass many ID's like that), and return Monitor object
.EXAMPLE
    PS C:\> Get-GlpiToolsMonitors -MonitorId 326
    Function gets MonitorID from GLPI which is provided through -MonitorId after Function type, and return Monitor object
.EXAMPLE 
    PS C:\> Get-GlpiToolsMonitors -MonitorId 326, 321
    Function gets MonitorID from GLPI which is provided through -MonitorId keyword after Function type (u can provide many ID's like that), and return Monitor object
.EXAMPLE
    PS C:\> Get-GlpiToolsMonitors -MonitorId 234 -Raw
    Example will show Monitor with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> 234 | Get-GlpiToolsMonitors -Raw
    Example will show Monitor with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> Get-GlpiToolsMonitors -MonitorName glpi
    Example will return glpi Monitor, but what is the most important, Monitor will be shown exacly as you see in glpi Monitors tab.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.EXAMPLE
    PS C:\> Get-GlpiToolsMonitors -MonitorName glpi -SearchInTrash Yes
    Example will return glpi Monitor, but from trash
.INPUTS
    Monitor ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Monitors from GLPI
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsMonitors {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,

        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "MonitorId")]
        [alias('MID')]
        [string[]]$MonitorId,
        [parameter(Mandatory = $false,
            ParameterSetName = "MonitorId")]
        [switch]$Raw,

        [parameter(Mandatory = $true,
            ParameterSetName = "MonitorName")]
        [alias('MN')]
        [string]$MonitorName,
        [parameter(Mandatory = $false,
            ParameterSetName = "MonitorName")]
        [alias('SIT')]
        [ValidateSet("Yes", "No")]
        [string]$SearchInTrash = "No",

        [parameter(Mandatory = $false,
            ParameterSetName = "MonitorId")]
        [alias('Param')]
        [ValidateSet("ExpandDropdowns",
            "GetHateoas",
            "GetSha1",
            "WithDevices",
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

        $MonitorObjectArray = [System.Collections.Generic.List[PSObject]]::New()

        switch ($Parameter) {
            ExpandDropdowns { $ParamValue = "?expand_dropdowns=true" }
            GetHateoas { $ParamValue = "?get_hateoas=true" }
            GetSha1 { $ParamValue = "?get_sha1=true" }
            WithDevices { $ParamValue = "?with_devices=true" }
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
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/Monitor' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Monitor -Raw
                }
                MonitorId {
                    # the v3 answer already carries the names of the related items; only the extras that exist in the v3 are supported
                    if ($Parameter -and $Parameter -ne 'ExpandDropdowns') {
                        Assert-GlpiToolsV3Supported -Name "-Parameter $Parameter"
                    }
                    foreach ($V3ItemId in $MonitorId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Assets/Monitor/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Monitor ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Monitor -Raw:$Raw
                        }
                    }
                }
                MonitorName {
                    Search-GlpiToolsItems -SearchFor Monitor -SearchType contains -SearchValue $MonitorName -SearchInTrash $SearchInTrash | ConvertFrom-GlpiToolsV3Item -ItemType Monitor -Raw
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
                    uri     = "$($PathToGlpi)/Monitor/?range=0-9999999999999"
                }
                
                $GlpiMonitorAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiMonitor in $GlpiMonitorAll) {
                    $MonitorHash = [ordered]@{ }
                            $MonitorProperties = $GlpiMonitor.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($MonitorProp in $MonitorProperties) {
                                $MonitorHash.Add($MonitorProp.Name, $MonitorProp.Value)
                            }
                            $object = [pscustomobject]$MonitorHash
                            $MonitorObjectArray.Add($object)
                }
                $MonitorObjectArray
                $MonitorObjectArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            MonitorId { 
                foreach ( $MId in $MonitorId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Monitor/$($MId)$ParamValue"
                    }

                    Try {
                        $GlpiMonitor = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $MonitorHash = [ordered]@{ }
                            $MonitorProperties = $GlpiMonitor.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($MonitorProp in $MonitorProperties) {
                                $MonitorHash.Add($MonitorProp.Name, $MonitorProp.Value)
                            }
                            $object = [pscustomobject]$MonitorHash
                            $MonitorObjectArray.Add($object)
                        } else {
                            $MonitorHash = [ordered]@{ }
                            $MonitorProperties = $GlpiMonitor.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($MonitorProp in $MonitorProperties) {

                                $MonitorPropNewValue = Get-GlpiToolsParameters -Parameter $MonitorProp.Name -Value $MonitorProp.Value

                                $MonitorHash.Add($MonitorProp.Name, $MonitorPropNewValue)

                            }
                            $object = [pscustomobject]$MonitorHash
                            $MonitorObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Monitor ID = $MId is not found"
                        
                    }
                    $MonitorObjectArray
                    $MonitorObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            MonitorName { 
                Search-GlpiToolsItems -SearchFor Monitor -SearchType contains -SearchValue $MonitorName -SearchInTrash $SearchInTrash
            }
            Default {
                
            }
        }
    }
    
    end {
    
    }
}