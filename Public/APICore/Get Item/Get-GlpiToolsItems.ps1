<#
.SYNOPSIS
    Function is getting all the items of a specific type in GLPI (also feature SearchText).
.DESCRIPTION
    Function is getting all the items of a specific type in GLPI.
    Can be filter with SearchText paramter
    Like https://github.com/glpi-project/glpi/blob/master/apirest.md#get-all-items
.PARAMETER ItemType
    Type of item wanted.
    Exemples : Computer, Monitor, User, Group_Ticket, Group_User, etc.
.PARAMETER SearchText
    SearchText (default NULL): hashtable of filters to pass on the query (with key = field and value = the text to search).
    By default it act as a '-like "*value*"'. Use ^ and $ to force an exact match. Eg. SearchText = @{"groups_id"="^10$" ; "type"="^2$"}
    This parameter can take pipeline input.
.PARAMETER Raw
    Raw is always ON if the return contain more that one object.
    If the return contain only one object and RAW is not use, parameters will be converted (expanded to show name instead of ID).
    Use the parameter RAW to force to show ID in ALL cases.
.PARAMETER OnlyId
    (default: false): keep only id keys in returned data. Optional.
.PARAMETER SearchInTrash
    (default: false): Return deleted element. Optional
.PARAMETER ExtraParameter
    String append to the query for extra option. Refer to apirest.php.
    Ex. "&only_id=true" or "&with_infocoms", etc..
.EXAMPLE
    PS C:\> Get-GlpiToolsItems -ItemType "Group_Ticket"
    Function gets all items from Group_Ticket
.EXAMPLE
    PS C:\> @{"groups_id"="^10$" ; "type"="^2$"} | Get-GlpiToolsItems -ItemType "Group_Ticket"
    Function gets SearchCriteria from Pipeline, and return GLPI object
.EXAMPLE
    PS C:\> @{"groups_id"="^10$" ; "type"="^2$"}  , @{"groups_id"="^15$" ; "type"="^2$"}  | Get-GlpiToolsItems -ItemType "Group_Ticket"
    Function gets multiple SearchCriteria from Pipeline, and return GLPI object
.EXAMPLE
    PS C:\> Get-GlpiToolsItems -ItemType "Group_Ticket" -SearchText @{"groups_id"="^10$" ; "type"="^2$"}
    Function gets GLPI object filter by SearchText.
.EXAMPLE
    PS C:\> Get-GlpiToolsItems -ItemType "Ticket" -SearchText @{"id"="^234$"}  -Raw
    Example will show Ticket with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> @{"id"="^234$"} | Get-GlpiToolsItems -ItemType "Ticket" -Raw
    Example will show Ticket with id 234, but without any parameter converted
.EXAMPLE
    PS C:\> Get-GlpiToolsItems -ItemType "Ticket" -SearchInTrash $true
    Example will return glpi Ticket, but from trash
.INPUTS
    SearchText hashtable.
.OUTPUTS
    Function returns PSCustomObject with property's of Object from GLPI
.NOTES
    SilentBob999 10/2019
#>

