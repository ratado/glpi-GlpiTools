<#
.SYNOPSIS
    Smoke test of the module against a live GLPI instance, for API v1 and API v3 (Legacy and Native output).
.DESCRIPTION
    Runs the read steps (and, with -Write, the ticket write cycle) of every mode and writes a Markdown report
    without tokens or secrets. Each mode runs in its own pwsh process with a temporary HOME, so the real
    configuration file is never touched. Credentials come from environment variables, never from parameters:
      GLPITOOLS_SMOKE_URL          site URL (v3) ; the legacy API URL is built from it
      GLPITOOLS_SMOKE_APPTOKEN     app_token of the legacy API
      GLPITOOLS_SMOKE_USERTOKEN    user_token of the legacy API
      GLPITOOLS_SMOKE_CLIENTID     OAuth client id (password grant)
      GLPITOOLS_SMOKE_CLIENTSECRET OAuth client secret
      GLPITOOLS_SMOKE_USERNAME     GLPI user for the password grant
      GLPITOOLS_SMOKE_PASSWORD     password of that user
.PARAMETER Mode
    v1, v3Legacy, v3Native or All (default). A single mode is run in the current process.
.PARAMETER Write
    Also runs the write cycle: New-GlpiToolsTicket, Add-GlpiToolsTicketFollowup, Update-GlpiToolsTicket and the
    purge of the test ticket. Test records are named with the GLPITOOLS-SMOKE prefix.
.PARAMETER SkipCertificateCheck
    Ignores TLS certificate validation. Off by default; only for a lab instance with a self-signed certificate.
.PARAMETER ReportPath
    Markdown report path. Default: Tests/Smoke/RESULTADO-<date>.md.
.EXAMPLE
    PS C:\> ./Tests/Smoke/Invoke-GlpiToolsSmoke.ps1 -Write -SkipCertificateCheck
.NOTES
    Writes only with -Write. The test ticket is removed even when a step fails.
#>
[CmdletBinding()]
param (
    [ValidateSet('All', 'v1', 'v3Legacy', 'v3Native')]
    [string]$Mode = 'All',
    [switch]$Write,
    [switch]$SkipCertificateCheck,
    [string]$ReportPath,
    [string]$ResultJson
)

$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Prefix = 'GLPITOOLS-SMOKE'

# Runs one child process per mode and aggregates the results into the report
if ($Mode -eq 'All') {
    if (-not $ReportPath) { $ReportPath = Join-Path $PSScriptRoot ("RESULTADO-{0}.md" -f (Get-Date -Format 'yyyy-MM-dd')) }
    $All = @()
    foreach ($m in 'v1', 'v3Legacy', 'v3Native') {
        $tmp = [System.IO.Path]::GetTempFileName()
        $childArgs = @('-NoProfile', '-File', $PSCommandPath, '-Mode', $m, '-ResultJson', $tmp)
        if ($Write) { $childArgs += '-Write' }
        if ($SkipCertificateCheck) { $childArgs += '-SkipCertificateCheck' }
        & pwsh @childArgs | Out-Host
        $ChildExit = $LASTEXITCODE
        $Raw = Get-Content $tmp -Raw
        Remove-Item $tmp -Force
        # a child that died before writing its results is a failure, not an empty success
        if (-not $Raw) {
            $All += [pscustomobject]@{ Mode = $m; Step = 'Execução'; Cmdlet = 'pwsh'; Result = 'falha'; Note = "processo encerrado sem resultados (código $ChildExit)" }
            continue
        }
        $All += @($Raw | ConvertFrom-Json)
    }
    $Lines = @(
        "# Resultado do smoke contra o glpi12 ($(Get-Date -Format 'yyyy-MM-dd'))",
        '',
        "Escrita: $(if ($Write) { 'sim (registros com prefixo ' + $Prefix + ', removidos ao final)' } else { 'não (somente leitura)' }). Sem tokens nem segredos.",
        '',
        '| Modo | Passo | Cmdlet | Resultado | Observação |',
        '|---|---|---|---|---|'
    )
    foreach ($r in $All) { $Lines += "| $($r.Mode) | $($r.Step) | ``$($r.Cmdlet)`` | $($r.Result) | $($r.Note -replace '\|', '/') |" }
    $Fail = @($All | Where-Object Result -eq 'falha').Count
    $Lines += ''
    $Lines += "Total: $($All.Count) passos, $(@($All | Where-Object Result -eq 'ok').Count) ok, $Fail falha(s), $(@($All | Where-Object Result -eq 'ignorado').Count) ignorado(s)."
    $Lines | Set-Content -Path $ReportPath -Encoding UTF8
    Write-Host "Relatório: $ReportPath"
    exit $(if ($Fail) { 1 } else { 0 })
}

