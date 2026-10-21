BeforeAll {
    # keep the real config untouched by redirecting the home directory
    $script:OriginalHome = $env:HOME
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $script:SavedSession = $global:GlpiToolsSessionToken
    $script:SavedContext = $global:GlpiToolsContext
    $script:TempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("glpitools-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:TempHome | Out-Null
    $env:HOME = $script:TempHome
    $env:LOCALAPPDATA = $script:TempHome
    # the script module is imported directly so that private functions are reachable and mockable
    Import-Module (Join-Path $PSScriptRoot '..' 'GlpiTools.psm1') -Force
    # the API v3 document is not downloaded by the tests; the filter fields are then not validated
    Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    $global:GlpiToolsContext = $script:SavedContext
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Generic item cmdlets on API v3' {
    BeforeEach {
        $global:GlpiToolsContext = $null
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        # a valid session avoids the token request made by the begin blocks
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 1; name = 'x' } } -ModuleName GlpiTools
    }

    Context 'Get-GlpiToolsItems' {
        It 'lists the route of the item type outside the trash, reading all pages' {
            Get-GlpiToolsItems -ItemType Ticket | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
                $Method -eq 'Get' -and $Resource -eq '/Assistance/Ticket' -and $All -and $Query.filter -eq 'is_deleted==0'
            }
        }
        It 'filters the trash' {
            Get-GlpiToolsItems -ItemType Ticket -SearchInTrash $true | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'is_deleted==1' }
        }
        It 'turns SearchText into contains criteria' {
            Get-GlpiToolsItems -ItemType Computer -SearchText @{ name = 'DC' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'name=ilike=*DC*;is_deleted==0' }
        }
        It 'returns only the id with -OnlyId' {
            $r = Get-GlpiToolsItems -ItemType Computer -OnlyId $true
            $r.PSObject.Properties.Name | Should -Be @('id')
        }
        It 'maps regular expression anchors of -SearchText' -ForEach @(
            @{ Text = '^234$'; Expected = 'id==234;is_deleted==0' }
            @{ Text = '^PC'; Expected = 'id=ilike=PC*;is_deleted==0' }
            @{ Text = 'PC$'; Expected = 'id=ilike=*PC;is_deleted==0' }
        ) {
            Get-GlpiToolsItems -ItemType Ticket -SearchText @{ id = $Text } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq $Expected }
        }
        It 'rejects -ExtraParameter and unknown item types' {
            { Get-GlpiToolsItems -ItemType Ticket -ExtraParameter '&with_logs=true' } | Should -Throw '*-ExtraParameter is not supported*'
            { Get-GlpiToolsItems -ItemType DeviceMemoryModel } | Should -Throw '*not supported by the GLPI API v3*'
        }
    }

    Context 'Add-GlpiToolsItems' {
        It 'posts a hashtable' {
            Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ name = 'a' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Post' -and $Resource -eq '/Assistance/Ticket' -and $Body.name -eq 'a' }
        }
        It 'posts each element of a legacy JSON payload' {
            Add-GlpiToolsItems -AddTo Computer -JsonPayload '{"input":[{"name":"a"},{"name":"b"}]}' | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 2 -ParameterFilter { $Method -eq 'Post' -and $Resource -eq '/Assets/Computer' }
        }
    }

    Context 'Update-GlpiToolsItems' {
        It 'patches the item' {
            Update-GlpiToolsItems -UpdateTo Ticket -ItemId 5 -ItemsHashtableWithoutId @{ name = 'n' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Patch' -and $Resource -eq '/Assistance/Ticket/5' -and $Body.name -eq 'n' -and -not $Body.ContainsKey('id') }
        }
        It 'patches each element of a legacy JSON payload by its id' {
            Update-GlpiToolsItems -UpdateTo Computer -JsonPayload '{"input":[{"id":3,"name":"a"},{"id":4,"name":"b"}]}' | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Computer/3' -and -not $Body.ContainsKey('id') }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Computer/4' }
        }
    }

    Context 'Remove-GlpiToolsItems' {
        It 'refuses payload elements without an id' {
            { Remove-GlpiToolsItems -RemoveFrom Computer -HashtableToRemove @{ input = @(@{ name = 'x' }) } } | Should -Throw '*integer id*'
            { Update-GlpiToolsItems -UpdateTo Computer -JsonPayload '{"input":[{"name":"a"}]}' } | Should -Throw '*integer id*'
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
        }
        It 'sends items to the trash by default' {
            Remove-GlpiToolsItems -RemoveFrom Ticket -ItemId 5 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Delete' -and $Resource -eq '/Assistance/Ticket/5' -and -not $Query }
        }
        It 'purges with -Purge' {
            Remove-GlpiToolsItems -RemoveFrom Ticket -ItemId 5 -Purge | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.force -eq 'true' }
        }
        It 'deletes each id of a legacy payload' {
            Remove-GlpiToolsItems -RemoveFrom Computer -HashtableToRemove @{ input = @(@{ id = 1 }, @{ id = 2 }) } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 2 -ParameterFilter { $Method -eq 'Delete' -and $Resource -match '^/Assets/Computer/[12]$' }
        }
    }

    Context 'Search-GlpiToolsItems' {
        It 'translates the search to RSQL, with the name as default field' {
            Search-GlpiToolsItems -SearchFor Computer -SearchType contains -SearchValue DC | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Computer' -and $Query.filter -eq 'name=ilike=*DC*;is_deleted==0' }
        }
        It 'joins several criteria and negates with +NOT' {
            Search-GlpiToolsItems -SearchFor Computer -SearchType contains, contains -SearchField 1, 1 -SearchValue a, b -SearchLink OR+NOT | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq '(name=ilike=*a*,name=notilike=*b*);is_deleted==0' }
        }
        It 'rejects numeric search options it cannot translate' {
            { Search-GlpiToolsItems -SearchFor Computer -SearchType contains -SearchField 40 -SearchValue a } | Should -Throw '*cannot be translated*'
        }
        It 'searches the trash on request' {
            Search-GlpiToolsItems -SearchFor Computer -SearchType equals -SearchValue a -SearchInTrash Yes | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'name==a;is_deleted==1' }
        }
    }
}

