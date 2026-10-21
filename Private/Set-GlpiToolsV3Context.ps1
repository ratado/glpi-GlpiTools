<#
.SYNOPSIS
    Keeps the active entity and profile used by the API v3 requests.
.DESCRIPTION
    The API v3 has no server side session state: the entity and the profile are sent in the
    GLPI-Entity, GLPI-Entity-Recursive and GLPI-Profile headers of each request. This function stores
    the choice made by Set-GlpiToolsChangeActiveEntities and Set-GlpiToolsChangeActiveProfile for
    Invoke-GlpiToolsRequest. The context is discarded together with the session token.
.PARAMETER EntityId
    Entity to be used by the following requests.
.PARAMETER EntityRecursive
    Whether the child entities of EntityId are included.
.PARAMETER ProfileId
    Profile to be used by the following requests.
.EXAMPLE
    PS C:\> Set-GlpiToolsV3Context -EntityId 1 -EntityRecursive $true
    Following requests are made in the entity 1 and its children.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    API v3 migration
#>

function Set-GlpiToolsV3Context {
    # only in-memory module state changes, there is nothing to confirm
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false)]
        [int]$EntityId,

        [parameter(Mandatory = $false)]
        [bool]$EntityRecursive,

        [parameter(Mandatory = $false)]
        [int]$ProfileId,

        [parameter(Mandatory = $false)]
        [switch]$ResetEntity
    )

    $Context = [ordered]@{}
    foreach ($Property in $global:GlpiToolsContext.PSObject.Properties) {
        $Context[$Property.Name] = $Property.Value
    }
    if ($PSBoundParameters.ContainsKey('EntityId')) { $Context['EntityId'] = $EntityId; $Context['EntityRecursive'] = [bool]$EntityRecursive }
    if ($PSBoundParameters.ContainsKey('ProfileId')) { $Context['ProfileId'] = $ProfileId }
    # a profile change goes back to the default entities of the new profile, as the legacy API does
    if ($ResetEntity) { $Context.Remove('EntityId'); $Context.Remove('EntityRecursive') }
    $global:GlpiToolsContext = [pscustomobject]$Context
}