# Single mode: isolated HOME so the real configuration stays intact
foreach ($v in 'URL', 'APPTOKEN', 'USERTOKEN', 'CLIENTID', 'CLIENTSECRET', 'USERNAME', 'PASSWORD') {
    if (-not (Get-Item "Env:GLPITOOLS_SMOKE_$v" -ErrorAction SilentlyContinue)) { throw "Missing environment variable GLPITOOLS_SMOKE_$v" }
}
$TempHome = Join-Path ([System.IO.Path]::GetTempPath()) ("glpitools-smoke-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $TempHome | Out-Null
$env:HOME = $TempHome
$env:LOCALAPPDATA = $TempHome
Import-Module (Join-Path $Root 'GlpiTools.psd1') -Force -WarningAction SilentlyContinue

$Results = [System.Collections.Generic.List[object]]::new()
$Site = $env:GLPITOOLS_SMOKE_URL.TrimEnd('/')

<#
.SYNOPSIS
    Runs one smoke step, never aborts the run, and records the outcome.
.PARAMETER Step
    Readable name of the step.
.PARAMETER Cmdlet
    Command exercised by the step.
.PARAMETER Script
    Code of the step; its output becomes the note of the report.
#>
function Invoke-Step {
    param ([string]$Step, [string]$Cmdlet, [scriptblock]$Script)
    try {
        $note = & $Script
        $res = 'ok'
    } catch {
        $note = $_.Exception.Message
        $res = 'falha'
    }
    $Results.Add([pscustomobject]@{ Mode = $Mode; Step = $Step; Cmdlet = $Cmdlet; Result = $res; Note = "$note" })
    Write-Host ("[{0}] {1} {2}: {3}" -f $Mode, $res, $Step, $note)
}

<#
.SYNOPSIS
    Fails when a read returned no data and describes the amount otherwise.
.PARAMETER Value
    Objects returned by the command.
.PARAMETER What
    Name of what was read, used in the message.
#>
function Assert-Data {
    param ($Value, [string]$What)
    $n = @($Value | Where-Object { $null -ne $_ }).Count
    if ($n -lt 1) { throw "$What returned no data" }
    "$What`: $n"
}

$TicketId = $null
try {
    Invoke-Step 'Configuração' 'Set-GlpiToolsConfig' {
        if ($Mode -eq 'v1') {
            Set-GlpiToolsConfig -AppToken $env:GLPITOOLS_SMOKE_APPTOKEN -UserToken $env:GLPITOOLS_SMOKE_USERTOKEN -PathToGlpi "$Site/apirest.php" -SkipCertificateCheck:$SkipCertificateCheck
        } else {
            Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi $Site -ClientId $env:GLPITOOLS_SMOKE_CLIENTID -ClientSecret $env:GLPITOOLS_SMOKE_CLIENTSECRET `
                -Username $env:GLPITOOLS_SMOKE_USERNAME -Password $env:GLPITOOLS_SMOKE_PASSWORD -OutputFormat $(if ($Mode -eq 'v3Native') { 'Native' } else { 'Legacy' }) -SkipCertificateCheck:$SkipCertificateCheck
        }
        "versão $((Get-GlpiToolsConfig).ApiVersion)"
    }
    Invoke-Step 'Sessão' 'Set-GlpiToolsInitSession' { Set-GlpiToolsInitSession | Out-Null; if (-not (Get-GlpiToolsSessionToken)) { throw 'no session token' }; 'token obtido' }

    # Read steps
    Invoke-Step 'Entidades do usuário' 'Get-GlpiToolsMyEntities' { Assert-Data (Get-GlpiToolsMyEntities) 'entidades' }
    Invoke-Step 'Chamado 2 (nomes)' 'Get-GlpiToolsTickets -TicketId 2' {
        $t = Get-GlpiToolsTickets -TicketId 2
        if (-not $t) { throw 'ticket 2 not returned' }
        "id=$($t.id) properties=$(@($t.PSObject.Properties).Count)"
    }
    Invoke-Step 'Chamado 2 (-Raw)' 'Get-GlpiToolsTickets -TicketId 2 -Raw' {
        $t = Get-GlpiToolsTickets -TicketId 2 -Raw
        if (-not $t) { throw 'ticket 2 not returned' }
        "id=$($t.id) properties=$(@($t.PSObject.Properties).Count)"
    }
    Invoke-Step 'Chamados por nome' 'Get-GlpiToolsTickets -TicketName' {
        $name = (Get-GlpiToolsTickets -TicketId 2 -Raw).name
        if (-not $name) { throw 'ticket 2 has no name' }
        Assert-Data (Get-GlpiToolsTickets -TicketName $name -SearchInTrash No) 'chamados'
    }
    Invoke-Step 'Computadores' 'Get-GlpiToolsComputers -All' { Assert-Data (Get-GlpiToolsComputers -All) 'computadores' }
    Invoke-Step 'Dropdown (localizações)' 'Get-GlpiToolsDropdownsLocations -All' { Assert-Data (Get-GlpiToolsDropdownsLocations -All) 'localizações' }
    Invoke-Step 'Usuários' 'Get-GlpiToolsUsers -All' { Assert-Data (Get-GlpiToolsUsers -All) 'usuários' }

    # Write cycle on a test ticket
    if ($Write) {
        Invoke-Step 'Criar chamado' 'New-GlpiToolsTicket' {
            $r = New-GlpiToolsTicket -name "$Prefix $Mode" -content "$Prefix criado pelo smoke ($Mode)"
            $script:TicketId = @($r)[0].id
            if (-not $script:TicketId) { throw 'no id returned' }
            "id=$($script:TicketId)"
        }
        if ($TicketId) {
            Invoke-Step 'Acompanhamento' 'Add-GlpiToolsTicketFollowup' { Add-GlpiToolsTicketFollowup -ticket_id $TicketId -content "$Prefix acompanhamento" | Out-Null; "chamado $TicketId" }
            Invoke-Step 'Atualizar chamado' 'Update-GlpiToolsTicket' {
                Update-GlpiToolsTicket -ticket_id $TicketId -name "$Prefix $Mode atualizado" | Out-Null
                $t = Get-GlpiToolsTickets -TicketId $TicketId -Raw
                if ($t.name -notlike '*atualizado') { throw "name not updated: $($t.name)" }
                'nome atualizado e relido'
            }
        }
    }
} finally {
    # The test ticket is purged even when a step failed
    if ($TicketId) {
        Invoke-Step 'Remover chamado (purge)' 'Remove-GlpiToolsItems' { Remove-GlpiToolsItems -RemoveFrom Ticket -ItemId $TicketId -Purge | Out-Null; "chamado $TicketId" }
        Invoke-Step 'Chamado removido' 'Get-GlpiToolsTickets -TicketId' {
            if (Get-GlpiToolsTickets -TicketId $TicketId -Raw -ErrorAction SilentlyContinue) { throw "ticket $TicketId still exists" }
            'não encontrado, como esperado'
        }
    }
    Invoke-Step 'Encerrar sessão' 'Set-GlpiToolsKillSession' { Set-GlpiToolsKillSession; 'sessão encerrada' }
    Remove-Item -Path $TempHome -Recurse -Force -ErrorAction SilentlyContinue
    if ($ResultJson) { $Results | ConvertTo-Json -Depth 3 -AsArray | Set-Content -Path $ResultJson -Encoding UTF8 }
}
