BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    # files that are versioned with the tests and must never carry credentials
    $script:Recorded = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Fixtures'), (Join-Path $PSScriptRoot 'Smoke') -File -Recurse -ErrorAction SilentlyContinue)
}

Describe 'Smoke script' {
    It 'parses without syntax errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Smoke' 'Invoke-GlpiToolsSmoke.ps1'), [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
    It 'reads credentials only from environment variables' {
        $text = Get-Content (Join-Path $PSScriptRoot 'Smoke' 'Invoke-GlpiToolsSmoke.ps1') -Raw
        $text | Should -Not -Match '[0-9a-f]{40,}'
        $text | Should -Match 'GLPITOOLS_SMOKE_USERTOKEN'
    }
}

Describe 'Recorded fixtures and smoke reports' {
    It 'finds files to check' {
        $script:Recorded.Count | Should -BeGreaterThan 0
    }
    It 'carry no long hexadecimal token or secret' {
        foreach ($file in $script:Recorded) {
            $hits = Select-String -Path $file.FullName -Pattern '(?i)\b[0-9a-f]{40,}\b' -AllMatches
            @($hits).Count | Should -Be 0 -Because "$($file.Name) must not contain tokens or secrets"
        }
    }
    It 'carry no credential-looking field' {
        foreach ($file in $script:Recorded) {
            $hits = Select-String -Path $file.FullName -Pattern '(?i)"(app_token|user_token|client_secret|access_token|refresh_token|password)"\s*:\s*"[^"]{8,}"' -AllMatches
            @($hits).Count | Should -Be 0 -Because "$($file.Name) must not contain credential fields"
        }
    }
}
