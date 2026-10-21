# GlpiTools - Install and configure
#
# This file shows how to install the module, connect it to your GLPI server and
# start/end a session. Read it first, then go to 02-rest-api-v3.ps1 or 03-legacy-api.ps1.
#
# Do not run the whole file at once: copy the blocks you need and run them one by one.
# The two lines below stop an accidental full run. Remove them if you know what you are doing.
Write-Warning 'Run the blocks of this file one by one instead of the whole file.'
return

# ---------------------------------------------------------------------------
# 1. Requirements
# ---------------------------------------------------------------------------
# - PowerShell 7 or later (Windows, Linux or macOS). Windows PowerShell 5.1 is not supported.
# - A GLPI server with the API you want to use turned on:
#     REST API v3  -> GLPI 12, with an OAuth client (recommended for GLPI 12)
#     Legacy API   -> any GLPI with "Enable Rest API" turned on, with app and user tokens

# ---------------------------------------------------------------------------
# 2. Install the module
# ---------------------------------------------------------------------------
# From the PowerShell Gallery:
Install-Module -Name GlpiTools -Scope CurrentUser

# Or by hand: copy the module folder (named "GlpiTools") to one of the folders listed here:
$env:PSModulePath -split [IO.Path]::PathSeparator

# Load the module. Put this line at the top of every script that uses it.
Import-Module GlpiTools

# Windows only: if PowerShell refuses to load the module because of the execution policy,
# relax the policy for the current window only and import again.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Import-Module GlpiTools

# ---------------------------------------------------------------------------
# 3. Configure the connection (once)
# ---------------------------------------------------------------------------
# The address and the credentials are saved on your computer, protected, and reused by
# every later session. Run only the option that matches your server.

# Option A - REST API v3 (GLPI 12)
# Create an OAuth client in GLPI (Setup > OAuth clients) with the Password grant and the "api" scope.
# Use the address of the site, with nothing after it.
$Site = 'https://glpi.example.com'
Set-GlpiToolsConfig -ApiVersion v3 -PathToGlpi $Site `
    -ClientId 'your-client-id' -ClientSecret 'your-client-secret' `
    -Username 'your-glpi-user' -Password 'your-glpi-password'

# Option B - Legacy REST API
# App token: Setup > General > API. User token: your user > Remote access keys.
# Use the address of the legacy endpoint, which ends with /apirest.php.
Set-GlpiToolsConfig -AppToken 'your-app-token' -UserToken 'your-user-token' `
    -PathToGlpi 'https://glpi.example.com/apirest.php'

# Test servers with a self-signed certificate: add -SkipCertificateCheck to Set-GlpiToolsConfig.
# Never use it in production, because it turns off the protection against fake servers.

# Check what is saved. Careful: the output shows passwords and secrets, do not share it.
Get-GlpiToolsConfig

# ---------------------------------------------------------------------------
# 4. Choose the shape of the results (REST API v3 only)
# ---------------------------------------------------------------------------
# Legacy (default): same property names as the legacy API, so old scripts keep working.
# Native: the data exactly as the REST API v3 sends it, with related items as objects.
Set-GlpiToolsOutputFormat -Format Native
Set-GlpiToolsOutputFormat -Format Legacy

# ---------------------------------------------------------------------------
# 5. The usual flow: start a session, work, end the session
# ---------------------------------------------------------------------------
# Start the session. The output is the session token, which you normally do not need.
Set-GlpiToolsInitSession | Out-Null

# ... run your commands here ...
Get-GlpiToolsActiveProfile

# End the session when you are done.
Set-GlpiToolsKillSession | Out-Null

# ---------------------------------------------------------------------------
# 6. Discover the commands
# ---------------------------------------------------------------------------
# List every command of the module.
Get-Command -Module GlpiTools

# Read the help of a command, with its parameters and examples.
Get-Help New-GlpiToolsTicket -Full
