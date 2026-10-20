# Changelog

All notable changes to this project are documented in this file.

## Unreleased

- `Set-GlpiToolsConfig` can now be set up for the GLPI 12 REST API v3, using an OAuth client with the user name and password.
- Added the `-SkipCertificateCheck` option to the configuration, to be used only with self-signed certificates.
- Starting a session with the REST API v3 now gets an access token from GLPI and renews it automatically before it expires.
- With the REST API v3 configured, the generic commands (`Get-`, `Add-`, `Update-` and `Remove-GlpiToolsItems`, `Search-GlpiToolsItems`), the entity and profile commands, the system settings and the documents list now work. Commands with no equivalent in the API v3 stop with a clear message.
- With the REST API v3 configured, the ticket commands work: listing, creating and updating tickets, and adding followups, solutions and tasks. Linking an item to a ticket, `-DisableNotification` and some `-Parameter` options are not available in the API v3 and stop with a clear message.
- With the REST API v3 configured, `Get-GlpiToolsTickets` returns the same properties and values as the legacy API (IDs with `-Raw`, names without it).
- With the REST API v3 configured, `Get-GlpiToolsChanges`, `Get-GlpiToolsProblems` and `Get-GlpiToolsRecurrentTickets` work and return the same properties as the legacy API.
- With the REST API v3 configured, the asset commands (computers, monitors, network equipment, peripherals, phones, printers, racks, enclosures, PDUs, software, cartridges and consumables) work and return the same properties as the legacy API. `Get-GlpiToolsSoftwareVersions`, `Get-GlpiToolsComputerSoftwareVersions` and `Get-GlpiToolsFinancialAndAdministrativeInformations` have new optional parameters (`-SoftwareId`, `-ComputerId`, `-ItemType` and `-ItemId`) that are required only with the API v3.
- With the REST API v3 configured, `Get-GlpiToolsEntities`, `Get-GlpiToolsGroups` and `Get-GlpiToolsUsers` work and return the same properties as the legacy API. `Get-GlpiToolsGroupsMembers` is not available in the API v3 and stops with a clear message.
- With the REST API v3 configured, the management commands (budgets, certificates, contacts, contracts, data centers, lines, software licenses and suppliers) work and return the same properties as the legacy API.
- Changing the configuration now closes the session that was open on the GLPI server.
- The configuration file is now readable only by its owner on Linux.
- Existing configurations keep working as the legacy API, with no changes needed.

## 1.8.0

- Changed the session management, keeping it until the user requests to kill the session.
- Fixed the `Set-GlpiToolsChangeActiveEntities` function.
- Fixed the `Update-GlpiToolsTicket` function.
- Added `Get-GlpiToolsActiveEntities` to get the current active entities of the logged user.
- Added `Get-GlpiToolsMyEntities` to get all accessible entities of the logged user.
- Added `Get-GlpiToolsSessionToken` to get the current session token.
- Added `Set-GlpiToolsSessionToken` to set the current session token.
