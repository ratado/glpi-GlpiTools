<#
.SYNOPSIS
    Function is getting Ticket informations from GLPI
.DESCRIPTION
    Function is based on TicketID which you can find in GLPI website
    Returns object with property's of Ticket
.PARAMETER All
    This parameter will return all Tickets from GLPI
.PARAMETER TicketId
    This parameter can take pipline input, either, you can use this function with -TicketId keyword.
    Provide to this param Ticket ID from GLPI Tickets Bookmark
.PARAMETER Raw
    Parameter which you can use with TicketId Parameter.
    TicketId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER TicketName
    Provide to this param Ticket Name from GLPI Tickets Bookmark
.PARAMETER SearchInTrash
    Parameter which you can use with TicketName Parameter.
    If you want Search for Ticket name in trash, that parameter allow you to do it.
.PARAMETER Parameter
    Parameter which you can use with TicketId Parameter. 
    If you want to get additional parameter of Ticket object like, disks, or logs, use this parameter.
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsTickets
    Function gets TicketID from GLPI from Pipline, and return Ticket object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsTickets
    Function gets TicketID from GLPI from Pipline (u can pass many ID's like that), and return Ticket object
.EXAMPLE
    PS C:\> Get-GlpiToolsTickets -TicketId 326
    Function gets TicketID from GLPI which is provided through -TicketId after Function type, and return Ticket object
.EXAMPLE 
    PS C:\> Get-GlpiToolsTickets -TicketId 326, 321
    Function gets TicketID from GLPI which is provided through -TicketId keyword after Function type (u can provide many ID's like that), and return Ticket object
.EXAMPLE
    PS C:\> Get-GlpiToolsTickets -TicketId 234 -Raw
    Example will show Ticket with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> 234 | Get-GlpiToolsTickets -Raw
    Example will show Ticket with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> Get-GlpiToolsTickets -TicketName glpi
    Example will return glpi Ticket, but what is the most important, Ticket will be shown exacly as you see in glpi Tickets tab.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.EXAMPLE
    PS C:\> Get-GlpiToolsTickets -TicketName glpi -SearchInTrash Yes
    Example will return glpi Ticket, but from trash
.INPUTS
    Ticket ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Tickets from GLPI
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsTickets {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,

        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "TicketId")]
        [alias('TID')]
        [string[]]$TicketId,
        [parameter(Mandatory = $false,
            ParameterSetName = "TicketId")]
        [switch]$Raw,

        [parameter(Mandatory = $true,
            ParameterSetName = "TicketName")]
        [alias('TN')]
        [string]$TicketName,
        [parameter(Mandatory = $false,
            ParameterSetName = "TicketName")]
        [alias('SIT')]
        [ValidateSet("Yes", "No")]
        [string]$SearchInTrash = "No",

        [parameter(Mandatory = $false,
            ParameterSetName = "TicketId")]
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

        $TicketObjectArray = [System.Collections.Generic.List[PSObject]]::New()

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
                    # the legacy listing leaves the trash out
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Ticket -Raw
                }
                TicketId {
                    # the v3 answer already carries the names of the related items; only the extras that exist in the v3 are supported
                    if ($Parameter -and $Parameter -notin 'ExpandDropdowns', 'WithDocuments') {
                        Assert-GlpiToolsV3Supported -Name "-Parameter $Parameter"
                    }
                    foreach ($TId in $TicketId) {
                        $V3Ticket = $null
                        try {
                            $V3Ticket = Invoke-GlpiToolsRequest -Method Get -Resource "/Assistance/Ticket/$TId"
                        } catch {
                            # only a missing ticket is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Ticket ID = $TId is not found"
                        }
                        if ($V3Ticket) {
                            if ($Parameter -eq 'WithDocuments') {
                                $V3Documents = @()
                                try {
                                    $V3Documents = @(Invoke-GlpiToolsRequest -Method Get -Resource "/Assistance/Ticket/$TId/Timeline/Document" -All)
                                } catch {
                                    # a ticket without readable documents is still returned
                                    if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                                }
                                $V3Ticket | Add-Member -NotePropertyName '_documents' -NotePropertyValue $V3Documents
                            }
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Ticket | ConvertFrom-GlpiToolsV3Item -ItemType Ticket -Raw:$Raw
                        }
                    }
                }
                TicketName {
                    Search-GlpiToolsItems -SearchFor Ticket -SearchType contains -SearchValue $TicketName -SearchInTrash $SearchInTrash
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
                    uri     = "$($PathToGlpi)/Ticket/?range=0-9999999999999"
                }
                
                $GlpiTicketAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiTicket in $GlpiTicketAll) {
                    $TicketHash = [ordered]@{ }
                            $TicketProperties = $GlpiTicket.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($TicketProp in $TicketProperties) {
                                $TicketHash.Add($TicketProp.Name, $TicketProp.Value)
                            }
                            $object = [pscustomobject]$TicketHash
                            $TicketObjectArray.Add($object)
                }
                $TicketObjectArray
                $TicketObjectArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            TicketId { 
                foreach ( $TId in $TicketId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Ticket/$($TId)$ParamValue"
                    }

                    Try {
                        $GlpiTicket = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $TicketHash = [ordered]@{ }
                            $TicketProperties = $GlpiTicket.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($TicketProp in $TicketProperties) {
                                $TicketHash.Add($TicketProp.Name, $TicketProp.Value)
                            }
                            $object = [pscustomobject]$TicketHash
                            $TicketObjectArray.Add($object)
                        } else {
                            $TicketHash = [ordered]@{ }
                            $TicketProperties = $GlpiTicket.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($TicketProp in $TicketProperties) {

                                $TicketPropNewValue = Get-GlpiToolsParameters -Parameter $TicketProp.Name -Value $TicketProp.Value

                                $TicketHash.Add($TicketProp.Name, $TicketPropNewValue)
                            }
                            $object = [pscustomobject]$TicketHash
                            $TicketObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Ticket ID = $TId is not found"
                        
                    }
                    $TicketObjectArray
                    $TicketObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            TicketName { 
                Search-GlpiToolsItems -SearchFor Ticket -SearchType contains -SearchValue $TicketName -SearchInTrash $SearchInTrash
            }
            Default {
                
            }
        }
    }
    
    end {
    
    }
}