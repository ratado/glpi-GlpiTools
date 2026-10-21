<#
.SYNOPSIS
    Reads the records of an API v3 route once per call of the calling command.
.DESCRIPTION
    A command that receives ids from the pipeline runs its process block once per id, so a list that does not
    depend on the id would be requested again each time. The list is kept in a variable of the scope of the
    calling command, which lasts for the whole pipeline of that call.
.PARAMETER Resource
    Route to read.
.PARAMETER All
    Reads every page of a listing; without it the route is read once, as a single record.
.PARAMETER NotFoundIsEmpty
    Treats a 404 answer as an empty result, for records that may not exist.
.EXAMPLE
    PS C:\> $V3Items = Get-GlpiToolsV3CachedList -Resource "/Assets/Computer/$ComputerId/SoftwareInstallation" -All
    Returns the installations of the computer, reading them on the first call only.
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    API v3 migration
#>

function Get-GlpiToolsV3CachedList {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$Resource,

        [parameter(Mandatory = $false)]
        [switch]$All,

        [parameter(Mandatory = $false)]
        [switch]$NotFoundIsEmpty
    )

    # scope 1 is the command that called this function; the list is reused only for the same route
    $Cached = Get-Variable -Name GlpiToolsV3ListCache -Scope 1 -ErrorAction SilentlyContinue
    if ($Cached -and $Cached.Value.Resource -eq $Resource) {
        return , @($Cached.Value.List)
    }

    $List = @()
    try {
        $List = @(Invoke-GlpiToolsRequest -Method Get -Resource $Resource -All:$All | Where-Object { $_ })
    } catch {
        # a missing record is an empty result only when the caller expects it
        if (-not $NotFoundIsEmpty -or $_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
    }
    Set-Variable -Name GlpiToolsV3ListCache -Value @{ Resource = $Resource; List = $List } -Scope 1
    , $List
}