function Get-GlpiToolsItems{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [alias('Type')]
        [string]$ItemType,

        [parameter(Mandatory = $false,
            ValueFromPipeline = $true)]
        [alias('Search')]
        [hashtable]$SearchText,

        [parameter(Mandatory = $false)]
        [bool]$Raw = $false,

        [parameter(Mandatory = $false)]
        [alias('SIT')]
        [bool]$SearchInTrash = $false,

        [parameter(Mandatory = $false)]
        [bool]$OnlyId = $false,

        [parameter(Mandatory = $false)]
        [alias('Param')]
        [string]$ExtraParameter

    )

    begin {

        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi
        $SessionToken = $Script:SessionToken

        $AppToken = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig -Verbose:$false | Select-Object -ExpandProperty PathToGlpi
        $SessionToken = Get-GlpiToolsSessionToken -Verbose:$false | Select-Object -ExpandProperty SessionToken

        $GlpiObjectArray = [System.Collections.Generic.List[PSObject]]::New()

        if ($SearchInTrash) { $IsDeletedString = "&is_deleted=true" }
        if ($OnlyId) { $OnlyIdString = "&only_id=true" }

    }

    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            if ($ExtraParameter) {
                Assert-GlpiToolsV3Supported -Name '-ExtraParameter'
            }
            # -SearchText matches the text inside each field, like the legacy searchText
            $Criteria = @()
            foreach ($key in $SearchText.Keys) {
                # the legacy text is a regular expression: the anchors ^ and $ select equals, starts with or ends with
                $V3Text = [string]$SearchText[$key]
                $V3Operator = 'contains'
                if ($V3Text -match '^\^(.*)\$$') { $V3Operator = 'equals'; $V3Text = $Matches[1] }
                elseif ($V3Text -match '^\^(.*)$') { $V3Operator = 'startswith'; $V3Text = $Matches[1] }
                elseif ($V3Text -match '^(.*)\$$') { $V3Operator = 'endswith'; $V3Text = $Matches[1] }
                $Criteria += @{ Field = (ConvertTo-GlpiToolsV3FieldName -ItemType $ItemType -Name $key); Operator = $V3Operator; Value = $V3Text }
            }
            # the legacy API lists items outside the trash unless -SearchInTrash is used
            $V3Required = @{ Field = 'is_deleted'; Operator = 'equals'; Value = $(if ($SearchInTrash) { 1 } else { 0 }) }
            $V3Items = Invoke-GlpiToolsRequest -Method Get -Resource (Get-GlpiToolsV3Route -ItemType $ItemType) -Query @{ filter = (ConvertTo-GlpiToolsRsql -Criteria $Criteria -Required $V3Required -ItemType $ItemType) } -All
            if ($OnlyId) {
                $V3Items | Select-Object -Property id
                return
            }
            # like the legacy command, several results are returned raw; a type without a map keeps the v3 format
            if (Get-GlpiToolsV3FieldMap -ItemType $ItemType) {
                if (-not $Raw -and (@($V3Items).Count -gt 1) -and (Get-GlpiToolsOutputFormat) -eq 'Legacy') { Write-Warning "RAW forced because more than 1 result" }
                $V3Items | ConvertFrom-GlpiToolsV3Item -ItemType $ItemType -Raw:($Raw -or (@($V3Items).Count -gt 1))
            } else {
                Write-Verbose -Message "There is no field map for '$ItemType'; the v3 format is returned."
                $V3Items
            }
            return
        }


        $SearchTextString = ""
        foreach ($key in $SearchText.Keys) {
            $SearchTextString += "&searchText[$($key)]=$($SearchText[$key])"
        }

        $params = @{
            headers = @{
                'Content-Type'  = 'application/json'
                'App-Token'     = $AppToken
                'Session-Token' = $SessionToken
            }
            method  = 'get'
            uri     = "$($PathToGlpi)/$($ItemType)/?range=0-9999999999999$($SearchTextString)$($IsDeletedString)$($OnlyIdString)$($ExtraParameter)"
        }

        $GlpiObjectAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false
        if (-not $Raw -and (@($GlpiObjectAll).count -gt 1)) {Write-Warning "RAW forced because more than 1 result"}

        foreach ($GlpiObject in $GlpiObjectAll) {
            if ($Raw -or (@($GlpiObjectAll).count -gt 1) ) {
                $ObjectHash = [ordered]@{ }
                $ObjectProperties = $GlpiObject.PSObject.Properties | Select-Object -Property Name, Value

                foreach ($ObjectProp in $ObjectProperties) {
                    $ObjectHash.Add($ObjectProp.Name, $ObjectProp.Value)
                }
                $object = [pscustomobject]$ObjectHash
                $GlpiObjectArray.Add($object)
            } else {
                $ObjectHash = [ordered]@{ }
                $ObjectProperties = $GlpiObject.PSObject.Properties | Select-Object -Property Name, Value

                foreach ($ObjectProp in $ObjectProperties) {

                    $ObjectPropNewValue = Get-GlpiToolsParameters -Parameter $ObjectProp.Name -Value $ObjectProp.Value

                    $ObjectHash.Add($ObjectProp.Name, $ObjectPropNewValue)
                }
                $object = [pscustomobject]$ObjectHash
                $GlpiObjectArray.Add($object)
            }
        }

        $GlpiObjectArray
        $GlpiObjectArray = [System.Collections.Generic.List[PSObject]]::New()

    }

    end {
        
    }
}

$ItemTypeValidate = {
    param ($commandName, $parameterName, $stringMatch)
    $ModulePath = Split-Path (Get-Module -Name GlpiTools).Path -Parent
    (Get-Content "$($ModulePath)\Private\Parameters.json" | ConvertFrom-Json).GlpiComponents | Where-Object {$_ -match "$stringMatch"}
}
Register-ArgumentCompleter -CommandName Get-GlpiToolsItems -ParameterName ItemType -ScriptBlock $ItemTypeValidate