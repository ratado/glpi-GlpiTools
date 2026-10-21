# GlpiTools - Examples for the REST API v3 (GLPI 12)
#
# Everything here works after you configured the module with -ApiVersion v3
# (see 01-install-and-configure.ps1). The IDs below are only examples: change the
# variables to values that exist on your server.
#
# Do not run the whole file at once: copy the blocks you need and run them one by one.
# The two lines below stop an accidental full run. Remove them if you know what you are doing.
Write-Warning 'Run the blocks of this file one by one instead of the whole file.'
return

# Values used by the examples. Change them in one place.
$TicketId   = 1     # an existing ticket
$CategoryId = 3     # an ITIL category (Setup > Dropdowns > Assistance > ITIL categories)
$RequesterId = 2    # ID of the user who asks for the ticket
$TechnicianId = 4   # ID of the user who will work on the ticket
$EntityId   = 1     # an entity you can access
$ProfileId  = 4     # a profile you can use

# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------
# Start the session. Do it once, before the other commands.
Set-GlpiToolsInitSession | Out-Null

# End the session when you are done.
Set-GlpiToolsKillSession | Out-Null

# ---------------------------------------------------------------------------
# Profiles and entities
# ---------------------------------------------------------------------------
# Show the profile you are using now.
Get-GlpiToolsActiveProfile

# List the profiles available to you.
Get-GlpiToolsMyProfiles

# Show the active entities.
Get-GlpiToolsActiveEntities

# List the entities available to you. -IsRecursive returns the whole tree.
Get-GlpiToolsMyEntities -IsRecursive

# Change the profile. On the REST API v3 the change applies only to this module,
# not to your browser session, and the active entities go back to the default of the new profile.
Set-GlpiToolsChangeActiveProfile -ProfilesId $ProfileId

# Change the active entity. -IsRecursive includes the child entities.
# From now on the commands only see (and change) items of the active entities, so a ticket of
# another entity looks like it does not exist. Go back to the root entity when you are done.
Set-GlpiToolsChangeActiveEntities -EntitiesId $EntityId -IsRecursive
Set-GlpiToolsChangeActiveEntities -EntitiesId 0 -IsRecursive

# ---------------------------------------------------------------------------
# Read tickets
# ---------------------------------------------------------------------------
# Get one ticket. Related items, such as the entity, come as names.
Get-GlpiToolsTickets -TicketId $TicketId

# Get the same ticket with the raw values (IDs instead of names).
Get-GlpiToolsTickets -TicketId $TicketId -Raw

# Get one ticket with its dropdown values expanded.
# On the REST API v3 -Parameter accepts only ExpandDropdowns and WithDocuments.
Get-GlpiToolsTickets -TicketId $TicketId -Parameter ExpandDropdowns

# List all tickets that are not in the trash. On the REST API v3 a command with no
# filter lists everything (on the legacy API it returns nothing).
Get-GlpiToolsTickets

# The ticket has a "team" property with the people involved and their roles.
(Get-GlpiToolsTickets -TicketId $TicketId).team

