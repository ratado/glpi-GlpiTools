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
    $script:Document = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' 'doc-v3-min.json') -Raw | ConvertFrom-Json
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Filter validation against the API v3 schema' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        $Doc = $script:Document
        Mock Get-GlpiToolsV3Document { $Doc } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { @() } -ModuleName GlpiTools
    }

    Context 'Test-GlpiToolsV3Property' {
        It 'answers for plain and dotted properties' {
            InModuleScope GlpiTools {
                Test-GlpiToolsV3Property -ItemType Ticket -Name name | Should -BeTrue
                Test-GlpiToolsV3Property -ItemType Ticket -Name titulo | Should -BeFalse
                # inline properties of a related item
                Test-GlpiToolsV3Property -ItemType Ticket -Name entity.name | Should -BeTrue
                Test-GlpiToolsV3Property -ItemType Ticket -Name entity.nope | Should -BeFalse
                # a related item without inline properties is checked in its full schema
                Test-GlpiToolsV3Property -ItemType Ticket -Name category.name | Should -BeTrue
                Test-GlpiToolsV3Property -ItemType Ticket -Name category.nope | Should -BeFalse
            }
        }
        It 'does not decide when the document is unavailable' {
            Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
            InModuleScope GlpiTools {
                Set-GlpiToolsSessionToken -ResetToken
                Test-GlpiToolsV3Property -ItemType Ticket -Name titulo | Should -BeNullOrEmpty
            }
        }
        It 'reads the document once per session, also when it failed' {
            InModuleScope GlpiTools {
                Test-GlpiToolsV3Property -ItemType Ticket -Name name | Out-Null
                Test-GlpiToolsV3Property -ItemType Ticket -Name id | Out-Null
            }
            Should -Invoke Get-GlpiToolsV3Document -ModuleName GlpiTools -Exactly 1
        }
        It 'tries again after a failed read once the minute has passed, and not before' {
            Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
            Set-GlpiToolsSessionToken -ResetToken
            InModuleScope GlpiTools { Test-GlpiToolsV3Property -ItemType Ticket -Name name | Out-Null }
            InModuleScope GlpiTools { Test-GlpiToolsV3Property -ItemType Ticket -Name name | Out-Null }
            Should -Invoke Get-GlpiToolsV3Document -ModuleName GlpiTools -Exactly 1
            InModuleScope GlpiTools { $script:GlpiToolsV3DocCache.RetryAfter = [datetime]::UtcNow.AddSeconds(-1) }
            InModuleScope GlpiTools { Test-GlpiToolsV3Property -ItemType Ticket -Name name | Out-Null }
            Should -Invoke Get-GlpiToolsV3Document -ModuleName GlpiTools -Exactly 2
        }
        It 'looks the schema up once to check several fields' {
            Mock Get-GlpiToolsV3Route { '/Assistance/Ticket' } -ModuleName GlpiTools
            InModuleScope GlpiTools { Assert-GlpiToolsV3FilterField -ItemType Ticket -Field name, id, entity.name }
            Should -Invoke Get-GlpiToolsV3Route -ModuleName GlpiTools -Exactly 1
        }
        It 'reads the document again after the session is reset' {
            InModuleScope GlpiTools { Test-GlpiToolsV3Property -ItemType Ticket -Name name | Out-Null }
            Set-GlpiToolsSessionToken -ResetToken
            InModuleScope GlpiTools { Test-GlpiToolsV3Property -ItemType Ticket -Name name | Out-Null }
            Should -Invoke Get-GlpiToolsV3Document -ModuleName GlpiTools -Exactly 2
        }
    }

    Context 'Search-GlpiToolsItems' {
        It 'refuses a property the type does not have and names the valid ones' {
            $Err = $null
            try { Search-GlpiToolsItems -SearchFor Ticket -SearchType contains -SearchValue x -SearchField titulo } catch { $Err = $_ }
            $Err.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3InvalidFilterField'
            $Err.Exception.Message | Should -BeLike "*Valid properties: id, name, is_deleted, entity, category*"
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
        }
        It 'accepts a known property and a dotted one' {
            Search-GlpiToolsItems -SearchFor Ticket -SearchType contains -SearchValue x -SearchField entity.name | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'entity.name=ilike=*x*;is_deleted==0' }
        }
        It 'leaves the trash filter out for a type that has no is_deleted' {
            Search-GlpiToolsItems -SearchFor RssFeed -SearchType contains -SearchValue x -SearchField url | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'url=ilike=*x*' }
        }
        It 'searches normally when the document cannot be read' {
            Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
            Search-GlpiToolsItems -SearchFor Ticket -SearchType contains -SearchValue x -SearchField titulo | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'titulo=ilike=*x*;is_deleted==0' }
        }
    }

    Context 'Get-GlpiToolsItems' {
        It 'refuses an unknown -SearchText property' {
            $Err = $null
            try { Get-GlpiToolsItems -ItemType Ticket -SearchText @{ titulo = 'x' } } catch { $Err = $_ }
            $Err.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3InvalidFilterField'
        }
    }
}
