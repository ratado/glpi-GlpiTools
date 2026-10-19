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
    $script:RoutesFile = Join-Path $PSScriptRoot '..' 'Private' 'V3Routes.json'
}

AfterAll {
    $env:HOME = $script:OriginalHome
    $env:LOCALAPPDATA = $script:OriginalLocalAppData
    $global:GlpiToolsSessionToken = $script:SavedSession
    Remove-Item -Path $script:TempHome -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'Get-GlpiToolsV3Route' {
    It 'maps item types to routes, ignoring case' -ForEach @(
        @{ Type = 'Ticket'; Route = '/Assistance/Ticket' }
        @{ Type = 'computer'; Route = '/Assets/Computer' }
        @{ Type = 'Location'; Route = '/Dropdowns/Location' }
        @{ Type = 'Softwarelicense'; Route = '/Management/License' }
    ) {
        Get-GlpiToolsV3Route -ItemType $Type | Should -Be $Route
    }
    It 'throws for an item type without a v3 route' {
        { Get-GlpiToolsV3Route -ItemType 'DeviceMemoryModel' } | Should -Throw "*not supported by the GLPI API v3*"
    }
    It 'has only collection routes' {
        $routes = Get-Content $RoutesFile -Raw | ConvertFrom-Json
        $routes.PSObject.Properties.Value | ForEach-Object { $_ | Should -Match '^/[A-Za-z]+(/[A-Za-z]+)?$' }
    }
}

Describe 'ConvertTo-GlpiToolsRsql' {
    It 'builds equality and operators' -ForEach @(
        @{ C = @{ Field = 'name'; Value = 'foo' }; Expected = 'name==foo' }
        @{ C = @{ Field = 'name'; Operator = 'notequals'; Value = 'foo' }; Expected = 'name!=foo' }
        @{ C = @{ Field = 'name'; Operator = 'contains'; Value = 'DC' }; Expected = 'name=ilike=*DC*' }
        @{ C = @{ Field = 'name'; Operator = 'startswith'; Value = 'DC' }; Expected = 'name=ilike=DC*' }
        @{ C = @{ Field = 'name'; Operator = 'endswith'; Value = 'DC' }; Expected = 'name=ilike=*DC' }
        @{ C = @{ Field = 'id'; Operator = 'ge'; Value = 2 }; Expected = 'id=ge=2' }
        @{ C = @{ Field = 'id'; Operator = 'in'; Value = @(1, 2) }; Expected = 'id=in=("1","2")' }
        @{ C = @{ Field = 'name'; Operator = 'isnull' }; Expected = 'name=isnull=' }
    ) {
        ConvertTo-GlpiToolsRsql -Criteria $C | Should -Be $Expected
    }
    It 'joins criteria with AND by default and OR on request' {
        ConvertTo-GlpiToolsRsql -Criteria @{ Field = 'a'; Value = 1 }, @{ Field = 'b'; Value = 2 } | Should -Be 'a==1;b==2'
        ConvertTo-GlpiToolsRsql -Criteria @{ Field = 'a'; Value = 1 }, @{ Field = 'b'; Value = 2; Link = 'OR' } | Should -Be 'a==1,b==2'
    }
    It 'accepts the equality shortcut' {
        ConvertTo-GlpiToolsRsql -Filter @{ name = 'foo' } | Should -Be 'name==foo'
    }
    It 'escapes special characters in values' {
        ConvertTo-GlpiToolsRsql -Filter @{ name = 'a;b,c(d)e\f' } | Should -Be 'name==a\;b\,c\(d\)e\\f'
    }
    It 'keeps spaces and accents' {
        ConvertTo-GlpiToolsRsql -Filter @{ name = 'Ação grande' } | Should -Be 'name==Ação grande'
    }
    It 'wraps values that start with a quote' {
        ConvertTo-GlpiToolsRsql -Filter @{ name = '"x' } | Should -Be ('name==' + [char]39 + [char]34 + 'x' + [char]39)
    }
    It 'does not let a value add criteria' {
        $r = ConvertTo-GlpiToolsRsql -Filter @{ name = 'x;is_deleted==1' }
        $r | Should -Be 'name==x\;is_deleted==1'
    }
    It 'rejects invalid property names, operators and links' {
        { ConvertTo-GlpiToolsRsql -Filter @{ 'name==1;x' = 'a' } } | Should -Throw '*Invalid property*'
        { ConvertTo-GlpiToolsRsql -Criteria @{ Field = 'a'; Operator = 'like'; Value = 1 } } | Should -Throw '*Unknown filter operator*'
        { ConvertTo-GlpiToolsRsql -Criteria @{ Field = 'a'; Value = 1 }, @{ Field = 'b'; Value = 2; Link = 'XOR' } } | Should -Throw '*Unknown filter link*'
    }
}

Describe 'Invoke-GlpiToolsRequest' {
    BeforeEach {
        $global:GlpiToolsSessionToken = $null
        Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' -ClientId 'cid' -ClientSecret 'csecret' -Username 'glpi' -Password 'pw'
        # token grant answers and API answers are told apart by the URI
        Mock Invoke-RestMethod { [pscustomobject]@{ token_type = 'Bearer'; expires_in = 3600; access_token = 'AT1'; refresh_token = 'RT1' } } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/token' }
        Mock Invoke-RestMethod { Set-Variable -Name $ResponseHeadersVariable -Value @{} -Scope 2; [pscustomobject]@{ id = 2 } } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
    }

    It 'refuses to run with a legacy configuration' {
        Set-GlpiToolsConfig -AppToken a -UserToken b -PathToGlpi 'http://x/apirest.php'
        { Invoke-GlpiToolsRequest -Method Get -Resource /Assistance/Ticket/2 } | Should -Throw '*API v3*'
    }
    It 'sends the bearer token and the API version header to the right URL' {
        $r = Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket/2'
        $r.id | Should -Be 2
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Uri -eq 'https://glpi.example.com/api.php/v3.0/Assistance/Ticket/2' -and $Method -eq 'Get' -and
            $Headers['Authorization'] -eq 'Bearer AT1' -and $Headers['GLPI-API-Version'] -eq '3.0.0' -and $Headers['Accept'] -eq 'application/json'
        }
    }
    It 'encodes the query string' {
        Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket' -Query @{ filter = 'name==a b;id=ge=2' } | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter { $Uri -eq 'https://glpi.example.com/api.php/v3.0/Assistance/Ticket?filter=name%3D%3Da%20b%3Bid%3Dge%3D2' }
    }
    It 'sends the body as JSON' {
        Invoke-GlpiToolsRequest -Method Post -Resource '/Assistance/Ticket' -Body @{ name = 'Ação' } | Out-Null
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 1 -ParameterFilter {
            $Method -eq 'Post' -and $ContentType -eq 'application/json' -and $Body -eq '{"name":"Ação"}'
        }
    }
    It 'reads every page of a listing' {
        # 3 pages of 2 items, total 5, reported by Content-Range
        Mock Invoke-RestMethod {
            $start = [int]([regex]::Match($Uri, 'start=(\d+)').Groups[1].Value)
            $items = @($start..([math]::Min($start + 1, 4)) | ForEach-Object { [pscustomobject]@{ id = $_ } })
            Set-Variable -Name $ResponseHeadersVariable -Value @{ 'Content-Range' = @("$start-$($start + $items.Count - 1)/5") } -Scope 2
            $items
        } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
        $r = Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/Computer' -All -PageSize 2
        $r.id | Should -Be @(0, 1, 2, 3, 4)
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 3 -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
    }
    It 'stops on a short page when Content-Range is missing' {
        Mock Invoke-RestMethod {
            $start = [int]([regex]::Match($Uri, 'start=(\d+)').Groups[1].Value)
            Set-Variable -Name $ResponseHeadersVariable -Value @{} -Scope 2
            if ($start -eq 0) { @([pscustomobject]@{ id = 0 }, [pscustomobject]@{ id = 1 }) } else { @([pscustomobject]@{ id = 2 }) }
        } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
        $r = Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/Computer' -All -PageSize 2
        @($r).Count | Should -Be 3
    }
    It 'returns an empty result for an empty listing' {
        Mock Invoke-RestMethod { Set-Variable -Name $ResponseHeadersVariable -Value @{ 'Content-Range' = @('0--1/0') } -Scope 2; @() } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
        @(Invoke-GlpiToolsRequest -Method Get -Resource '/Assets/Computer' -All).Count | Should -Be 0
    }
    It 'renews the token once on 401 and repeats the request' {
        $script:calls = 0
        Mock Invoke-RestMethod {
            $script:calls++
            if ($script:calls -eq 1) {
                $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Unauthorized)
                $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Unauthorized', $resp)
                throw $ex
            }
            Set-Variable -Name $ResponseHeadersVariable -Value @{} -Scope 2
            [pscustomobject]@{ id = 2 }
        } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
        (Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket/2').id | Should -Be 2
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 2 -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
        Should -Invoke Invoke-RestMethod -ModuleName GlpiTools -Exactly 2 -ParameterFilter { $Uri -like '*/api.php/token' }
    }
    It 'turns an API error into an exception with status and message' {
        Mock Invoke-RestMethod {
            $resp = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
            $ex = [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not Found', $resp)
            $e = [System.Management.Automation.ErrorRecord]::new($ex, 'x', 'NotSpecified', $null)
            $e.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('{"status":"ERROR_ITEM_NOT_FOUND","title":"Not found","detail":null}')
            throw $e
        } -ModuleName GlpiTools -ParameterFilter { $Uri -like '*/api.php/v3.0/*' }
        $err = $null
        try { Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket/9' } catch { $err = $_ }
        $err.Exception.Message | Should -Be 'GLPI API error 404 ERROR_ITEM_NOT_FOUND: Not found'
        $err.FullyQualifiedErrorId | Should -Match 'GlpiApi.404'
    }
    It 'never writes the token to the verbose output' {
        $v = Invoke-GlpiToolsRequest -Method Get -Resource '/Assistance/Ticket/2' -Verbose 4>&1 | Out-String
        $v | Should -Not -Match 'AT1'
        $v | Should -Not -Match 'csecret'
    }
}
