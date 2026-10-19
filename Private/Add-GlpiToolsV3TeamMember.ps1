<#
.SYNOPSIS
    Adds a user to the team of a ticket, change or problem in the API v3.
.DESCRIPTION
    Posts the user as requester, assigned or observer. When the user already has that role in the
    item, nothing is sent, so repeating the call does not create duplicates.
.PARAMETER Resource
    Route of the item, for example /Assistance/Ticket/7.
.PARAMETER Role
    requester, assigned or observer.
.PARAMETER UserId
    GLPI user id.
.EXAMPLE
    PS C:\> Add-GlpiToolsV3TeamMember -Resource /Assistance/Ticket/7 -Role requester -UserId 4
    Makes the user 4 a requester of the ticket 7.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Add-GlpiToolsV3TeamMember {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$Resource,

        [parameter(Mandatory = $true)]
        [ValidateSet('requester', 'assigned', 'observer')]
        [string]$Role,

        [parameter(Mandatory = $true)]
        [int]$UserId
    )

    $Members = Invoke-GlpiToolsRequest -Method Get -Resource "$Resource/TeamMember"
    if (@($Members | Where-Object { $_.role -eq $Role -and $_.type -eq 'User' -and $_.id -eq $UserId }).Count -gt 0) {
        Write-Verbose "User $UserId is already $Role in $Resource"
        return
    }
    Invoke-GlpiToolsRequest -Method Post -Resource "$Resource/TeamMember" -Body @{ type = 'User'; id = $UserId; role = $Role } | Out-Null
}
