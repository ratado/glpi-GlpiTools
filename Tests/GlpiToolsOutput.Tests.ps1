BeforeAll {
    # the script module is imported directly so that private functions are reachable
    Import-Module (Join-Path $PSScriptRoot '..' 'GlpiTools.psm1') -Force
    # the API v3 document is not downloaded by the tests; the filter fields are then not validated
    Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
    $script:Fixtures = Join-Path $PSScriptRoot 'Fixtures'
    $script:V3Ticket = Get-Content -Path (Join-Path $script:Fixtures 'Ticket2-v3.json') -Raw | ConvertFrom-Json -DateKind String
    $script:V1Raw = Get-Content -Path (Join-Path $script:Fixtures 'Ticket2-v1-Raw.json') -Raw | ConvertFrom-Json
    $script:V1Named = Get-Content -Path (Join-Path $script:Fixtures 'Ticket2-v1.json') -Raw | ConvertFrom-Json
}

Describe 'ConvertFrom-GlpiToolsV3Item for Ticket' {
    Context 'with -Raw' {
        BeforeAll {
            $script:Converted = $script:V3Ticket | ConvertFrom-GlpiToolsV3Item -ItemType Ticket -Raw
        }

        It 'returns the same properties as the legacy API, in the same order' {
            $Expected = $script:V1Raw.PSObject.Properties.Name | Where-Object { $_ -notin 'time_to_own', 'tickettemplates_id' }
            $Actual = $script:Converted.PSObject.Properties.Name | Where-Object { $_ -ne 'team' }
            $Actual | Should -Be $Expected
        }

        It 'returns the same values as the legacy API' {
            foreach ($Name in $script:Converted.PSObject.Properties.Name | Where-Object { $_ -ne 'team' }) {
                $Converted = $script:Converted.$Name
                $Expected = $script:V1Raw.$Name
                "${Name}: $Converted" | Should -Be "${Name}: $Expected"
            }
        }

        It 'formats dates as the legacy API does' {
            $script:Converted.solvedate | Should -Be '2026-10-05 19:41:06'
        }

        It 'returns booleans as integers' {
            $script:Converted.is_deleted | Should -BeOfType [int]
            $script:Converted.is_deleted | Should -Be 0
        }

        It 'appends the team' {
            $script:Converted.team | Should -Not -BeNullOrEmpty
        }
    }

    Context 'without -Raw' {
        BeforeAll {
            $script:Converted = $script:V3Ticket | ConvertFrom-GlpiToolsV3Item -ItemType Ticket
        }

        It 'shows the complete name of the entity' {
            $script:Converted.entities_id | Should -Be $script:V1Named.entities_id
        }

        It 'keeps the relations that the legacy API does not convert as IDs' {
            $script:Converted.status | Should -Be $script:V1Named.status
            $script:Converted.itilcategories_id | Should -Be $script:V1Named.itilcategories_id
            $script:Converted.requesttypes_id | Should -Be $script:V1Named.requesttypes_id
        }

        It 'shows the user name instead of the empty text of the legacy conversion' {
            $script:Converted.users_id_recipient | Should -Be 'glpi'
        }

        It 'leaves an empty location empty' {
            $script:Converted.locations_id | Should -BeNullOrEmpty
        }
    }

    It 'keeps the properties added by the cmdlets' {
        $Item = $script:V3Ticket.PSObject.Copy()
        $Item | Add-Member -NotePropertyName '_documents' -NotePropertyValue @(1)
        ($Item | ConvertFrom-GlpiToolsV3Item -ItemType Ticket -Raw)._documents | Should -Be 1
    }

    It 'fails for an item type without map' {
        { $script:V3Ticket | ConvertFrom-GlpiToolsV3Item -ItemType Unknown } | Should -Throw
    }
}

Describe 'ConvertFrom-GlpiToolsV3Item for the other item types' {
    # properties of the legacy API that the v3 does not provide are not expected
    It 'keeps order and values of the legacy API for <Type> <Id>' -ForEach @(
        @{ Type = 'Computer'; Id = 5 }
        @{ Type = 'User'; Id = 2 }
        @{ Type = 'Entity'; Id = 1 }
        @{ Type = 'Group'; Id = 1 }
        @{ Type = 'Location'; Id = 4 }
        @{ Type = 'Software'; Id = 1 }
    ) {
        $V3 = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' "$Type$Id-v3.json") -Raw | ConvertFrom-Json -DateKind String
        $V1 = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' "$Type$Id-v1-Raw.json") -Raw | ConvertFrom-Json -DateKind String
        $Converted = $V3 | ConvertFrom-GlpiToolsV3Item -ItemType $Type -Raw
        $Names = @($Converted.PSObject.Properties.Name)
        # every converted property exists in the legacy object, in the same relative order
        $Names | Where-Object { $_ -notin $V1.PSObject.Properties.Name } | Should -BeNullOrEmpty
        $Names | Should -Be @($V1.PSObject.Properties.Name | Where-Object { $_ -in $Names })
        foreach ($Name in $Names) {
            "${Name}: $(@($Converted.$Name) -join ',')" | Should -Be "${Name}: $(@($V1.$Name) -join ',')"
        }
    }

    It 'shows the names of the related items without -Raw' {
        $V3 = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' 'User2-v3.json') -Raw | ConvertFrom-Json -DateKind String
        $Converted = $V3 | ConvertFrom-GlpiToolsV3Item -ItemType User
        $Converted.profiles_id | Should -Be 'Super-Admin'
        $Converted.entities_id | Should -Be 'Entidade raiz'
    }
}

Describe 'ConvertFrom-GlpiToolsV3Item decimals' {
    It 'keeps an empty decimal empty' {
        $V3 = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' 'Computer5-v3.json') -Raw | ConvertFrom-Json -DateKind String
        $V3.ticket_tco = $null
        ($V3 | ConvertFrom-GlpiToolsV3Item -ItemType Computer -Raw).ticket_tco | Should -BeNullOrEmpty
    }
}

Describe 'ConvertFrom-GlpiToolsV3Item for changes and problems' {
    It 'keeps order and values of the legacy API for <Type> <Id>' -ForEach @(
        @{ Type = 'Change'; Id = 1 }
        @{ Type = 'Problem'; Id = 1 }
    ) {
        $V3 = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' "$Type$Id-v3.json") -Raw | ConvertFrom-Json -DateKind String
        $V1 = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' "$Type$Id-v1-Raw.json") -Raw | ConvertFrom-Json -DateKind String
        $Converted = $V3 | ConvertFrom-GlpiToolsV3Item -ItemType $Type -Raw
        $Names = @($Converted.PSObject.Properties.Name | Where-Object { $_ -ne 'team' })
        $Names | Where-Object { $_ -notin $V1.PSObject.Properties.Name } | Should -BeNullOrEmpty
        $Names | Should -Be @($V1.PSObject.Properties.Name | Where-Object { $_ -in $Names })
        foreach ($Name in $Names) {
            "${Name}: $(@($Converted.$Name) -join ',')" | Should -Be "${Name}: $(@($V1.$Name) -join ',')"
        }
    }
}
