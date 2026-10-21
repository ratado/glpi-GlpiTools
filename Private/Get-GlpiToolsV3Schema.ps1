<#
.SYNOPSIS
    Returns the properties the API v3 knows for an item type.
.DESCRIPTION
    Finds the schema of the listing route of the item type in the OpenAPI document and returns its properties.
    The document is read once per session (it is dropped when the session or the configuration is reset), and a
    failed read is remembered too, so the server is not asked again for every search.
.PARAMETER ItemType
    Item type as used by the module, for example Ticket or Computer.
.EXAMPLE
    PS C:\> Get-GlpiToolsV3Schema -ItemType Ticket
    Returns the properties of the Ticket schema, or nothing when the schema cannot be determined.
.INPUTS
    None
.OUTPUTS
    PSCustomObject
.NOTES
    API v3 migration
#>

function Get-GlpiToolsV3Schema {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ItemType
    )

    $Site = Get-GlpiToolsBaseUrl -Type Site
    $Cache = $script:GlpiToolsV3DocCache
    if (-not $Cache -or $Cache.Site -ne $Site) {
        $Cache = @{ Site = $Site; Schemas = $null; Routes = @{ } }
        $Document = Get-GlpiToolsV3Document
        if ($Document -and $Document.components.schemas) {
            $Cache.Schemas = $Document.components.schemas
            # the listing of each route tells which schema its items follow
            foreach ($Path in $Document.paths.PSObject.Properties) {
                $Reference = $Path.Value.get.responses.'200'.content.'application/json'.schema.items.'$ref'
                if ($Reference) {
                    $Cache.Routes[$Path.Name.TrimEnd('/')] = ([string]$Reference).Split('/')[-1]
                }
            }
        }
        $script:GlpiToolsV3DocCache = $Cache
    }
    if (-not $Cache.Schemas) {
        return
    }

    $Route = Get-GlpiToolsV3Route -ItemType $ItemType
    $SchemaName = $Cache.Routes[$Route.TrimEnd('/')]
    if ($SchemaName) {
        [pscustomobject]@{ Name = $SchemaName; Properties = $Cache.Schemas.$SchemaName.properties; Schemas = $Cache.Schemas }
    }
}