Describe 'Session, entity and profile cmdlets on API v3' {
    BeforeEach {
        $global:GlpiToolsContext = $null
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        $session = '{"default_entity":0,"profiles":{"1":{"name":"Self","entities":[{"id":0,"name":"Root","is_recursive":0}]},"4":{"name":"Admin","entities":[{"id":0,"name":"Root","is_recursive":1}]}},"active_entities":{"0":0,"1":1},"active_profile":{"id":4,"name":"Admin"}}' | ConvertFrom-Json
        $tree = '[{"key":0,"label":"Root","children":[{"key":1,"label":"A","children":[]}]}]' | ConvertFrom-Json
        Mock Invoke-GlpiToolsRequest { $session } -ModuleName GlpiTools -ParameterFilter { $Resource -eq '/session' }
        Mock Invoke-GlpiToolsRequest { $tree } -ModuleName GlpiTools -ParameterFilter { $Resource -eq '/Session/EntityTree' }
    }

    It 'reads the active profile from the session' {
        (Get-GlpiToolsActiveProfile).name | Should -Be 'Admin'
    }
    It 'lists my profiles in the legacy shape' {
        $p = Get-GlpiToolsMyProfiles
        @($p).Count | Should -Be 2
        $p[1].id | Should -Be 4
        $p[1].entities[0].is_recursive | Should -Be 1
    }
    It 'lists my entities, directly assigned or the whole tree' {
        @(Get-GlpiToolsMyEntities).id | Should -Be @(0)
        @(Get-GlpiToolsMyEntities -IsRecursive).id | Should -Be @(0, 1)
    }
    It 'reports the active entities' {
        $e = Get-GlpiToolsActiveEntities
        $e.id | Should -Be 0
        $e.selected_entities | Should -Be @(0, 1)
    }
    It 'changes the active entity and sends it in the following requests' {
        Set-GlpiToolsChangeActiveEntities -EntitiesId 1 -IsRecursive | Should -BeTrue
        (Get-GlpiToolsActiveEntities).id | Should -Be 1
    }
    It 'rejects an entity or profile that is not available' {
        { Set-GlpiToolsChangeActiveEntities -EntitiesId 99 } | Should -Throw '*not available*'
        { Set-GlpiToolsChangeActiveProfile -ProfilesId 99 } | Should -Throw '*not available*'
    }
    It 'changes the active profile' {
        Set-GlpiToolsChangeActiveProfile -ProfilesId 1 | Should -BeTrue
        $global:GlpiToolsContext.ProfileId | Should -Be 1
    }
    It 'drops the context when the session is discarded' {
        Set-GlpiToolsChangeActiveProfile -ProfilesId 1 | Out-Null
        Set-GlpiToolsKillSession
        $global:GlpiToolsContext | Should -BeNullOrEmpty
    }
    It 'fails clearly for cmdlets without a v3 equivalent' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsListSearchOptions -ListOptionsFor Computer' }
        @{ Cmd = 'Get-GlpiToolsItemLogs -LogsFor Computer -ItemId 1' }
        @{ Cmd = 'Set-GlpiToolsResetPasswordRequest -Email a@b.c' }
    ) {
        { Invoke-Expression $Cmd } | Should -Throw '*is not supported by the GLPI API v3*'
    }
}

