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
    # runs a cmdlet with the parameters given as a hashtable
    function script:Invoke-WithParams { param($Name, $Params) & $Name @Params }
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Administration cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
    }

    Context '<Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsEntities'; Base = 'Entity'; Route = '/Administration/Entity'; Field = 'name' }
        @{ Cmd = 'Get-GlpiToolsGroups'; Base = 'Group'; Route = '/Administration/Group'; Field = 'name' }
        @{ Cmd = 'Get-GlpiToolsUsers'; Base = 'User'; Route = '/Administration/User'; Field = 'username' }
    ) {
        It 'lists the items outside the trash' {
            & $Cmd -All | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq $Route -and $All -and $Query.filter -eq 'is_deleted==0' }
        }
        It 'gets each item by id, also from the pipeline' {
            Invoke-WithParams $Cmd @{ "${Base}Id" = 2, 3 } | Out-Null
            4 | & $Cmd | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/2" }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/3" }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/4" }
        }
        It 'skips a missing item but reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ "${Base}Id" = 99 } } | Should -Not -Throw
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ "${Base}Id" = 99 } } | Should -Throw '*boom*'
        }
        It 'searches by the name property of the v3' {
            Invoke-WithParams $Cmd @{ "${Base}Name" = 'foo' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq $Route -and $Query.filter -like "$Field=ilike=*foo*" }
        }
    }

    It 'has no v3 equivalent for the group members' {
        { Get-GlpiToolsGroupsMembers -All } | Should -Throw '*Get-GlpiToolsGroupsMembers is not supported by the GLPI API v3*'
    }
}

Describe 'Administration cmdlets on the legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 5; name = 'x' } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'still calls apirest.php for <Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsEntities'; IdParam = 'EntityId'; Item = 'Entity' }
        @{ Cmd = 'Get-GlpiToolsGroups'; IdParam = 'GroupId'; Item = 'Group' }
        @{ Cmd = 'Get-GlpiToolsUsers'; IdParam = 'UserId'; Item = 'User' }
        @{ Cmd = 'Get-GlpiToolsGroupsMembers'; IdParam = 'GroupMemberId'; Item = 'Group_User' }
    ) {
        & $Cmd -All | Out-Null
        Invoke-WithParams $Cmd @{ $IdParam = 2; Raw = $true } | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -like "http://glpi/apirest.php/$Item/?range=*" }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq "http://glpi/apirest.php/$Item/2" }
    }
}
