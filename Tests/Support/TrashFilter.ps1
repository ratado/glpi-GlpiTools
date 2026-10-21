<#
.SYNOPSIS
    Returns the trash filter that the listing of a route must send.
.DESCRIPTION
    A type whose field map has no is_deleted property (dropdowns, entities, groups...) is listed with no filter;
    any other type is listed with is_deleted==0.
#>
function script:Get-ExpectedTrashFilter {
    param([string]$Route)
    $Root = Join-Path $PSScriptRoot '..' '..' 'Private'
    $Routes = Get-Content -Path (Join-Path $Root 'V3Routes.json') -Raw | ConvertFrom-Json
    $Maps = Get-Content -Path (Join-Path $Root 'V3FieldMap.json') -Raw | ConvertFrom-Json
    foreach ($Alias in ($Routes.PSObject.Properties | Where-Object { $_.Value.TrimEnd('/') -eq $Route.TrimEnd('/') })) {
        $Map = $Maps.PSObject.Properties[$Alias.Name]
        if ($Map) {
            if ($Map.Value | Where-Object { $_.v3 -eq 'is_deleted' }) { return 'is_deleted==0' }
            return $null
        }
    }
    'is_deleted==0'
}
