BeforeAll {
    # keep the real config untouched by redirecting the home directory
    $script:OriginalHome = $env:HOME
    $script:OriginalLocalAppData = $env:LOCALAPPDATA
    $script:SavedSession = $global:GlpiToolsSessionToken
    $script:SavedContext = $global:GlpiToolsContext
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
    $global:GlpiToolsContext = $script:SavedContext
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-GlpiToolsV3EnumId' {
    It 'translates names and keeps numbers' -ForEach @(
        @{ Kind = 'Level'; Value = 'High'; Expected = 4 }
        @{ Kind = 'Level'; Value = '3'; Expected = 3 }
        @{ Kind = 'Type'; Value = 'Request'; Expected = 2 }
        @{ Kind = 'Type'; Value = '1'; Expected = 1 }
        @{ Kind = 'TaskState'; Value = 'Done'; Expected = 2 }
        @{ Kind = 'Validation'; Value = 'Granted'; Expected = 3 }
        @{ Kind = 'Validation'; Value = 'unknown'; Expected = 1 }
    ) {
        ConvertTo-GlpiToolsV3EnumId -Kind $Kind -Value $Value | Should -Be $Expected
    }
}

Describe 'Ticket cmdlets on API v3 with pipeline input by property name' {
    BeforeEach {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 9 } } -ModuleName GlpiTools
    }
    It 'creates the ticket with the urgency and the type of the piped object' {
        [pscustomobject]@{ name = 'n'; content = 'c'; urgency = 'High'; Type = 'Request' } | New-GlpiToolsTicket | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Method -eq 'Post' -and $Body.urgency -eq 4 -and $Body.type -eq 2 }
    }
    It 'creates the task with the status of the piped object' {
        [pscustomobject]@{ ticket_id = 2; content = 'tk'; Status = 'Done' } | Add-GlpiToolsTicketTask | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Body.state -eq 2 }
    }
    It 'returns the created ticket and reports the error when the team cannot be completed' {
        Mock Add-GlpiToolsV3TeamMember { throw 'user not found' } -ModuleName GlpiTools
        $Ticket = New-GlpiToolsTicket -name 'n' -content 'c' -requester_id 5 -ErrorVariable Failure -ErrorAction SilentlyContinue
        $Ticket.id | Should -Be 9
        "$Failure" | Should -Match 'Ticket 9 was created'
    }
}

Describe 'Filters, ids and context' {
    It 'keeps the parentheses when a value ends with an escaped backslash before an OR' {
        ConvertTo-GlpiToolsRsql -Criteria @{ Field = 'name'; Value = 'a\' }, @{ Field = 'id'; Value = 1; Link = 'OR' } -Required @{ Field = 'is_deleted'; Value = 0 } | Should -Be '(name==a\\,id==1);is_deleted==0'
    }
    It 'escapes the id placed in the route' {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { [pscustomobject]@{ id = 1; name = 'x' } } -ModuleName GlpiTools
        Get-GlpiToolsTickets -TicketId '2/../x?y=1' | Out-Null
        Should -Invoke Invoke-GlpiToolsRequest -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Resource -eq '/Assistance/Ticket/2%2F..%2Fx%3Fy%3D1' }
    }
    It 'drops the entity chosen before when the profile changes' {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p
        Set-GlpiToolsSessionToken -SessionToken 'AT' -ExpiresAt ([datetime]::UtcNow.AddHours(1))
        Mock Invoke-GlpiToolsRequest { '{"profiles":{"6":{"name":"x"}}}' | ConvertFrom-Json } -ModuleName GlpiTools
        Set-GlpiToolsV3Context -EntityId 3 -EntityRecursive $true
        Set-GlpiToolsChangeActiveProfile -ProfilesId 6 | Should -BeTrue
        $global:GlpiToolsContext.ProfileId | Should -Be 6
        $global:GlpiToolsContext.PSObject.Properties.Name | Should -Not -Contain 'EntityId'
    }
    It 'warns when the v3 address uses http' {
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'http://glpi.example.com' -ClientId c -ClientSecret s -Username u -Password p -WarningVariable Warned -WarningAction SilentlyContinue
        "$Warned" | Should -Match 'http://'
    }
}