Describe 'Context headers in requests' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRestMethod { Set-Variable -Name $ResponseHeadersVariable -Value @{} -Scope 2; 'ok' } -ModuleName GlpiTools
    }
    It 'sends entity and profile headers once chosen' {
        Set-GlpiToolsV3Context -EntityId 3 -EntityRecursive $true
        Set-GlpiToolsV3Context -ProfileId 6
        Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket' | Out-Null
        Should -Invoke Invoke-GlpiToolsRestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Headers['GLPI-Entity'] -eq '3' -and $Headers['GLPI-Entity-Recursive'] -eq 'true' -and $Headers['GLPI-Profile'] -eq '6'
        }
    }
    It 'sends no context headers by default' {
        $global:GlpiToolsContext = $null
        Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket' | Out-Null
        Should -Invoke Invoke-GlpiToolsRestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { -not $Headers.ContainsKey('GLPI-Entity') -and -not $Headers.ContainsKey('GLPI-Profile') }
    }
}

Describe 'Legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 1; name = 'x' } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'Get-GlpiToolsItems still calls apirest.php' {
        Get-GlpiToolsItems -ItemType Ticket -Raw $true | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Uri -eq 'http://glpi/apirest.php/Ticket/?range=0-9999999999999' -and $Headers['App-Token'] -eq 'app1' -and $Headers['Session-Token'] -eq 'S1'
        }
    }
    It 'Add, Update and Remove still use the legacy verbs and URLs' {
        Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ name = 'a' } | Out-Null
        Update-GlpiToolsItems -UpdateTo Ticket -ItemId 5 -ItemsHashtableWithoutId @{ name = 'n' } | Out-Null
        Remove-GlpiToolsItems -RemoveFrom Ticket -ItemId 5 -Purge | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'post' -and $Uri -eq 'http://glpi/apirest.php/Ticket/' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'put' -and $Uri -eq 'http://glpi/apirest.php/Ticket/5' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'delete' -and $Uri -eq 'http://glpi/apirest.php/Ticket/5?force_purge=true' }
    }
    It 'entity and profile cmdlets still call the legacy endpoints' {
        Get-GlpiToolsActiveProfile | Out-Null
        Get-GlpiToolsMyEntities | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'http://glpi/apirest.php/getActiveProfile/' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'http://glpi/apirest.php/getMyEntities/' }
    }
    It 'Get-GlpiToolsListSearchOptions is not blocked' {
        { Get-GlpiToolsListSearchOptions -ListOptionsFor Computer } | Should -Not -Throw '*API v3*'
    }
}

Describe 'Get-GlpiToolsProfiles on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 4; name = 'p' } } -ModuleName GlpiTools
    }
    It 'gets the profiles whose ids come from the pipeline' {
        2, 3 | Get-GlpiToolsProfiles | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Administration/Profile/2' }
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Administration/Profile/3' }
    }
    It 'gets the profiles given by -ProfileId' {
        Get-GlpiToolsProfiles -ProfileId 5 | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Administration/Profile/5' }
    }
}
