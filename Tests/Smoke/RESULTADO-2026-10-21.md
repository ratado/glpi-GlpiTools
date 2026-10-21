# Resultado do smoke contra o glpi12 (2026-10-21)

Escrita: sim (registros com prefixo GLPITOOLS-SMOKE, removidos ao final). Sem tokens nem segredos.

| Modo | Passo | Cmdlet | Resultado | Observação |
|---|---|---|---|---|
| v1 | Configuração | `Set-GlpiToolsConfig` | ok | versão v1 |
| v1 | Sessão | `Set-GlpiToolsInitSession` | ok | token obtido |
| v1 | Entidades do usuário | `Get-GlpiToolsMyEntities` | ok | entidades: 1 |
| v1 | Chamado 2 (nomes) | `Get-GlpiToolsTickets -TicketId 2` | ok | id=2 properties=37 |
| v1 | Chamado 2 (-Raw) | `Get-GlpiToolsTickets -TicketId 2 -Raw` | ok | id=2 properties=37 |
| v1 | Chamados por nome | `Get-GlpiToolsTickets -TicketName` | ok | chamados: 4 |
| v1 | Computadores | `Get-GlpiToolsComputers -All` | ok | computadores: 7 |
| v1 | Dropdown (localizações) | `Get-GlpiToolsDropdownsLocations -All` | ok | localizações: 1220 |
| v1 | Usuários | `Get-GlpiToolsUsers -All` | ok | usuários: 11 |
| v1 | Criar chamado | `New-GlpiToolsTicket` | ok | id=42 |
| v1 | Acompanhamento | `Add-GlpiToolsTicketFollowup` | ok | chamado 42 |
| v1 | Atualizar chamado | `Update-GlpiToolsTicket` | ok | nome atualizado e relido |
| v1 | Remover chamado (purge) | `Remove-GlpiToolsItems` | ok | chamado 42 |
| v1 | Chamado removido | `Get-GlpiToolsTickets -TicketId` | ok | não encontrado, como esperado |
| v1 | Encerrar sessão | `Set-GlpiToolsKillSession` | ok | sessão encerrada |
| v3Legacy | Configuração | `Set-GlpiToolsConfig` | ok | versão v3 |
| v3Legacy | Sessão | `Set-GlpiToolsInitSession` | ok | token obtido |
| v3Legacy | Entidades do usuário | `Get-GlpiToolsMyEntities` | ok | entidades: 1 |
| v3Legacy | Chamado 2 (nomes) | `Get-GlpiToolsTickets -TicketId 2` | ok | id=2 properties=35 |
| v3Legacy | Chamado 2 (-Raw) | `Get-GlpiToolsTickets -TicketId 2 -Raw` | ok | id=2 properties=35 |
| v3Legacy | Chamados por nome | `Get-GlpiToolsTickets -TicketName` | ok | chamados: 4 |
| v3Legacy | Computadores | `Get-GlpiToolsComputers -All` | ok | computadores: 7 |
| v3Legacy | Dropdown (localizações) | `Get-GlpiToolsDropdownsLocations -All` | ok | localizações: 1220 |
| v3Legacy | Usuários | `Get-GlpiToolsUsers -All` | ok | usuários: 11 |
| v3Legacy | Criar chamado | `New-GlpiToolsTicket` | ok | id=43 |
| v3Legacy | Acompanhamento | `Add-GlpiToolsTicketFollowup` | ok | chamado 43 |
| v3Legacy | Atualizar chamado | `Update-GlpiToolsTicket` | ok | nome atualizado e relido |
| v3Legacy | Remover chamado (purge) | `Remove-GlpiToolsItems` | ok | chamado 43 |
| v3Legacy | Chamado removido | `Get-GlpiToolsTickets -TicketId` | ok | não encontrado, como esperado |
| v3Legacy | Encerrar sessão | `Set-GlpiToolsKillSession` | ok | sessão encerrada |
| v3Native | Configuração | `Set-GlpiToolsConfig` | ok | versão v3 |
| v3Native | Sessão | `Set-GlpiToolsInitSession` | ok | token obtido |
| v3Native | Entidades do usuário | `Get-GlpiToolsMyEntities` | ok | entidades: 1 |
| v3Native | Chamado 2 (nomes) | `Get-GlpiToolsTickets -TicketId 2` | ok | id=2 properties=44 |
| v3Native | Chamado 2 (-Raw) | `Get-GlpiToolsTickets -TicketId 2 -Raw` | ok | id=2 properties=44 |
| v3Native | Chamados por nome | `Get-GlpiToolsTickets -TicketName` | ok | chamados: 4 |
| v3Native | Computadores | `Get-GlpiToolsComputers -All` | ok | computadores: 7 |
| v3Native | Dropdown (localizações) | `Get-GlpiToolsDropdownsLocations -All` | ok | localizações: 1220 |
| v3Native | Usuários | `Get-GlpiToolsUsers -All` | ok | usuários: 11 |
| v3Native | Criar chamado | `New-GlpiToolsTicket` | ok | id=44 |
| v3Native | Acompanhamento | `Add-GlpiToolsTicketFollowup` | ok | chamado 44 |
| v3Native | Atualizar chamado | `Update-GlpiToolsTicket` | ok | nome atualizado e relido |
| v3Native | Remover chamado (purge) | `Remove-GlpiToolsItems` | ok | chamado 44 |
| v3Native | Chamado removido | `Get-GlpiToolsTickets -TicketId` | ok | não encontrado, como esperado |
| v3Native | Encerrar sessão | `Set-GlpiToolsKillSession` | ok | sessão encerrada |

Total: 45 passos, 45 ok, 0 falha(s), 0 ignorado(s).

## Ambiente e observações

- Instância `glpi12` (GLPI 12.0.0), PowerShell 7 em Linux, certificado autoassinado (`-SkipCertificateCheck`). Cada modo rodou em processo próprio, com `HOME` temporário (a configuração real não foi tocada).
- Roteiro: `Tests/Smoke/Invoke-GlpiToolsSmoke.ps1 -Write` (credenciais por variáveis de ambiente `GLPITOOLS_SMOKE_*`).
- Escrita: um chamado `GLPITOOLS-SMOKE` por modo (ids 42, 43 e 44), com acompanhamento e atualização, removido com purge ao final de cada modo. Conferido depois: nenhum chamado `GLPITOOLS-SMOKE` restou (fora e dentro da lixeira) e a contagem voltou a 26 chamados.
- Propriedades do chamado 2: v1 = 37, v3 Legacy = 35 (iguais com e sem `-Raw`), v3 Native = 44. A diferença entre v1 e v3 Legacy é a documentada em `spec/diferencas-v1-v3.md`: a v3 não tem `links`, `tickettemplates_id` e `time_to_own`, e acrescenta `team`.
- Contagens iguais nas três variantes: 1 entidade, 4 chamados por nome, 7 computadores, 1220 localizações, 11 usuários.
