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
    # the API v3 document is not downloaded by the tests; the filter fields are then not validated
    Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
    # runs a cmdlet with the parameters given as a hashtable
    function script:Invoke-WithParams { param($Name, $Params) & $Name @Params }
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Tools cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
    }

    Context '<Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsProjects'; IdParam = 'ProjectId'; Route = '/Project'; Filter = 'is_deleted==0' }
        @{ Cmd = 'Get-GlpiToolsReminders'; IdParam = 'ReminderId'; Route = '/Tools/Reminder'; Filter = $null }
        @{ Cmd = 'Get-GlpiToolsKnowledgeBase'; IdParam = 'KnowledgeBaseId'; Route = '/Knowledgebase/Article'; Filter = $null }
        @{ Cmd = 'Get-GlpiToolsRssFeeds'; IdParam = 'RssfeedId'; Route = '/Tools/RSSFeed'; Filter = $null }
    ) {
        It 'lists the items; only the types that have a trash leave it out' {
            & $Cmd -All | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq $Route -and $All -and $Query.filter -eq $Filter }
        }
        It 'gets each item by id, also from the pipeline' {
            Invoke-WithParams $Cmd @{ $IdParam = 2, 3 } | Out-Null
            4 | & $Cmd | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/2" }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/3" }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/4" }
        }
        It 'does not reach the legacy API' {
            Mock Invoke-GlpiToolsRequestApi { throw 'legacy API reached' } -ModuleName GlpiTools
            { & $Cmd -All | Out-Null } | Should -Not -Throw
        }
    }

    Context 'legacy guard' {
        It 'refuses a legacy call made with the v3 configuration' {
            $Err = $null
            try { InModuleScope GlpiTools { Invoke-GlpiToolsRequestApi -Params @{ uri = 'https://x/apirest.php/Ticket'; method = 'get' } } } catch { $Err = $_ }
            $Err.FullyQualifiedErrorId | Should -Be 'GlpiTools.LegacyCallWithV3'
        }
    }

    Context 'field maps' {
        It 'converts a project to the legacy names' {
            $V3Project = [pscustomobject]@{ id = 1; name = 'p'; parent = [pscustomobject]@{ id = 5; name = 'root' }; status = [pscustomobject]@{ id = 2; name = 'Open' }; is_deleted = $false; date_mod = '2026-01-02T03:04:05+00:00' }
            $Item = InModuleScope GlpiTools -Parameters @{ P = $V3Project } { $P | ConvertFrom-GlpiToolsV3Item -ItemType Project }
            $Item.projects_id | Should -Be 'root'
            $Item.projectstates_id | Should -Be 'Open'
            $Item.is_deleted | Should -Be 0
            $Item.date_mod | Should -Be '2026-01-02 03:04:05'
        }
        It 'renames the reminder and knowledge base columns' {
            $Reminder = InModuleScope GlpiTools { [pscustomobject]@{ id = 1; date_begin = '2026-01-02T03:04:05'; date_end = '2026-01-02T04:04:05' } | ConvertFrom-GlpiToolsV3Item -ItemType Reminder }
            $Reminder.begin | Should -Be '2026-01-02 03:04:05'
            $Reminder.end | Should -Be '2026-01-02 04:04:05'
            $Article = InModuleScope GlpiTools { [pscustomobject]@{ id = 1; content = 'a'; views = 3 } | ConvertFrom-GlpiToolsV3Item -ItemType KnowbaseItem }
            $Article.answer | Should -Be 'a'
            $Article.view | Should -Be 3
        }
    }
}
