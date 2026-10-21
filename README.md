# GlpiTools
<div align="center">
<!-- Discord -->
  <a href="https://discord.gg/u4YdyVb">
    <img src="https://img.shields.io/discord/235574673155293194.svg?style=flat&label=Discord&logo=discord"
      alt="Discord - Chat" title="Discord - Chat" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
  <!-- Slack -->
  <a href="https://join.slack.com/t/powershell-poland/shared_invite/enQtNDYxNjYzNjYwMjcyLTFmZGU1N2IyODY3ZDI0ZmJjYjM3OTYwMjkwYjQ5ZTU1MzM1ZTIwYjRmOGFhM2M3MjE1Zjk4NDY4MDRjNTBlOWQ">
    <img src="https://img.shields.io/badge/chat-on%20slack-orange.svg?style=flat&logo=slack"
      alt="Slack - Chat" title="Slack - Chat" />
  </a>&nbsp;&nbsp;&nbsp;&nbsp;
</div>

## About

GlpiTools is a PowerShell module that lets you work with GLPI from the command line: list, create and update tickets, computers, users, entities and many other items, using simple commands.

This is a fork of https://github.com/wpietrzakpl/GlpiTools with some improvements.

Version 2.0.0 works with the two ways GLPI offers to be used by programs:

 * the **legacy REST API** that GLPI has always offered, with access tokens;
 * the **REST API v3** of GLPI 12, with an OAuth client and your GLPI user name and password.

You choose one of them when you set up the module. The commands and their parameters are the same in both.

## What you need

 * PowerShell 7 or later, on Windows, Linux or macOS. Windows PowerShell 5.1 is no longer supported.
 * A GLPI server with the API you want to use turned on (see below).

## Installing

Install from the PowerShell Gallery:

```powershell
Install-Module -Name GlpiTools
```

Or install by hand:

 * Download the module from GitHub.
 * Unzip it, remove the branch name from the folder name and copy the folder to one of your module folders. To see them, run `$env:PSModulePath -split [IO.Path]::PathSeparator`.
 * Load it with `Import-Module GlpiTools`.

## Setting up

Run `Set-GlpiToolsConfig` once. It saves the address and the credentials on your computer, protected, and the module uses them from then on. Then start a session with `Set-GlpiToolsInitSession` and end it with `Set-GlpiToolsKillSession` when you are done.

### Option 1: legacy REST API

In GLPI:

 * Turn on the API: Setup -> General -> API -> Enable Rest API.
 * Get the application token (app_token): Setup -> General -> API, in the API client, regenerate and copy the application token.
 * Get your user token: Administration -> Users -> (your user) -> Remote access keys, regenerate and copy the API token. The user must have permission to do what you want to do with the API.

In PowerShell:

```powershell
Set-GlpiToolsConfig -AppToken 'your-app-token' -UserToken 'your-user-token' -PathToGlpi 'https://glpi.example.com/apirest.php'
```

### Option 2: REST API v3 (GLPI 12)

In GLPI, as an administrator, create an OAuth client for the module:

 * Go to Setup -> OAuth clients and add a client.
 * Allow the **Password** grant and the **api** scope.
 * Save it and copy the client ID and the client secret.

In PowerShell:

```powershell
Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi 'https://glpi.example.com' `
    -ClientId 'your-client-id' -ClientSecret 'your-client-secret' `
    -Username 'your-glpi-user' -Password 'your-glpi-password'
```

Use the address of the GLPI site, without anything after it. Prefer `https://`: with `http://` the user name, the password and the secret travel without protection, and the module warns you.

If your server uses a self-signed certificate, add `-SkipCertificateCheck`. Use it only in test environments, because it turns off the check that protects you from fake servers.

Configurations saved by older versions keep working as the legacy API, with no changes.

### Choosing how the data comes back (REST API v3 only)

 * `Legacy` (the default): the commands return the same properties and values as before, such as `entities_id`, so your scripts keep working. With `-Raw` you get IDs, and without it you get names.
 * `Native`: the commands return the data exactly as the REST API v3 sends it, with related items as objects. `-Raw` is accepted and has no effect.

Choose it with `-OutputFormat` in `Set-GlpiToolsConfig`, or change it at any time with:

```powershell
Set-GlpiToolsOutputFormat -Format Native
```

Session, entities, profiles and system settings commands return the same shape in both formats.

## Good to know

 * `Get-GlpiToolsConfig` shows the saved credentials, including the password and the client secret. Do not paste its output in chats, logs or tickets.
 * With the REST API v3, a command with no parameters, such as `Get-GlpiToolsTickets`, lists everything. With the legacy API it returns nothing.
 * With the REST API v3, a user appears with the login name instead of the full name, and the list of hierarchical items such as locations shows only the main fields. Reading one item by its ID returns all fields.
 * Some details that the REST API v3 does not provide are left out of the results (for example a few fields of tickets and users), and tickets get an extra `team` property with the people involved.
 * Searching by a field that does not exist stops with a message listing the valid fields.

### Commands that do not exist in the REST API v3

With the REST API v3 these commands stop with a clear message. Use the legacy API if you need them:

 * `Get-GlpiToolsItemLogs` and `Get-GlpiToolsListSearchOptions`;
 * `Set-GlpiToolsPasswordReset` and `Set-GlpiToolsResetPasswordRequest`;
 * `Get-GlpiToolsGroupsMembers` and `Add-GlpiToolsTicketItem`;
 * the Apps Structures and FusionInventory plugin commands;
 * the `Get-GlpiToolsDropdowns*` commands for components (cases, memory, drives and others), operating systems, VLANs, IP and network names, outlets, line operators, PDU and rack models and types, sensor and SIM card types, project states and task templates, software and knowledge base categories.

A few options of some commands are also unavailable, such as `-DisableNotification` when creating a ticket, and they stop with a message.

### Small differences in session commands (REST API v3)

 * Searching with a numeric field only understands the name and the ID; for other fields use the field name.
 * The active entities are built from the session information that GLPI sends.
 * `Get-GlpiToolsMyEntities` lists the entities of your profiles, or the whole tree with `-IsRecursive`.
 * `Get-GlpiToolsSystemConfig` leaves out settings that look like passwords, secrets, tokens or keys.
 * Changing the entity or the profile applies only to this module, and changing the profile goes back to the default entities of the new profile.
 * `-ExtraParameter` of `Get-GlpiToolsItems` and `Get-GlpiToolsItemLogs` is not available.

## Examples

The [examples](examples/README.md) folder has step-by-step guides with ready-to-use commands: installing and configuring the module, and the most common tasks (tickets, follow-ups, solutions, approvals and searches) for the REST API v3 and for the legacy API. They were tested against GLPI 12.

## Available commands

```powershell
Get-Module GlpiTools | Select-Object -ExpandProperty ExportedCommands
```

## What changed

See the [CHANGELOG](CHANGELOG.md).

## License

GlpiTools is free software, distributed under the GNU General Public License version 3 (see the `LICENSE` file). The module was created by Wojciech Pietrzak, and this version is maintained by André Proto.
