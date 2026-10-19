<#
.SYNOPSIS
    Sends a request to the GLPI API v3.
.DESCRIPTION
    Builds the URL, headers, query string and JSON body of a request, adds the OAuth bearer token
    (renewed automatically), reads every page when asked, and turns HTTP errors into exceptions with
    the status and the message returned by GLPI. A rejected token (401, or 400 "Invalid OAuth token") renews the token and repeats the
    request once. Tokens and secrets are never written to the output.
.PARAMETER Method
    HTTP method: Get, Post, Patch or Delete.
.PARAMETER Resource
    Resource path after the API base URL, for example /Assistance/Ticket/2.
.PARAMETER Query
    Query string parameters (filter, sort, start, limit, ...) as a hashtable.
.PARAMETER Body
    Request body as a hashtable, sent as JSON.
.PARAMETER All
    Reads every page of a listing and returns all items.
.PARAMETER Accept
    Accept header of the request. Default is application/json.
.PARAMETER NoContext
    Does not send the entity and profile chosen with Set-GlpiToolsChangeActiveEntities and
    Set-GlpiToolsChangeActiveProfile, for questions about what the user can reach at all.
.PARAMETER PageSize
    Number of items per page when -All is used. Default is 500.
.EXAMPLE
    PS C:\> Invoke-GlpiToolsRequest -Method Get -Resource /Assistance/Ticket/2
    Returns the ticket 2.
.EXAMPLE
    PS C:\> Invoke-GlpiToolsRequest -Method Get -Resource /Assets/Computer -All
    Returns all computers, reading as many pages as needed.
.INPUTS
    None
.OUTPUTS
    The deserialized response. With -All, an array with the items of all pages.
.NOTES
    API v3 migration
#>

