<#
.SYNOPSIS
    Runs the read operations of an item cmdlet on the GLPI API v3.
.DESCRIPTION
    Shared v3 branch of the Get-GlpiTools* cmdlets that list items, read items by ID and search items by name.
    The operation is chosen by the active parameter set of the cmdlet: a set called All lists the items,
    a set ending in Id reads each ID (a missing item is skipped, other failures are reported) and a set
    ending in Name searches by name. The answers are converted to the legacy properties.
.PARAMETER ParameterSetName
    Active parameter set of the calling cmdlet ($PSCmdlet.ParameterSetName).
.PARAMETER Resource
    Route of the item type in the API v3, for example /Assets/Computer.
.PARAMETER ItemType
    Item type of the field map used to convert the answer to the legacy properties.
.PARAMETER SearchFor
    Item type used by the name search. Default is the value of ItemType.
.PARAMETER SearchField
    Field used by the name search. Default is the name field.
.PARAMETER SearchInTrash
    Value forwarded to the name search when it is informed (Yes or No).
.PARAMETER Id
    IDs to read.
.PARAMETER Name
    Name to search.
.PARAMETER Raw
    Returns the IDs of the related items instead of their names, when reading by ID.
.PARAMETER AlwaysRaw
    Never converts the IDs of the related items to names, whatever Raw is.
.PARAMETER RequiredCriteria
    Criteria every listed item must meet. The default leaves the items in the trash out, as the legacy listing does;
    pass an empty array for a type that has no trash (RecurringTicket, Reminder...).
.PARAMETER Parameter
    Extra requested with the cmdlet parameter of the same name. Only WithDocuments is acted on here.
.PARAMETER SupportedParameter
    Extras that exist in the API v3. Default is ExpandDropdowns; any other extra stops the command with the standard error.
.EXAMPLE
    PS C:\> Invoke-GlpiToolsV3ItemQuery -ParameterSetName $PSCmdlet.ParameterSetName -Resource '/Assets/Computer' -ItemType Computer -Id $ComputerId -Name $ComputerName -Raw:$Raw
    Lists, reads or searches computers according to the parameter set of the calling cmdlet.
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    API v3 migration
#>

function Invoke-GlpiToolsV3ItemQuery {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ParameterSetName,

        [parameter(Mandatory = $true)]
        [string]$Resource,

        [parameter(Mandatory = $true)]
        [string]$ItemType,

        [parameter(Mandatory = $false)]
        [string]$SearchFor = $ItemType,

        [parameter(Mandatory = $false)]
        [string]$SearchField,

        [parameter(Mandatory = $false)]
        [string]$SearchInTrash,

        [parameter(Mandatory = $false)]
        $Id,

        [parameter(Mandatory = $false)]
        [string]$Name,

        [parameter(Mandatory = $false)]
        [switch]$Raw,

        [parameter(Mandatory = $false)]
        [switch]$AlwaysRaw,

        [parameter(Mandatory = $false)]
        [object[]]$RequiredCriteria = @(@{ Field = 'is_deleted'; Value = 0 }),

        [parameter(Mandatory = $false)]
        [string]$Parameter,

        [parameter(Mandatory = $false)]
        [string[]]$SupportedParameter = @('ExpandDropdowns')
    )

    if ($Raw -and (Get-GlpiToolsOutputFormat) -eq 'Native') {
        Write-Verbose -Message "-Raw has no effect with the native output format."
    }

    # the active parameter set tells the operation, because pipeline input is not bound yet in the begin block
    switch -Wildcard ($ParameterSetName) {
        'All' {
            $V3List = @{ Method = 'Get'; Resource = $Resource; All = $true }
            if ($RequiredCriteria) {
                $V3List.Query = @{ filter = (ConvertTo-GlpiToolsRsql -Required $RequiredCriteria) }
            }
            Invoke-GlpiToolsRequest @V3List | ConvertFrom-GlpiToolsV3Item -ItemType $ItemType -Raw
        }
        '*Id' {
            # the v3 answer already carries the names of the related items; only the extras that exist in the v3 are supported
            if ($Parameter -and $Parameter -notin $SupportedParameter) {
                Assert-GlpiToolsV3Supported -Name "-Parameter $Parameter"
            }
            foreach ($V3ItemId in $Id) {
                $V3Item = $null
                try {
                    $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "$Resource/$V3ItemId"
                } catch {
                    # only a missing item is skipped; other failures are reported
                    if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                    Write-Verbose -Message "$ItemType ID = $V3ItemId is not found"
                }
                if ($V3Item) {
                    if ($Parameter -eq 'WithDocuments') {
                        $V3Documents = @()
                        try {
                            $V3Documents = @(Invoke-GlpiToolsRequest -Method Get -Resource "$Resource/$V3ItemId/Timeline/Document" -All)
                        } catch {
                            # an item without readable documents is still returned
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                        }
                        $V3Item | Add-Member -NotePropertyName '_documents' -NotePropertyValue $V3Documents
                    }
                    # the legacy properties are returned, converted to names unless Raw is used or the legacy command does not convert
                    $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType $ItemType -Raw:($Raw -or $AlwaysRaw)
                }
            }
        }
        '*Name' {
            $V3Search = @{ SearchFor = $SearchFor; SearchType = 'contains'; SearchValue = $Name }
            if ($SearchField) { $V3Search.SearchField = $SearchField }
            if ($PSBoundParameters.ContainsKey('SearchInTrash')) { $V3Search.SearchInTrash = $SearchInTrash }
            Search-GlpiToolsItems @V3Search | ConvertFrom-GlpiToolsV3Item -ItemType $ItemType -Raw
        }
    }
}
