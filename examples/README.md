# GlpiTools examples

Ready-to-use examples of the most common tasks: reading, creating and updating tickets, follow-ups, solutions, approvals and searches.

Each file is a PowerShell script written to be read and run **block by block**. Copy the blocks you need into your session. The whole file does not run at once on purpose: it stops at the top with a warning, so you do not create records by accident.

## Which file do I read?

| File | Read it when |
| --- | --- |
| [01-install-and-configure.ps1](01-install-and-configure.ps1) | You are starting. Install the module, connect it to GLPI and learn the usual flow (start a session, work, end the session). |
| [02-rest-api-v3.ps1](02-rest-api-v3.ps1) | Your GLPI is version 12 and you use the REST API v3 (OAuth client, user name and password). |
| [03-legacy-api.ps1](03-legacy-api.ps1) | You use the legacy REST API (app token and user token), or you need a task that the REST API v3 does not offer: link tickets, validations, approving a solution, the satisfaction survey, actors through the generic commands, item history. |

## Before you start

- Use PowerShell 7 or later.
- Change the values at the top of each example (ticket, category, user and entity IDs). The IDs in the files are only illustrations.
- Prefer a test server while you learn. Creating, updating and removing records changes real data.
- The credentials you save with `Set-GlpiToolsConfig` stay on your computer, protected. `Get-GlpiToolsConfig` shows them in plain text, so do not paste its output in chats or tickets.

## Good to know

- **Active entity.** After `Set-GlpiToolsChangeActiveEntities`, the commands only see the items of the active entities. If a ticket seems to disappear, go back with `Set-GlpiToolsChangeActiveEntities -EntitiesId 0 -IsRecursive`.
- **Categories with a dedicated form.** On the legacy API, a category tied to a form of a GLPI plugin refuses new tickets. Use a category without a form.
- **Approving a validation.** GLPI records the answer only when it comes from the user asked to approve. Run that step with the tokens of that user.
- **Satisfaction survey.** It is created only when a ticket is closed in an entity with the survey turned on at a rate above 0%, and only the requester can answer it. To answer, use the ticket ID as the survey ID.

## Tested

The examples were run against GLPI 12.0.0 with both APIs. Plugin-specific tasks are described but not run, because they depend on your server.
