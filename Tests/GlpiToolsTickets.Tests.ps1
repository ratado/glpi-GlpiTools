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
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Ticket cmdlets on API v3' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9; name = 'x' } } -ModuleName GlpiTools
    }

    Context 'Get-GlpiToolsTickets' {
        It 'lists the tickets outside the trash' {
            Get-GlpiToolsTickets -All | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq '/Assistance/Ticket' -and $All -and $Query.filter -eq 'is_deleted==0' }
        }
        It 'gets each ticket by id, with or without -Raw' {
            Get-GlpiToolsTickets -TicketId 2, 3 | Out-Null
            Get-GlpiToolsTickets -TicketId 4 -Raw | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/2' }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/3' }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/4' }
        }
        It 'skips a missing ticket but reports other failures' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Get-GlpiToolsTickets -TicketId 99 } | Should -Not -Throw
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('boom'), 'GlpiApi.500', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools
            { Get-GlpiToolsTickets -TicketId 99 } | Should -Throw '*boom*'
        }
        It 'works with pipeline input' {
            2, 3 | Get-GlpiToolsTickets | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 2 -ParameterFilter { $Resource -match '^/Assistance/Ticket/[23]$' }
        }
        It 'still returns the ticket when its documents are not found' {
            Mock Invoke-GlpiToolsRequest {
                $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('gone'), 'GlpiApi.404', 'InvalidOperation', $null)
                $PSCmdlet.ThrowTerminatingError($e)
            } -ModuleName GlpiTools -ParameterFilter { $Resource -like '*/Timeline/Document' }
            Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 2 } } -ModuleName GlpiTools -ParameterFilter { $Resource -eq '/Assistance/Ticket/2' }
            (Get-GlpiToolsTickets -TicketId 2 -Parameter WithDocuments -ErrorAction SilentlyContinue).id | Should -Be 2
        }
        It 'adds the documents with -Parameter WithDocuments' {
            Get-GlpiToolsTickets -TicketId 2 -Parameter WithDocuments | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/2/Timeline/Document' }
        }
        It 'refuses -Parameter values without a v3 equivalent' {
            { Get-GlpiToolsTickets -TicketId 2 -Parameter WithLogs } | Should -Throw '*-Parameter WithLogs is not supported*'
        }
        It 'searches by name' {
            Get-GlpiToolsTickets -TicketName foo | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Query.filter -eq 'name=ilike=*foo*;is_deleted==0' }
        }
    }

    Context 'New-GlpiToolsTicket' {
        It 'creates the ticket with v3 fields' {
            New-GlpiToolsTicket -name 'Subj' -content 'Body' -urgency High -impact 3 -itilcategories_id 5 -Type Request -ApprovalRequired -requesttypes_id 2 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
                $Method -eq 'Post' -and $Resource -eq '/Assistance/Ticket' -and $Body.name -eq 'Subj' -and $Body.content -eq 'Body' -and
                $Body.type -eq 2 -and $Body.urgency -eq 4 -and $Body.impact -eq 3 -and $Body.category.id -eq 5 -and
                $Body.request_type.id -eq 2 -and $Body.global_validation -eq 2
            }
        }
        It 'adds requester and technician to the team of the new ticket' {
            Mock Invoke-GlpiToolsRequest { @() } -ModuleName GlpiTools -ParameterFilter { $Method -eq 'Get' -and $Resource -like '*/TeamMember' }
            New-GlpiToolsTicket -name 'S' -content 'B' -requester_id 4 -technician_id 5 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/9/TeamMember' -and $Body.role -eq 'requester' -and $Body.id -eq 4 -and $Body.type -eq 'User' }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/9/TeamMember' -and $Body.role -eq 'assigned' -and $Body.id -eq 5 }
        }
        It 'refuses linked items and disabled notification before creating anything' {
            { New-GlpiToolsTicket -name 'S' -content 'B' -item_id 1 -item_type Computer } | Should -Throw '*not supported*'
            { New-GlpiToolsTicket -name 'S' -content 'B' -DisableNotification } | Should -Throw '*-DisableNotification is not supported*'
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0
        }
    }

    Context 'Update-GlpiToolsTicket' {
        It 'patches only the fields that were given' {
            Update-GlpiToolsTicket -ticket_id 7 -name 'New' -status 4 -Validation Granted -itilcategories_id 3 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
                $Method -eq 'Patch' -and $Resource -eq '/Assistance/Ticket/7' -and $Body.name -eq 'New' -and $Body.status.id -eq 4 -and
                $Body.global_validation -eq 3 -and $Body.category.id -eq 3 -and -not $Body.ContainsKey('urgency') -and -not $Body.ContainsKey('content')
            }
        }
        It 'keeps a numeric -Type' {
            Update-GlpiToolsTicket -ticket_id 7 -Type 2 | Out-Null
            Update-GlpiToolsTicket -ticket_id 7 -Type Incident | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Patch' -and $Body.type -eq 2 }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Patch' -and $Body.type -eq 1 }
        }
        It 'does not add a team member twice' {
            Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ role = 'requester'; id = 4; type = 'User' } } -ModuleName GlpiTools -ParameterFilter { $Method -eq 'Get' -and $Resource -like '*/TeamMember' }
            Update-GlpiToolsTicket -ticket_id 7 -requester_id 4 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0 -ParameterFilter { $Method -eq 'Post' }
        }
        It 'adds the requester to the team' {
            Mock Invoke-GlpiToolsRequest { @() } -ModuleName GlpiTools -ParameterFilter { $Method -eq 'Get' -and $Resource -like '*/TeamMember' }
            Update-GlpiToolsTicket -ticket_id 7 -requester_id 4 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/7/TeamMember' -and $Body.role -eq 'requester' }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0 -ParameterFilter { $Method -eq 'Patch' }
        }
    }

    Context 'Timeline cmdlets' {
        It 'adds a followup' {
            Add-GlpiToolsTicketFollowup -ticket_id 7 -content 'f' -IsPrivate | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Post' -and $Resource -eq '/Assistance/Ticket/7/Timeline/Followup' -and $Body.content -eq 'f' -and $Body.is_private -eq $true }
        }
        It 'adds a solution' {
            Add-GlpiToolsTicketSolution -ticket_id 7 -content 's' -solutiontype_id 3 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/7/Timeline/Solution' -and $Body.type.id -eq 3 }
        }
        It 'returns the task inside the timeline wrapper' {
            Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ type = 'Task'; item = [pscustomobject]@{ id = 3; content = 'c' } } } -ModuleName GlpiTools
            $t = Get-GlpiToolsTicketTask -ticket_id 7
            $t.id | Should -Be 3
            $t.content | Should -Be 'c'
        }
        It 'adds, lists and updates tasks' {
            Add-GlpiToolsTicketTask -ticket_id 7 -content 't' -Status Done -duration 60 | Out-Null
            Get-GlpiToolsTicketTask -ticket_id 7 | Out-Null
            Update-GlpiToolsTicketTask -task_id 11 -ticket_id 7 -content 'u' -Status Todo | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Post' -and $Resource -eq '/Assistance/Ticket/7/Timeline/Task' -and $Body.state -eq 2 -and $Body.duration -eq 60 }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Get' -and $Resource -eq '/Assistance/Ticket/7/Timeline/Task' -and $All }
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Patch' -and $Resource -eq '/Assistance/Ticket/7/Timeline/Task/11' -and $Body.state -eq 1 -and $Body.content -eq 'u' }
        }
        It 'sends a zero duration and refuses an empty task update' {
            Add-GlpiToolsTicketTask -ticket_id 7 -content 't' -duration 0 | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Body.ContainsKey('duration') -and $Body.duration -eq 0 }
            Update-GlpiToolsTicketTask -task_id 11 -ticket_id 7 -WarningAction SilentlyContinue | Out-Null
            Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 0 -ParameterFilter { $Method -eq 'Patch' }
        }
        It 'has no equivalent for linking items' {
            { Add-GlpiToolsTicketItem -ticket_id 7 -item_id 1 -item_type Computer } | Should -Throw '*Add-GlpiToolsTicketItem is not supported*'
        }
    }
}

