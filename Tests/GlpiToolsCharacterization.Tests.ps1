# commands whose v3 branch is characterized; built at discovery time so the tests are generated from it
$CharacterizedCmdlets = Get-ChildItem -Path (Join-Path $PSScriptRoot '..' 'Public') -Recurse -Filter 'Get-*.ps1' |
    Where-Object { $_.FullName -notmatch '[\\/]APICore[\\/]' } |
    Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'handled through the shared request layer|these records are sub-resources' } |
    ForEach-Object { $_.BaseName } | Sort-Object

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
    $script:FixtureDir = Join-Path $PSScriptRoot 'Fixtures'
    $script:SnapshotPath = Join-Path $script:FixtureDir 'characterization-v3.json'
    $script:UpdateSnapshot = $env:GLPITOOLS_UPDATE_SNAPSHOT -eq '1'

    # real v3 answers used as the mocked item for the item types that have a fixture
    $script:ItemFixtures = @{
        '/Assistance/Ticket'  = 'Ticket2-v3.json'
        '/Assistance/Change'  = 'Change1-v3.json'
        '/Assistance/Problem' = 'Problem1-v3.json'
        '/Assets/Computer'    = 'Computer5-v3.json'
        '/Assets/Software'    = 'Software1-v3.json'
        '/Dropdowns/Location' = 'Location4-v3.json'
        '/Administration/Entity' = 'Entity1-v3.json'
        '/Administration/Group'  = 'Group1-v3.json'
        '/Administration/User'   = 'User2-v3.json'
    }

    <#
    .SYNOPSIS
        Builds the item returned by the mocked request for a route and an id.
    #>
    function script:New-MockItem {
        param([string]$Route, [int]$Id)
        $base = ($Route -replace '/\d+$', '')
        if ($script:ItemFixtures.ContainsKey($base)) {
            $item = Get-Content -LiteralPath (Join-Path $script:FixtureDir $script:ItemFixtures[$base]) -Raw | ConvertFrom-Json
            $item.id = $Id
            return $item
        }
        [pscustomobject]@{ id = $Id; name = "item $Id"; comment = 'c' }
    }

    <#
    .SYNOPSIS
        Runs one scenario and returns the calls made to the API, the output, the verbose messages and the error.
    #>
    function script:Invoke-Scenario {
        param([string]$Name, [hashtable]$Params, $Pipeline)
        $global:CharCalls = [System.Collections.Generic.List[string]]::new()
        $result = [ordered]@{ calls = @(); output = $null; verbose = @(); error = $null }
        $items = @()
        $verbose = @()
        try {
            if ($null -ne $Pipeline) {
                $raw = @($Pipeline | & $Name @Params -Verbose 4>&1)
            } else {
                $raw = @(& $Name @Params -Verbose 4>&1)
            }
            foreach ($r in $raw) {
                if ($r -is [System.Management.Automation.VerboseRecord]) { $verbose += $r.Message } else { $items += , $r }
            }
        } catch {
            $result.error = "$($_.FullyQualifiedErrorId)|$($_.Exception.Message)"
        }
        $result.calls = @($global:CharCalls)
        $result.verbose = $verbose
        $result.output = ($items | ConvertTo-Json -Depth 8 -Compress -WarningAction SilentlyContinue)
        $result
    }

    <#
    .SYNOPSIS
        Builds the scenarios of a command from its parameter sets.
    #>
    function script:Get-Scenarios {
        param([string]$Name)
        $command = Get-Command $Name
        $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $has = { param($n) $command.Parameters.ContainsKey($n) }
        # parameters that only the v3 requires are always informed, except in the dedicated missing-parameter scenarios
        $extra = @{}
        if ($Name -eq 'Get-GlpiToolsComputerSoftwareVersions') { $extra.ComputerId = 7 }
        if ($Name -eq 'Get-GlpiToolsSoftwareVersions') { $extra.SoftwareId = 7 }
        if ((& $has 'ItemType') -and (& $has 'ItemId') -and $Name -like '*FinancialAndAdministrative*') { $extra.ItemType = 'Computer'; $extra.ItemId = 7 }
        $subResource = $extra.Count -gt 0
        $list = [ordered]@{}
        foreach ($set in $command.ParameterSets) {
            $mandatory = @($set.Parameters | Where-Object { $_.IsMandatory -and $_.Name -notin $common })
            if ($set.Name -eq 'All') {
                $list['all'] = @{ Params = ($extra + @{ All = $true }) }
            } elseif ($set.Name -like '*Name') {
                $nameParam = ($mandatory | Select-Object -First 1).Name
                $list['name'] = @{ Params = ($extra + @{ $nameParam = 'foo' }) }
                if (& $has 'SearchInTrash') { $list['name-trash'] = @{ Params = ($extra + @{ $nameParam = 'foo'; SearchInTrash = 'Yes' }) } }
            } elseif ($set.Name -like '*Id' -or $set.Name -eq 'Logs') {
                $idParam = ($mandatory | Select-Object -First 1).Name
                $list['id'] = @{ Params = ($extra + @{ $idParam = @(2, 3) }) }
                $list['id-raw'] = @{ Params = ($extra + @{ $idParam = @(2, 3); Raw = $true }) }
                $list['id-missing'] = @{ Params = ($extra + @{ $idParam = @(2, 999) }) }
                $list['id-error'] = @{ Params = ($extra + @{ $idParam = @(998) }) }
                # sub-resources list once per pipeline input; that behavior is covered by dedicated tests
                if (-not $subResource) { $list['id-pipeline'] = @{ Params = $extra; Pipeline = @(4, 5) } }
                if (& $has 'Parameter') {
                    # every value the command accepts, so the supported and the unsupported extras are both exercised
                    $validValues = ($command.Parameters['Parameter'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues
                    foreach ($p in $validValues) {
                        $list["id-parameter-$p"] = @{ Params = ($extra + @{ $idParam = 2; Parameter = $p }) }
                        $list["id-raw-parameter-$p"] = @{ Params = ($extra + @{ $idParam = 2; Parameter = $p; Raw = $true }) }
                    }
                }
            } elseif ($set.Name -eq '__AllParameterSets') {
                $required = @{}
                foreach ($m in $mandatory) { $required[$m.Name] = 5 }
                $list['default'] = @{ Params = $required }
                if (& $has 'Raw') { $list['default-raw'] = @{ Params = ($required + @{ Raw = $true }) } }
            }
        }
        $list
    }

    <#
    .SYNOPSIS
        Runs every scenario of a command and returns them keyed by scenario name.
    #>
    function script:Get-CmdletSnapshot {
        param([string]$Name)
        $snap = [ordered]@{}
        foreach ($scenario in (Get-Scenarios -Name $Name).GetEnumerator()) {
            $snap[$scenario.Key] = Invoke-Scenario -Name $Name -Params $scenario.Value.Params -Pipeline $scenario.Value.Pipeline
        }
        $snap
    }

    $script:Stored = $null
    if (-not $script:UpdateSnapshot) {
        $script:Stored = Get-Content -LiteralPath $script:SnapshotPath -Raw | ConvertFrom-Json
    }
    $script:Collected = [ordered]@{}
}

AfterAll {
    if ($script:UpdateSnapshot) {
        $script:Collected | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:SnapshotPath -Encoding utf8
    }
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name CharCalls -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Characterization of the v3 branch of the read cmdlets' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        # the mock records each call and answers by route, with 404 for id 999 and 500 for id 998
        Mock Invoke-GlpiToolsRequest {
            $query = if ($Query) { ($Query.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '&' } else { '' }
            $global:CharCalls.Add("$Method $Resource ?$query all=$([bool]$All)")
            if ($Resource -match '/(\d+)$' -and $Resource -notmatch '/(Timeline|Infocom|Version|SoftwareInstallation)') {
                $id = [int]$Matches[1]
                if ($id -eq 999 -or $id -eq 998) {
                    $code = if ($id -eq 999) { 'GlpiApi.404' } else { 'GlpiApi.500' }
                    $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new("failure $id"), $code, 'InvalidOperation', $null)
                    $PSCmdlet.ThrowTerminatingError($e)
                }
                return (New-MockItem -Route $Resource -Id $id)
            }
            if ($Resource -like '*/Timeline/Document') { return @([pscustomobject]@{ id = 31; name = 'doc a' }, [pscustomobject]@{ id = 32; name = 'doc b' }) }
            if ($Resource -like '*/Timeline/Task') { return @([pscustomobject]@{ type = 'Task'; item = [pscustomobject]@{ id = 41; content = 't' } }) }
            if ($Resource -eq '/Setup/Plugin') { return @([pscustomobject]@{ id = 1; key = 'a'; state = 1 }, [pscustomobject]@{ id = 2; key = 'b'; state = 4 }, [pscustomobject]@{ id = 3; key = 'c'; state = 2 }) }
            if ($Resource -like '*/Infocom') { return [pscustomobject]@{ id = 2; items_id = 7 } }
            if ($Resource -like '*/Version') { return @([pscustomobject]@{ id = 2; name = 'v2' }, [pscustomobject]@{ id = 3; name = 'v3' }, [pscustomobject]@{ id = 4; name = 'v4' }) }
            if ($Resource -like '*/SoftwareInstallation') { return @([pscustomobject]@{ id = 2; name = 'i2' }, [pscustomobject]@{ id = 3; name = 'i3' }, [pscustomobject]@{ id = 4; name = 'i4' }) }
            @((New-MockItem -Route $Resource -Id 1), (New-MockItem -Route $Resource -Id 2))
        } -ModuleName GlpiTools
    }

    It 'covers the expected number of commands' -ForEach @(@{ Count = $CharacterizedCmdlets.Count }) {
        $Count | Should -Be 82
    }

    It '<_> keeps the calls and the output of every scenario' -ForEach $CharacterizedCmdlets {
        $snapshot = Get-CmdletSnapshot -Name $_
        if ($script:UpdateSnapshot) {
            $script:Collected[$_] = $snapshot
        } else {
            $script:Stored.PSObject.Properties.Name | Should -Contain $_
            $actual = $snapshot | ConvertTo-Json -Depth 12 -Compress
            $expected = $script:Stored.$_ | ConvertTo-Json -Depth 12 -Compress
            $actual | Should -BeExactly $expected
        }
    }
}