# ---------------------------------------------------------------------------
# Create a ticket
# ---------------------------------------------------------------------------
# -Type accepts Incident or Request (or 1 and 2). -urgency, -impact and -priority accept
# "Very low", "Low", "Medium", "High", "Very High" (or 1 to 5). The command returns the new ID.
$NewTicket = New-GlpiToolsTicket `
    -name 'Title of a ticket created through the API' `
    -content '<p>Description in <b>HTML</b></p><table><tr><td>A table</td><td>12011</td></tr></table>' `
    -itilcategories_id $CategoryId `
    -Type Request `
    -requester_id $RequesterId
$NewTicket.id

# The same ticket with a hashtable. Each key is a parameter name of the command.
$form = @{
    name              = 'Title of a ticket created through the API'
    content           = '<p>Description in <b>HTML</b></p>'
    itilcategories_id = $CategoryId
    Type              = 'Incident'
    urgency           = 'High'
    requester_id      = $RequesterId
}
New-GlpiToolsTicket @form

# ---------------------------------------------------------------------------
# Clone a ticket
# ---------------------------------------------------------------------------
# Read the ticket and create a new one that reuses its data, changing only what you need.
$source = Get-GlpiToolsTickets -TicketId $TicketId -Raw
New-GlpiToolsTicket `
    -name "$($source.name) (copy)" `
    -content $source.content `
    -itilcategories_id $source.itilcategories_id `
    -Type Request

# ---------------------------------------------------------------------------
# Update a ticket
# ---------------------------------------------------------------------------
# Change only the fields you pass. -status is the numeric status of GLPI
# (1 New, 2 Processing (assigned), 3 Processing (planned), 4 Pending, 5 Solved, 6 Closed).
Update-GlpiToolsTicket -ticket_id $TicketId -urgency High

# Several fields at once, with a hashtable.
$form = @{
    ticket_id         = $TicketId
    itilcategories_id = $CategoryId
    urgency           = 'Medium'
    status            = 3
}
Update-GlpiToolsTicket @form

# Set or add the people of the ticket. They are added to the team with the role below.
#   -requester_id : the user becomes a requester
#   -technician_id: the user becomes assigned to the ticket
Update-GlpiToolsTicket -ticket_id $TicketId -technician_id $TechnicianId
Update-GlpiToolsTicket -ticket_id $TicketId -requester_id $RequesterId

# ---------------------------------------------------------------------------
# Follow-ups and solutions
# ---------------------------------------------------------------------------
# Add a follow-up to a ticket. -IsPrivate hides it from the requester.
Add-GlpiToolsTicketFollowup -ticket_id $TicketId -content '<p>Follow-up in <b>HTML</b></p>'
Add-GlpiToolsTicketFollowup -ticket_id $TicketId -content '<p>Internal note</p>' -IsPrivate

# Add a solution. -solutiontype_id is the ID of the solution type (the default is 2).
Add-GlpiToolsTicketSolution -ticket_id $TicketId -content '<p>Solution in <b>HTML</b></p>' -solutiontype_id 2

# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
# Search tickets whose title contains a text. On the REST API v3 -SearchField accepts
# 1 (name), 2 (ID) or the name of a property, such as status. Other numbers are not accepted.
Search-GlpiToolsItems -SearchFor Ticket -SearchField name -SearchType contains -SearchValue 'API'

# Two conditions: title containing "API" AND ID equal to a value.
Search-GlpiToolsItems -SearchFor Ticket -SearchField 1, 2 -SearchType contains, equals `
    -SearchValue 'API', $TicketId -SearchLink AND

# ---------------------------------------------------------------------------
# Any other item type
# ---------------------------------------------------------------------------
# Get-GlpiToolsItems, Add-GlpiToolsItems and Update-GlpiToolsItems work with the item types
# that exist on the REST API v3 (Computer, Monitor, User, Group, Location and many others).
# With several results the values come raw (IDs).

# List items filtered by text. Use ^ and $ to match the whole value.
Get-GlpiToolsItems -ItemType Ticket -SearchText @{ name = 'API' }
Get-GlpiToolsItems -ItemType Computer -SearchText @{ name = '^PC-001$' }

# Create an item.
Add-GlpiToolsItems -AddTo Computer -HashtableToAdd @{ name = 'PC-001'; comment = 'Created through the API' }

# Update an item by ID.
Update-GlpiToolsItems -UpdateTo Computer -ItemId 9 -ItemsHashtableWithoutId @{ comment = 'Updated through the API' }

# ---------------------------------------------------------------------------
# Not available on the REST API v3
# ---------------------------------------------------------------------------
# These tasks have no equivalent on the REST API v3. The commands stop with a clear message
# ("... is not supported by the GLPI API v3"). To do them, configure the legacy API
# (Set-GlpiToolsConfig with tokens) and use the matching examples in 03-legacy-api.ps1.
#   - Link tickets together (Ticket_Ticket)
#   - Add a user or a group as an actor with Add-GlpiToolsItems (Ticket_User, Group_Ticket);
#     for users use -requester_id and -technician_id in Update-GlpiToolsTicket
#   - Request and answer a validation (TicketValidation)
#   - Approve or refuse a solution (ITILFollowup with add_close / add_reopen)
#   - Answer the satisfaction survey (TicketSatisfaction)
#   - Item history (Get-GlpiToolsItemLogs) and search options (Get-GlpiToolsListSearchOptions)
#   - Options such as -DisableNotification in New-GlpiToolsTicket
