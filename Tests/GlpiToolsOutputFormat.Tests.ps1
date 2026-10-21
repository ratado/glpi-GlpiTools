# commands whose v3 branch reads items through the shared conversion; built at discovery time like the characterization test
$NativeCmdlets = Get-ChildItem -Path (Join-Path $PSScriptRoot '..' 'Public') -Recurse -Filter 'Get-*.ps1' |
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
    Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools

    <#
    .SYNOPSIS
        Builds the parameters that run the All, Id and Name scenarios of a command.
    #>
    function script:Get-NativeScenarios {
        param([string]$Name)
        $command = Get-Command $Name
        $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        # parameters that only the v3 requires are always informed
        $extra = @{}
        if ($Name -eq 'Get-GlpiToolsComputerSoftwareVersions') { $extra.ComputerId = 7 }
        if ($Name -eq 'Get-GlpiToolsSoftwareVersions') { $extra.SoftwareId = 7 }
        if ($Name -like '*FinancialAndAdministrative*') { $extra.ItemType = 'Computer'; $extra.ItemId = 7 }
        $list = [ordered]@{}
        foreach ($set in $command.ParameterSets) {
            $mandatory = @($set.Parameters | Where-Object { $_.IsMandatory -and $_.Name -notin $common })
            if ($set.Name -eq 'All') { $list['all'] = $extra + @{ All = $true } }
            elseif ($set.Name -like '*Name') { $list['name'] = $extra + @{ ($mandatory | Select-Object -First 1).Name = 'foo' } }
            elseif ($set.Name -like '*Id') {
                $idParam = ($mandatory | Select-Object -First 1).Name
                $list['id'] = $extra + @{ $idParam = 2 }
                if ($command.Parameters.ContainsKey('Raw')) { $list['id-raw'] = $extra + @{ $idParam = 2; Raw = $true } }
            }
        }
        $list
    }
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Output format Native on the read cmdlets' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p -OutputFormat Native
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        # every route answers with an item that has a nested relation and a property that the legacy map does not know
        Mock Invoke-GlpiToolsRequest {
            $make = { param($id) [pscustomobject]@{ id = $id; name = "item $id"; entity = [pscustomobject]@{ id = 1; name = 'Root' }; v3_only = 'x'; is_deleted = $false } }
            if ($Resource -match '/(\d+)$' -and $Resource -notmatch '/(Timeline|Infocom|Version|SoftwareInstallation)') { return (& $make ([int]$Matches[1])) }
            if ($Resource -like '*/Infocom') { return (& $make 2) }
            @((& $make 2), (& $make 3))
        } -ModuleName GlpiTools
    }

    It '<_> returns the items as the API v3 sent them' -ForEach $NativeCmdlets {
        $Name = $_
        $Scenarios = Get-NativeScenarios -Name $Name
        foreach ($Scenario in $Scenarios.GetEnumerator()) {
            # Plugins builds its own list and has a dedicated test below
            if ($Name -eq 'Get-GlpiToolsPlugins') { continue }
            $Params = $Scenario.Value
            $Items = @(& $Name @Params -WarningAction SilentlyContinue)
            $Items.Count | Should -BeGreaterThan 0 -Because "$Name $($Scenario.Key) returned nothing"
            foreach ($Item in $Items) {
                $Item.v3_only | Should -Be 'x' -Because "$Name $($Scenario.Key)"
                $Item.entity.name | Should -Be 'Root' -Because "$Name $($Scenario.Key)"
                $Item.PSObject.Properties.Name | Should -Not -Contain 'entities_id'
            }
        }
    }

    It 'covers the same commands as the characterization test' -ForEach @(@{ Count = $NativeCmdlets.Count }) {
        $Count | Should -Be 86
    }

    It 'ignores -Raw and says so in the verbose stream' {
        $Out = Get-GlpiToolsTickets -TicketId 2 -Raw -Verbose 4>&1
        ($Out | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message | Should -Contain '-Raw has no effect with the native output format.'
        ($Out | Where-Object { $_ -isnot [System.Management.Automation.VerboseRecord] }).entity.name | Should -Be 'Root'
    }

    It 'keeps the numeric state of the plugins' {
        Mock Invoke-GlpiToolsRequest { @([pscustomobject]@{ id = 1; key = 'a'; state = 1 }, [pscustomobject]@{ id = 2; key = 'b'; state = 4 }) } -ModuleName GlpiTools
        (Get-GlpiToolsPlugins).state | Should -Be 1, 4
    }

    It 'does not warn when more than one item comes from Get-GlpiToolsItems' {
        $Warnings = $null
        $Items = Get-GlpiToolsItems -ItemType Ticket -WarningVariable Warnings
        @($Items).Count | Should -Be 2
        $Warnings | Should -BeNullOrEmpty
        $Items[0].entity.name | Should -Be 'Root'
    }
}

Describe 'Output format Native on filters and bodies' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p -OutputFormat Native
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { @() } -ModuleName GlpiTools
        $Doc = Get-Content -Path (Join-Path $PSScriptRoot 'Fixtures' 'doc-v3-min.json') -Raw | ConvertFrom-Json
        Mock Get-GlpiToolsV3Document { $Doc } -ModuleName GlpiTools
    }

    It 'does not translate a legacy column used in -SearchText and suggests the v3 name' {
        $Err = $null
        try { Get-GlpiToolsItems -ItemType Ticket -SearchText @{ entities_id = '^1$' } } catch { $Err = $_ }
        $Err.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3InvalidFilterField'
        $Err.Exception.Message | Should -BeLike "*Did you mean 'entity.id'?*"
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
    }
    It 'accepts a v3 property in -SearchText' {
        Get-GlpiToolsItems -ItemType Ticket -SearchText @{ name = 'x' } | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -like 'name=ilike=*x*;*' }
    }
    It 'refuses a legacy column in the body of Add-GlpiToolsItems and suggests the v3 name' {
        $Err = $null
        try { Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ name = 'n'; entities_id = 2 } } catch { $Err = $_ }
        $Err.FullyQualifiedErrorId | Should -Be 'GlpiTools.V3InvalidField'
        $Err.Exception.Message | Should -BeLike "*Did you mean 'entity'*"
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
    }
    It 'sends a v3 body untouched with Add-GlpiToolsItems and Update-GlpiToolsItems' {
        Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ name = 'n'; entity = @{ id = 2 } } | Out-Null
        Update-GlpiToolsItems -UpdateTo Ticket -ItemId 5 -ItemsHashtableWithoutId @{ name = 'm' } | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Post' -and $Body.entity.id -eq 2 }
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Patch' -and $Body.name -eq 'm' }
    }
    It 'sends the body as given when the schema cannot be read' {
        Mock Get-GlpiToolsV3Document { $null } -ModuleName GlpiTools
        Set-GlpiToolsSessionToken -ResetToken
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        { Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ entities_id = 2 } | Out-Null } | Should -Not -Throw
    }
    It 'keeps translating the legacy names in the Legacy format' {
        Set-GlpiToolsOutputFormat -Format Legacy
        Add-GlpiToolsItems -AddTo Ticket -HashtableToAdd @{ name = 'n'; entities_id = 2 } | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Body.entity.id -eq 2 }
    }
}
