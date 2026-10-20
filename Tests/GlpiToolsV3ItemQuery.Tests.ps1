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

Describe 'Invoke-GlpiToolsV3ItemQuery' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
        Mock Search-GlpiToolsItems { [pscustomobject]@{ id = 8; name = 'found' } } -ModuleName GlpiTools
        # the conversion is mocked to expose the arguments it receives
        Mock ConvertFrom-GlpiToolsV3Item { [pscustomobject]@{ Type = $ItemType; Raw = [bool]$Raw; Input = $InputObject } } -ModuleName GlpiTools
    }

    Context 'listing' {
        It 'lists outside the trash and converts to the legacy properties as raw' {
            $r = Invoke-GlpiToolsV3ItemQuery -ParameterSetName All -Resource '/Assets/Computer' -ItemType Computer
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq '/Assets/Computer' -and $All -and $Query.filter -eq 'is_deleted==0' }
            $r.Type | Should -Be 'Computer'
            $r.Raw | Should -BeTrue
        }
        It 'does not filter the trash with IncludeTrash' {
            Invoke-GlpiToolsV3ItemQuery -ParameterSetName All -Resource '/Assistance/RecurringTicket' -ItemType RecurringTicket -IncludeTrash | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/RecurringTicket' -and $All -and -not $Query }
        }
    }

    Context 'reading by id' {
        It 'reads each id and converts to names unless Raw is used' {
            $r = Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 2, 3
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Computer/2' -and -not $All }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assets/Computer/3' }
            @($r).Count | Should -Be 2
            $r[0].Raw | Should -BeFalse
            (Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 2 -Raw).Raw | Should -BeTrue
        }
        It 'never converts to names with AlwaysRaw' {
            (Invoke-GlpiToolsV3ItemQuery -ParameterSetName LocationsId -Resource '/Dropdowns/Location' -ItemType Location -Id 2 -AlwaysRaw).Raw | Should -BeTrue
        }
        It 'skips a missing item with a verbose message' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            $v = Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 99 -Verbose 4>&1
            @($v | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message | Should -Contain 'Computer ID = 99 is not found'
            Should -Invoke ConvertFrom-GlpiToolsV3Item -ModuleName GlpiTools -Exactly 0
        }
        It 'reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 99 } | Should -Throw '*boom*'
        }
        It 'stops on an extra that the v3 does not have, before any request' {
            { Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 2 -Parameter WithLogs -SupportedParameter ExpandDropdowns } | Should -Throw '*-Parameter WithLogs is not supported*'
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
        }
        It 'accepts the supported extras' {
            { Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 2 -Parameter ExpandDropdowns -SupportedParameter ExpandDropdowns } | Should -Not -Throw
        }
        It 'does not check the extra when the command has no list of supported ones' {
            { Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerId -Resource '/Assets/Computer' -ItemType Computer -Id 2 -Parameter WithLogs } | Should -Not -Throw
        }
        It 'adds the documents of the timeline with WithDocuments' {
            Mock Invoke-GlpiToolsRequest {
                if ($Resource -like '*/Timeline/Document') { return @([pscustomobject]@{ id = 31 }) }
                [pscustomobject]@{ id = 2 }
            } -ModuleName GlpiTools
            $r = Invoke-GlpiToolsV3ItemQuery -ParameterSetName TicketId -Resource '/Assistance/Ticket' -ItemType Ticket -Id 2 -Parameter WithDocuments -SupportedParameter ExpandDropdowns, WithDocuments
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/2/Timeline/Document' -and $All }
            $r.Input._documents[0].id | Should -Be 31
        }
        It 'returns the item when the documents are not found, but reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                if ($Resource -like '*/Timeline/Document') {
                    $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                    $PSCmdlet.ThrowTerminatingError($e)
                }
                [pscustomobject]@{ id = 2 }
            } -ModuleName GlpiTools
            (Invoke-GlpiToolsV3ItemQuery -ParameterSetName TicketId -Resource '/Assistance/Ticket' -ItemType Ticket -Id 2 -Parameter WithDocuments).Input._documents.Count | Should -Be 0
            Mock Invoke-GlpiToolsRequest {
                if ($Resource -like '*/Timeline/Document') {
                    $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                    $PSCmdlet.ThrowTerminatingError($e)
                }
                [pscustomobject]@{ id = 2 }
            } -ModuleName GlpiTools
            { Invoke-GlpiToolsV3ItemQuery -ParameterSetName TicketId -Resource '/Assistance/Ticket' -ItemType Ticket -Id 2 -Parameter WithDocuments } | Should -Throw '*boom*'
        }
    }

    Context 'searching by name' {
        It 'searches with the item type by default and always returns raw' {
            $r = Invoke-GlpiToolsV3ItemQuery -ParameterSetName ComputerName -Resource '/Assets/Computer' -ItemType Computer -Name foo
            Should -Invoke Search-GlpiToolsItems -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $SearchFor -eq 'Computer' -and $SearchType -eq 'contains' -and $SearchValue -eq 'foo' -and -not $PSBoundParameters.ContainsKey('SearchInTrash') -and -not $PSBoundParameters.ContainsKey('SearchField') }
            $r.Raw | Should -BeTrue
        }
        It 'uses the informed search type, field and trash option' {
            Invoke-GlpiToolsV3ItemQuery -ParameterSetName UserName -Resource '/Administration/User' -ItemType User -SearchFor User -SearchField username -SearchInTrash Yes -Name foo | Out-Null
            Should -Invoke Search-GlpiToolsItems -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $SearchField -eq 'username' -and $SearchInTrash -eq 'Yes' }
            Invoke-GlpiToolsV3ItemQuery -ParameterSetName CloseTimeName -Resource '/Dropdowns/CloseTime' -ItemType CloseTime -SearchFor holiday -Name foo | Out-Null
            Should -Invoke Search-GlpiToolsItems -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $SearchFor -eq 'holiday' }
        }
    }

    It 'does nothing for a parameter set it does not know' {
        Invoke-GlpiToolsV3ItemQuery -ParameterSetName Other -Resource '/Assets/Computer' -ItemType Computer | Should -BeNullOrEmpty
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
    }
}
