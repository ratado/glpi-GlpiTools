# Changelog

All notable changes to this project are documented in this file.

## 2.0.0

### New

- The module now works with the REST API v3 of GLPI 12, besides the legacy REST API. You choose which one to use when you set up the module, and the commands, parameters and names stay the same.
- The REST API v3 is accessed with an OAuth client and the user name and password. The access is renewed automatically while you work, and it is closed when you end the session.
- Most of the commands now work with the REST API v3: tickets (including followups, solutions and tasks), changes, problems, recurring tickets, assets, users, groups, entities, management items, most dropdowns, plugins list, projects, reminders, the knowledge base and RSS feeds.
- With the REST API v3, the commands return the same properties and values as the legacy API by default, so existing scripts keep working. IDs come with `-Raw` and names without it, as before.
- New choice of output format for the REST API v3: `Legacy` (default) keeps the properties of the legacy API, and `Native` returns the data exactly as the REST API v3 sends it. Use `-OutputFormat` in `Set-GlpiToolsConfig`, or change it later with the new `Set-GlpiToolsOutputFormat`, without informing the credentials again.
- New `-SkipCertificateCheck` option in the configuration, for servers with a self-signed certificate. It is off by default and should be used only in test environments.
- Commands that have no equivalent in the REST API v3 stop with a clear message instead of failing. This applies to item logs, search options, password recovery, group members, linking an item to a ticket, the Apps Structures and FusionInventory plugins and some dropdowns for components, operating systems and networks.
- With the REST API v3, searching by a field that does not exist now stops with a message listing the valid fields, instead of returning every record.
- With the REST API v3, `Get-GlpiToolsDocuments -RawDocument` returns the file content as bytes, so PDFs and images are not damaged.
- With the REST API v3, a profile change goes back to the default entities of the new profile, as in the legacy API.
- Creating a ticket with the REST API v3 reports the error, and still returns the ticket, when the requester or technician cannot be added.
- New `examples` folder with step-by-step guides for installing, configuring and using the module, with separate examples for the REST API v3 and for the legacy API.

### Changes

- PowerShell 7 or later is now required. Windows PowerShell 5.1 is no longer supported.
- Reading the configuration is faster, because it is kept in memory until the file changes.
- Changing the configuration now closes the session that was open on the GLPI server.
- Creating a ticket with conflicting parameters (an item without its type, or an approval on something that is not a request) now stops only that command with a clear error, instead of closing the whole PowerShell session.
- With the legacy API, a failed request no longer writes the error text among the results of the command; the error is still raised, and the details are available with `-Verbose`.
- On Linux, the configuration file can now be read only by its owner.
- Existing configurations keep working as the legacy API, with no changes needed.

## 1.8.0

- Changed the session management, keeping it until the user requests to kill the session.
- Fixed the `Set-GlpiToolsChangeActiveEntities` function.
- Fixed the `Update-GlpiToolsTicket` function.
- Added `Get-GlpiToolsActiveEntities` to get the current active entities of the logged user.
- Added `Get-GlpiToolsMyEntities` to get all accessible entities of the logged user.
- Added `Get-GlpiToolsSessionToken` to get the current session token.
- Added `Set-GlpiToolsSessionToken` to set the current session token.