Describe 'Token and request errors' {
    BeforeEach {
        $global:GlpiToolsSessionToken = $null
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId 'cid' -ClientSecret 'csecret' -Username 'glpi' -Password 'pw' -Scope 'api'
        Mock Invoke-RestMethod { [pscustomobject]@{ token_type = 'Bearer'; expires_in = 3600; access_token = 'AT1'; refresh_token = 'RT1' } } -ModuleName GlpiTools
    }
    It 'repeats the password grant when the refresh answers invalid_request' {
        Set-GlpiToolsInitSession | Out-Null
        $global:GlpiToolsSessionToken.ExpiresAt = [datetime]::UtcNow.AddMinutes(-1)
        Mock Invoke-RestMethod {
            $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Bad Request'), 'x', 'NotSpecified', $null)
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":"invalid_request","error_description":"revoked"}')
            throw $e
        } -ModuleName GlpiTools -ParameterFilter { $Body.grant_type -eq 'refresh_token' }
        Mock Invoke-RestMethod { [pscustomobject]@{ token_type = 'Bearer'; expires_in = 3600; access_token = 'AT2'; refresh_token = 'RT2' } } -ModuleName GlpiTools -ParameterFilter { $Body.grant_type -eq 'password' }
        (Get-GlpiToolsSessionToken).SessionToken | Should -Be 'AT2'
    }
    It 'keeps the typed id of a rejected credential when a request needs a new token' {
        Mock Invoke-RestMethod {
            $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Unauthorized'), 'x', 'NotSpecified', $null)
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"error":"invalid_grant","error_description":"bad"}')
            throw $e
        } -ModuleName GlpiTools
        $Id = $null
        try { Get-GlpiToolsTickets -TicketId 1 } catch { $Id = $_.FullyQualifiedErrorId }
        $Id | Should -BeLike 'GlpiOAuth.invalid_grant*'
    }
}

Describe 'Legacy request wrapper error handling' {
    BeforeEach {
        Set-GlpiToolsConfig -AppToken 'app1' -UserToken 'usr1' -PathToGlpi 'http://glpi/apirest.php'
    }
    It 'reads the body of the error from ErrorDetails' {
        Mock Invoke-RestMethod {
            $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Not Found'), 'x', 'NotSpecified', $null)
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('["ERROR_ITEM_NOT_FOUND","Item not found"]')
            throw $e
        } -ModuleName GlpiTools
        { Invoke-GlpiToolsRequestApi -Params @{ uri = 'http://glpi/apirest.php/Ticket/9'; method = 'get' } | Out-Null } | Should -Throw '*Not Found*'
        $global:GLPIToolsErrorOutput.Code | Should -Be 'ERROR_ITEM_NOT_FOUND'
        $global:GLPIToolsErrorOutput.Details | Should -Be 'Item not found'
    }
    It 'reports an unknown error when the failure has no response' {
        Mock Invoke-RestMethod { throw 'connection refused' } -ModuleName GlpiTools
        { Invoke-GlpiToolsRequestApi -Params @{ uri = 'http://glpi/apirest.php/Ticket/9'; method = 'get' } | Out-Null } | Should -Throw '*connection refused*'
        $global:GLPIToolsErrorOutput.Code | Should -Be 'UNKNOWN ERROR'
    }
    It 'keeps the success output clean and the failure details out of the output stream' {
        Mock Invoke-RestMethod {
            $e = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Not Found'), 'x', 'NotSpecified', $null)
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('["ERROR_ITEM_NOT_FOUND","Item not found"]')
            throw $e
        } -ModuleName GlpiTools
        $Output = & { try { Invoke-GlpiToolsRequestApi -Params @{ uri = 'http://glpi/apirest.php/Ticket/9'; method = 'get' } } catch { $null = $_ } }
        $Output | Should -BeNullOrEmpty
        $Verbose = & { try { Invoke-GlpiToolsRequestApi -Params @{ uri = 'http://glpi/apirest.php/Ticket/9'; method = 'get' } -Verbose } catch { $null = $_ } } 4>&1
        $Verbose | Should -BeOfType [System.Management.Automation.VerboseRecord]
        $global:GLPIToolsErrorOutput.Code | Should -Be 'ERROR_ITEM_NOT_FOUND'
        Mock Invoke-RestMethod { [pscustomobject]@{ id = 9 } } -ModuleName GlpiTools
        $Ok = Invoke-GlpiToolsRequestApi -Params @{ uri = 'http://glpi/apirest.php/Ticket/9'; method = 'get' }
        @($Ok).Count | Should -Be 1
        $Ok.id | Should -Be 9
    }
}
