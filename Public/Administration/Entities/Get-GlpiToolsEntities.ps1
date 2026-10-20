<#
.SYNOPSIS
    Function returns entities from GLPI
.DESCRIPTION
    Function returns all possible enitites, you can provide id or name to get informations about desired entity
.PARAMETER All
    This parameter will return all Entities from GLPI
.PARAMETER EntityId
    This parameter can take pipline input, either, you can use this function with -ComputerId keyword.
    Provide to this param Entity ID from GLPI Entities Bookmark
.PARAMETER EntityName
    This parameter can take pipline input, either, you can use this function with -ComputerName keyword.
    Provide to this param entity Name from GLPI Entities Bookmark
.EXAMPLE
    PS C:\> Get-GlpiToolsEntities -All
    Command will return all entities from GLPI
.EXAMPLE
    PS C:\> Get-GlpiToolsEntities -EntityId 3
    Command will return entity with Id number 3 from GLPI
.EXAMPLE
    PS C:\> 3 | Get-GlpiToolsEntities
    Command will return entity with Id number 3 from GLPI
.EXAMPLE
    PS C:\> Get-GlpiToolsEntities -EntityName Old
    Command will return entity with Name Old from GLPI
.INPUTS
    Entity ID which you can find in GLPI, or use this Function to convert ID returned from other Functions
.OUTPUTS
    Function returns PSCustomObject with property's of entity from GLPI
.NOTES
    PSP 01/2019
#>

function Get-GlpiToolsEntities {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $false,
            ParameterSetName = "All")]
        [switch]$All,
        [parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = "EntityId")]
        [alias('EID')]
        [string[]]$EntityId,
        [parameter(Mandatory = $false,
            ParameterSetName = "EntityId")]
        [switch]$Raw,
        [parameter(Mandatory = $true,
            ParameterSetName = "EntityName")]
        [alias('EN')]
        [string]$EntityName
    )
    
    begin {
        $SessionToken = $Script:SessionToken
        $AppToken = $Script:AppToken
        $PathToGlpi = $Script:PathToGlpi

        $SessionToken = Get-GlpiToolsSessionToken | Select-Object -ExpandProperty SessionToken
        $AppToken = Get-GlpiToolsConfig | Select-Object -ExpandProperty AppToken
        $PathToGlpi = Get-GlpiToolsConfig | Select-Object -ExpandProperty PathToGlpi

        $ChoosenParam = ($PSCmdlet.MyInvocation.BoundParameters).Keys

        $EntitiesArray = [System.Collections.Generic.List[PSObject]]::New()
    }
    
    process {
        # API v3: handled through the shared request layer, the legacy code below is not reached
        if ((Get-GlpiToolsApiVersion) -eq 'v3') {
            # the parameter set is used because pipeline input is not bound yet in the begin block
            switch ($PSCmdlet.ParameterSetName) {
                All {
                    Invoke-GlpiToolsRequest -Method Get -Resource '/Administration/Entity' -Query @{ filter = (ConvertTo-GlpiToolsRsql -Required @{ Field = 'is_deleted'; Value = 0 }) } -All | ConvertFrom-GlpiToolsV3Item -ItemType Entity -Raw
                }
                EntityId {
                    foreach ($V3ItemId in $EntityId) {
                        $V3Item = $null
                        try {
                            $V3Item = Invoke-GlpiToolsRequest -Method Get -Resource "/Administration/Entity/$V3ItemId"
                        } catch {
                            # only a missing item is skipped; other failures are reported
                            if ($_.FullyQualifiedErrorId -notlike 'GlpiApi.404*') { throw }
                            Write-Verbose -Message "Entity ID = $V3ItemId is not found"
                        }
                        if ($V3Item) {
                            # the legacy properties are returned, converted to names unless -Raw is used
                            $V3Item | ConvertFrom-GlpiToolsV3Item -ItemType Entity -Raw:$Raw
                        }
                    }
                }
                EntityName {
                    Search-GlpiToolsItems -SearchFor Entity -SearchType contains -SearchValue $EntityName | ConvertFrom-GlpiToolsV3Item -ItemType Entity -Raw
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
                    uri     = "$($PathToGlpi)/Entity/?range=0-9999999999999"
                }
                
                $GlpiEntitiesAll = Invoke-GlpiToolsRequestApi -Params $params -Verbose:$false

                foreach ($GlpiEntity in $GlpiEntitiesAll) {
                    $EntityHash = [ordered]@{ }
                            $EntityProperties = $GlpiEntity.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($EntityProp in $EntityProperties) {
                                $EntityHash.Add($EntityProp.Name, $EntityProp.Value)
                            }
                            $object = [pscustomobject]$EntityHash
                            $EntitiesArray.Add($object)
                }
                $EntitiesArray
                $EntitiesArray = [System.Collections.Generic.List[PSObject]]::New()
            }
            EntityId {
                foreach ( $EId in $EntityId ) {
                    $params = @{
                        headers = @{
                            'Content-Type'  = 'application/json'
                            'App-Token'     = $AppToken
                            'Session-Token' = $SessionToken
                        }
                        method  = 'get'
                        uri     = "$($PathToGlpi)/Entity/$($EId)"
                    }

                    Try {
                        $GlpiEntity = Invoke-GlpiToolsRequestApi -Params $params -ErrorAction Stop

                        if ($Raw) {
                            $EntityHash = [ordered]@{ }
                            $EntityProperties = $GlpiEntity.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($EntityProp in $EntityProperties) {
                                $EntityHash.Add($EntityProp.Name, $EntityProp.Value)
                            }
                            $object = [pscustomobject]$EntityHash
                            $EntitiesArray.Add($object)
                        } else {
                            $EntityHash = [ordered]@{ }
                            $EntityProperties = $GlpiEntity.PSObject.Properties | Select-Object -Property Name, Value 
                                
                            foreach ($EntityProp in $EntityProperties) {

                                $EntityPropNewValue = Get-GlpiToolsParameters -Parameter $EntityProp.Name -Value $EntityProp.Value

                                $EntityHash.Add($EntityProp.Name, $EntityPropNewValue)
                            }
                            $object = [pscustomobject]$EntityHash
                            $EntitiesArray.Add($object)
                        }
                    } Catch {

                        Write-Verbose -Message "Entity ID = $EId is not found"
                        
                    }
                    $EntitiesArray
                    $EntitiesArray = [System.Collections.Generic.List[PSObject]]::New()
                }
            }
            EntityName {
                Search-GlpiToolsItems -SearchFor Entity -SearchType contains -SearchValue $EntityName
            }
            Default {}
        }
    }
    
    end {
        
    }
}