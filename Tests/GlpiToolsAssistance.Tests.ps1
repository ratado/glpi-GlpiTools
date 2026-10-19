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
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Change, problem and recurring ticket cmdlets on API v3' {
    BeforeAll {
        # runs a cmdlet with the parameters given as a hashtable
        function script:Invoke-WithParams { param($Name, $Params) & $Name @Params }
    }
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
    }

    Context '<Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsChanges'; IdParam = 'ChangeId'; NameParam = 'ChangeName'; Route = '/Assistance/Change'; Filter = 'is_deleted==0'; Documents = $true }
        @{ Cmd = 'Get-GlpiToolsProblems'; IdParam = 'ProblemId'; NameParam = 'ProblemName'; Route = '/Assistance/Problem'; Filter = 'is_deleted==0'; Documents = $true }
        @{ Cmd = 'Get-GlpiToolsRecurrentTickets'; IdParam = 'RecurrentTicketId'; NameParam = 'RecurrentTicketName'; Route = '/Assistance/RecurringTicket'; Filter = $null; Documents = $false }
    ) {
        It 'lists the items' {
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
        It 'skips a missing item but reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ $IdParam = 99 } } | Should -Not -Throw
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-WithParams $Cmd @{ $IdParam = 99 } } | Should -Throw '*boom*'
        }
        It 'searches by name' {
            Invoke-WithParams $Cmd @{ $NameParam = 'foo' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq $Route -and $Query.filter -like 'name=ilike=*foo*;*' }
        }
        It 'refuses -Parameter values without a v3 equivalent' {
            { Invoke-WithParams $Cmd @{ $IdParam = 2; Parameter = 'WithLogs' } } | Should -Throw '*-Parameter WithLogs is not supported*'
        }
        It 'handles -Parameter WithDocuments' -Skip:(-not $Documents) {
            Invoke-WithParams $Cmd @{ $IdParam = 2; Parameter = 'WithDocuments' } | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq "$Route/2/Timeline/Document" }
        }
        It 'refuses -Parameter WithDocuments where the item has no documents' -Skip:$Documents {
            { Invoke-WithParams $Cmd @{ $IdParam = 2; Parameter = 'WithDocuments' } } | Should -Throw '*-Parameter WithDocuments is not supported*'
        }
    }
}

Describe 'Change, problem and recurring ticket cmdlets on the legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 5; name = 'x' } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'still calls apirest.php for <Cmd>' -ForEach @(
        @{ Cmd = 'Get-GlpiToolsChanges'; IdParam = 'ChangeId'; Item = 'Change' }
        @{ Cmd = 'Get-GlpiToolsProblems'; IdParam = 'ProblemId'; Item = 'Problem' }
        @{ Cmd = 'Get-GlpiToolsRecurrentTickets'; IdParam = 'RecurrentTicketId'; Item = 'ticketrecurrent' }
    ) {
        & $Cmd -All | Out-Null
        Invoke-WithParams $Cmd @{ $IdParam = 2; Raw = $true } | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq "http://glpi/apirest.php/$Item/?range=0-9999999999999" }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq "http://glpi/apirest.php/$Item/2" }
    }
}