function Invoke-GlpiToolsRequest {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Post', 'Patch', 'Delete')]
        [string]$Method,

        [parameter(Mandatory = $true)]
        [string]$Resource,

        [parameter(Mandatory = $false)]
        [hashtable]$Query,

        [parameter(Mandatory = $false)]
        [hashtable]$Body,

        [parameter(Mandatory = $false)]
        [switch]$All,

        [parameter(Mandatory = $false)]
        [string]$Accept = 'application/json',

        [parameter(Mandatory = $false)]
        [switch]$NoContext,

        [parameter(Mandatory = $false)]
        [ValidateRange(1, 100000)]
        [int]$PageSize = 500
    )

    if ((Get-GlpiToolsApiVersion) -ne 'v3') {
        throw "Invoke-GlpiToolsRequest requires a configuration for the GLPI API v3."
    }

    $GlpiConfig = Get-GlpiToolsConfig -WarningAction SilentlyContinue
    $BaseUrl = Get-GlpiToolsBaseUrl -Type Api

    # sends one request; the token is read again on each attempt, so a renewed one is used
    $Send = {
        param([hashtable]$PageQuery)

        $Uri = "$BaseUrl/$($Resource.TrimStart('/'))"
        if ($PageQuery -and $PageQuery.Count -gt 0) {
            $Pairs = foreach ($Key in $PageQuery.Keys) {
                "$([System.Uri]::EscapeDataString([string]$Key))=$([System.Uri]::EscapeDataString([string]$PageQuery[$Key]))"
            }
            $Uri += '?' + ($Pairs -join '&')
        }

        $params = @{
            Method                  = $Method
            Uri                     = $Uri
            Headers                 = @{
                'Authorization'       = "Bearer $((Get-GlpiToolsSessionToken).SessionToken)"
                'Accept'              = $Accept
                'GLPI-API-Version'    = '3.0.0'
            }
            ResponseHeadersVariable = 'ResponseHeaders'
        }
        # entity and profile chosen with Set-GlpiToolsChangeActiveEntities / Set-GlpiToolsChangeActiveProfile
        $Context = if ($NoContext) { $null } else { $global:GlpiToolsContext }
        if ($null -ne $Context.EntityId) {
            $params['headers']['GLPI-Entity'] = [string]$Context.EntityId
            $params['headers']['GLPI-Entity-Recursive'] = ([string]([bool]$Context.EntityRecursive)).ToLower()
        }
        if ($null -ne $Context.ProfileId) {
            $params['headers']['GLPI-Profile'] = [string]$Context.ProfileId
        }
        if ($Body) {
            $params['Body'] = $Body | ConvertTo-Json -Depth 10 -Compress
            $params['ContentType'] = 'application/json'
        }
        if ($GlpiConfig.SkipCertificateCheck) {
            $params['SkipCertificateCheck'] = $true
        }

        $Data = Invoke-GlpiToolsRestMethod @params
        [pscustomobject]@{ Data = $Data; Headers = $ResponseHeaders }
    }

    # sends a page, renewing the token once on 401 and turning other failures into clear errors
    $SendPage = {
        param([hashtable]$PageQuery)
        try {
            try {
                & $Send $PageQuery
            } catch {
                # GLPI answers 401 for an unauthenticated call and 400 "Invalid OAuth token" for a revoked or unverifiable one
                $TokenRejected = ([int]$_.Exception.Response.StatusCode -eq 401) -or
                    ([int]$_.Exception.Response.StatusCode -eq 400 -and $_.ErrorDetails.Message -match 'Invalid OAuth token')
                if (-not $TokenRejected) { throw }
                Write-Verbose "Token rejected, renewing it and repeating the request once"
                Update-GlpiToolsAccessToken | Out-Null
                & $Send $PageQuery
            }
        } catch {
            $Caught = $_
            $Status = if ($Caught.Exception.Response) { [int]$Caught.Exception.Response.StatusCode } else { 0 }
            $ApiError = $null
            if ($Caught.ErrorDetails.Message) {
                try { $ApiError = $Caught.ErrorDetails.Message | ConvertFrom-Json } catch { $ApiError = $null }
            }
            if ($ApiError.title -or $ApiError.status) {
                $Message = "GLPI API error $Status $($ApiError.status): $($ApiError.title)"
                if ($ApiError.detail) { $Message += " - $($ApiError.detail)" }
            } elseif ($Status) {
                $Message = "GLPI API error ${Status}: $($Caught.Exception.Message)"
            } else {
                $Message = "GLPI API request failed: $($Caught.Exception.Message)"
            }
            $ErrorId = if ($Status) { "GlpiApi.$Status" } else { 'GlpiApi.RequestFailed' }
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new([System.Exception]::new($Message), $ErrorId, [System.Management.Automation.ErrorCategory]::InvalidOperation, $Resource))
        }
    }

    if (-not $All) {
        $Page = & $SendPage $Query
        # file content is returned as one byte array, not enumerated
        if ($Page.Data -is [byte[]]) {
            return , $Page.Data
        }
        return $Page.Data
    }

    # read pages until the total reported by Content-Range is reached or a short page arrives
    $Items = [System.Collections.Generic.List[object]]::new()
    $Start = if ($Query -and $Query.ContainsKey('start')) { [int]$Query['start'] } else { 0 }
    # a limit given by the caller is the page size
    if ($Query -and $Query.ContainsKey('limit')) { $PageSize = [int]$Query['limit'] }
    $FirstIdOfPreviousPage = $null
    while ($true) {
        $PageQuery = if ($Query) { $Query.Clone() } else { @{} }
        $PageQuery['start'] = $Start
        $PageQuery['limit'] = $PageSize
        $Page = & $SendPage $PageQuery

        $Received = @($Page.Data)
        if ($Received.Count -eq 1 -and $null -eq $Received[0]) { $Received = @() }
        # a server that ignores start would repeat the same page forever
        if ($Received.Count -gt 0 -and $null -ne $Received[0].id -and $Received[0].id -eq $FirstIdOfPreviousPage) { break }
        $FirstIdOfPreviousPage = if ($Received.Count -gt 0) { $Received[0].id } else { $null }
        $Items.AddRange([object[]]$Received)
        $Start += $Received.Count

        $Total = $null
        if ($Page.Headers) {
            $Range = [string]($Page.Headers['Content-Range'] | Select-Object -First 1)
            if ($Range -match '/(\d+)$') { $Total = [int]$Matches[1] }
        }

        if ($Received.Count -eq 0 -or ($null -ne $Total -and $Start -ge $Total) -or ($null -eq $Total -and $Received.Count -lt $PageSize)) {
            break
        }
    }
    $Items.ToArray()
}
