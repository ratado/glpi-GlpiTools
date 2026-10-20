<#
.SYNOPSIS
    Function is getting Phone informations from GLPI
.DESCRIPTION
    Function is based on PhoneID which you can find in GLPI website
    Returns object with property's of Phone
.PARAMETER All
    This parameter will return all Phones from GLPI
.PARAMETER PhoneId
    This parameter can take pipline input, either, you can use this function with -PhoneId keyword.
    Provide to this param Phone ID from GLPI Phones Bookmark
.PARAMETER Raw
    Parameter which you can use with PhoneId Parameter.
    PhoneId has converted parameters from default, parameter Raw allows not convert this parameters.
.PARAMETER PhoneName
    Provide to this param Phone Name from GLPI Phones Bookmark
.PARAMETER SearchInTrash
    Parameter which you can use with PhoneName Parameter.
    If you want Search for Phone name in trash, that parameter allow you to do it.
.PARAMETER Parameter
    Parameter which you can use with PhoneId Parameter. 
    If you want to get additional parameter of Phone object like, disks, or logs, use this parameter.
.EXAMPLE
    PS C:\> 326 | Get-GlpiToolsPhones
    Function gets PhoneID from GLPI from Pipline, and return Phone object
.EXAMPLE
    PS C:\> 326, 321 | Get-GlpiToolsPhones
    Function gets PhoneID from GLPI from Pipline (u can pass many ID's like that), and return Phone object
.EXAMPLE
    PS C:\> Get-GlpiToolsPhones -PhoneId 326
    Function gets PhoneID from GLPI which is provided through -PhoneId after Function type, and return Phone object
.EXAMPLE 
    PS C:\> Get-GlpiToolsPhones -PhoneId 326, 321
    Function gets PhoneID from GLPI which is provided through -PhoneId keyword after Function type (u can provide many ID's like that), and return Phone object
.EXAMPLE
    PS C:\> Get-GlpiToolsPhones -PhoneId 234 -Raw
    Example will show Phone with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> 234 | Get-GlpiToolsPhones -Raw
    Example will show Phone with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> Get-GlpiToolsPhones -PhoneName glpi
    Example will return glpi Phone, but what is the most important, Phone will be shown exacly as you see in glpi Phones tab.
    If you want to add parameter, you have to modify "default items to show". This is the "key/tool" icon near search.
.EXAMPLE
    PS C:\> Get-GlpiToolsPhones -PhoneName glpi -SearchInTrash Yes
    Example will return glpi Phone, but from trash
.INPUTS
    Phone ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of Phones from GLPI
.NOTES
    PSP 05/2019
#>

function Get-GlpiToolsPhones {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,

        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "PhoneId")]
        [alias('PID')]
        [string[]]$PhoneId,
        [parameter(Mandatory = $false,
            ParameterSetName = "PhoneId")]
        [switch]$Raw,

        [parameter(Mandatory = $true,
            ParameterSetName = "PhoneName")]
        [alias('PN')]
        [string]$PhoneName,
        [parameter(Mandatory = $false,
            ParameterSetName = "PhoneName")]
        [alias('SIT')]
        [ValidateSet("Yes", "No")]
        [string]$SearchInTrash = "No",

        [parameter(Mandatory = $false,
            ParameterSetName = "PhoneId")]
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

        $PhoneObjectArray = [System.Collections.Generic.List[PSObject]]::New()

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
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/Phone' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Phone -Raw
                }
                PhoneId {
                    # the v3 answer already carries the names of the related items; only the extras that exist in the v3 are supported
                    if ($Parameter -and $Parameter -ne 'ExpandDropdowns') {
                        Assert-GlpiToolsV3Supported -Name "-Parameter $Parameter"
                    }
                    foreach ($V3ItemId in $PhoneId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Assets/Phone/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Phone ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Phone -Raw:$Raw
                        }
                    }
                }
                PhoneName {
                    Search-GlpiToolsItems -SearchFor Phone -SearchType contains -SearchValue $PhoneName -SearchInTrash $SearchInTrash | ConvertFrom-GlpiToolsV3Item -ItemType Phone -Raw
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
                    uri     = "$($PathToGlpi)/Phone/?range=0-9999999999999"
                }
                
                $GlpiPhoneAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiPhone in $GlpiPhoneAll) {
                    $PhoneHash = [ordered]@{ }
                            $PhoneProperties = $GlpiPhone.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($PhoneProp in $PhoneProperties) {
                                $PhoneHash.Add($PhoneProp.Name, $PhoneProp.Value)
                            }
                            $object = [pscustomobject]$PhoneHash
                            $PhoneObjectArray.Add($object)
                }
                $PhoneObjectArray
                $PhoneObjectArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            PhoneId { 
                foreach ( $PId in $PhoneId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Phone/$($PId)$ParamValue"
                    }

                    Try {
                        $GlpiPhone = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $PhoneHash = [ordered]@{ }
                            $PhoneProperties = $GlpiPhone.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($PhoneProp in $PhoneProperties) {
                                $PhoneHash.Add($PhoneProp.Name, $PhoneProp.Value)
                            }
                            $object = [pscustomobject]$PhoneHash
                            $PhoneObjectArray.Add($object)
                        } else {
                            $PhoneHash = [ordered]@{ }
                            $PhoneProperties = $GlpiPhone.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($PhoneProp in $PhoneProperties) {

                                $PhonePropNewValue = Get-GlpiToolsParameters -Parameter $PhoneProp.Name -Value $PhoneProp.Value
                                $PhoneHash.Add($PhoneProp.Name, $PhonePropNewValue)

                            }
                            $object = [pscustomobject]$PhoneHash
                            $PhoneObjectArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Phone ID = $PId is not found"
                        
                    }
                    $PhoneObjectArray
                    $PhoneObjectArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            PhoneName { 
                Search-GlpiToolsItems -SearchFor Phone -SearchType contains -SearchValue $PhoneName -SearchInTrash $SearchInTrash
            }
            Default {
                
            }
        }
    }
    
    end {
    
    }
}