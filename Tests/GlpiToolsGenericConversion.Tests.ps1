BeforeAll {
    # keep the real config untouched by redirecting the home directory
    $script:OriginalHome = $env:HOME
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $script:SavedSession = $global:GlpiToolsSessionToken
    $script:TempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("glpitools-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:TempHome | Out-Null
    $env:HOME = $script:TempHome
    $env:LOCALAPPDATA = $script:TempHome
    # the script module is imported directly so that private functions are reachable and mockable
    Import-Module (Join-Path $PSScriptRoot '..' 'GlpiTools.psm1') -Force
    Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Generic commands with legacy field names on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { } -ModuleName GlpiTools
    }

    Context 'ConvertTo-GlpiToolsV3Input' {
        It 'turns a related item column into an object and keeps the other fields' {
            $r = InModuleScope GlpiTools { ConvertTo-GlpiToolsV3Input -ItemType Ticket -InputObject @{ name = 'a'; entities_id = 1; closedate = '2026-01-01 10:00:00' } }
            $r.name | Should -Be 'a'
            $r.entity.id | Should -Be 1
            $r.date_close | Should -Be '2026-01-01 10:00:00'
            $r.Keys | Should -Not -Contain 'entities_id'
        }
        It 'does not touch keys that are already v3 names or are unknown' {
            $r = InModuleScope GlpiTools { ConvertTo-GlpiToolsV3Input -ItemType Ticket -InputObject @{ entity = @{ id = 3 }; custom_field = 'x' } }
            $r.entity.id | Should -Be 3
            $r.custom_field | Should -Be 'x'
        }
        It 'converts booleans written as 0 and 1' {
            $r = InModuleScope GlpiTools { ConvertTo-GlpiToolsV3Input -ItemType Computer -InputObject @{ is_deleted = 1 } }
            $r.is_deleted | Should -BeTrue
        }
        It 'returns the payload unchanged for a type without a map' {
            $r = InModuleScope GlpiTools { ConvertTo-GlpiToolsV3Input -ItemType NoSuchType -InputObject @{ entities_id = 1 } }
            $r.entities_id | Should -Be 1
        }
    }

    Context 'Add-GlpiToolsItems and Update-GlpiToolsItems' {
        It 'sends the converted body when adding from a hashtable' {
            Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ name = 'n'; entities_id = 2 } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Post' -and $Body.entity.id -eq 2 -and $Body.name -eq 'n' -and -not $Body.ContainsKey('entities_id') }
        }
        It 'sends the converted body when adding from a JSON payload' {
            Add-GlpiToolsItems -AddTo Ticket -JsonPayload '{"input":{"name":"n","entities_id":2}}' | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Body.entity.id -eq 2 }
        }
        It 'sends the converted body when updating' {
            Update-GlpiToolsItems -UpdateTo Ticket -ItemId 5 -ItemsHashtableWithoutId @{ locations_id = 4 } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Patch' -and $Resource -like '*/5' -and $Body.location.id -eq 4 }
        }
        It 'sends the converted body when updating from a JSON payload' {
            Update-GlpiToolsItems -UpdateTo Ticket -JsonPayload '{"input":{"id":6,"locations_id":4}}' | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -like '*/6' -and $Body.location.id -eq 4 -and -not $Body.ContainsKey('id') }
        }
    }

    Context 'Get-GlpiToolsItems' {
        BeforeEach {
            Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 7; name = 'n'; entity = [pscustomobject]@{ id = 1; name = 'Root'; completename = 'Root' } } } -ModuleName GlpiTools
        }
        It 'returns the legacy names with the related item as a name' {
            $r = Get-GlpiToolsItems -ItemType Ticket
            $r.entities_id | Should -Be 'Root'
            $r.PSObject.Properties.Name | Should -Not -Contain 'entity'
        }
        It 'returns the id of the related item with -Raw' {
            (Get-GlpiToolsItems -ItemType Ticket -Raw $true).entities_id | Should -Be 1
        }
        It 'returns raw when there is more than one result' {
            Mock Invoke-GlpiToolsRequest { @([pscustomobject]@{ id = 7; entity = [pscustomobject]@{ id = 1; name = 'Root' } }, [pscustomobject]@{ id = 8; entity = [pscustomobject]@{ id = 2; name = 'B' } }) } -ModuleName GlpiTools
            $r = Get-GlpiToolsItems -ItemType Ticket -WarningAction SilentlyContinue
            $r.entities_id | Should -Be 1, 2
        }
        It 'keeps the v3 format for a type without a map' {
            Mock Get-GlpiToolsV3Route { '/Foo/Bar' } -ModuleName GlpiTools
            (Get-GlpiToolsItems -ItemType NoSuchType).entity.name | Should -Be 'Root'
        }
        It 'returns only the id with -OnlyId' {
            (Get-GlpiToolsItems -ItemType Ticket -OnlyId $true).PSObject.Properties.Name | Should -Be 'id'
        }
        It 'translates a legacy column used in -SearchText' {
            Get-GlpiToolsItems -ItemType Ticket -SearchText @{ entities_id = '^1$' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -like 'entity.id==1;*' }
        }
    }
}

Describe 'Field maps' {
    It 'have no legacy name equal to the v3 name of another field' {
        # the input converters treat a key that is a v3 name as already converted, so such a collision would hide a legacy column
        $Maps = Get-Content -Path (Join-Path $PSScriptRoot '..' 'Private' 'V3FieldMap.json') -Raw | ConvertFrom-Json
        $Collisions = foreach ($Type in $Maps.PSObject.Properties) {
            foreach ($Field in $Type.Value) {
                $Other = $Type.Value | Where-Object { $_.v3 -eq $Field.v1 -and $_ -ne $Field }
                if ($Other) { "$($Type.Name): $($Field.v1)" }
            }
        }
        $Collisions | Should -BeNullOrEmpty
    }
}