Describe 'Ticket cmdlets on the legacy API (regression)' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken app1 -UserToken usr1 -PathToGlpi 'http://glpi/apirest.php'
        Set-GlpiToolsSessionToken -SessionToken 'S1'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 5; name = 'x' } } -ModuleName GlpiTools
        Mock Invoke-GlpiToolsRequest { throw 'v3 layer must not be used' } -ModuleName GlpiTools
    }
    It 'lists and gets tickets from apirest.php' {
        Get-GlpiToolsTickets -All | Out-Null
        Get-GlpiToolsTickets -TicketId 2 -Raw | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'http://glpi/apirest.php/Ticket/?range=0-9999999999999' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'http://glpi/apirest.php/Ticket/2' -and $Headers['App-Token'] -eq 'app1' }
    }
    It 'creates and updates tickets with the legacy verbs' {
        New-GlpiToolsTicket -name 'S' -content 'B' | Out-Null
        Update-GlpiToolsTicket -ticket_id 7 -name 'n' | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'post' -and $Uri -eq 'http://glpi/apirest.php/Ticket/' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'PUT' -and $Uri -eq 'http://glpi/apirest.php/Ticket/7' }
    }
    It 'adds followups, solutions and tasks to the legacy sub-resources' {
        Add-GlpiToolsTicketFollowup -ticket_id 7 -content 'f' | Out-Null
        Add-GlpiToolsTicketSolution -ticket_id 7 -content 's' | Out-Null
        Add-GlpiToolsTicketTask -ticket_id 7 -content 't' | Out-Null
        Get-GlpiToolsTicketTask -ticket_id 7 | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'post' -and $Uri -eq 'http://glpi/apirest.php/Ticket/7/TicketFollowup/' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'post' -and $Uri -eq 'http://glpi/apirest.php/Ticket/7/ITILSolution/' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'post' -and $Uri -eq 'http://glpi/apirest.php/Ticket/7/TicketTask/' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'get' -and $Uri -eq 'http://glpi/apirest.php/Ticket/7/TicketTask/' }
    }
    It 'links an item through Item_ticket' {
        Add-GlpiToolsTicketItem -ticket_id 7 -item_id 1 -item_type Computer | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'http://glpi/apirest.php/Ticket/7/Item_ticket/' }
    }
}
