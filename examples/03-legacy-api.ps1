# GlpiTools - Examples for the legacy REST API
#
# Everything here works after you configured the module with the app token and the user token
# (see 01-install-and-configure.ps1). It also covers the tasks that the REST API v3 does not offer.
# The IDs below are only examples: change the variables to values that exist on your server.
#
# Do not run the whole file at once: copy the blocks you need and run them one by one.
# The two lines below stop an accidental full run. Remove them if you know what you are doing.
Write-Warning 'Run the blocks of this file one by one instead of the whole file.'
return

# Values used by the examples. Change them in one place.
[int]$TicketId    = 1   # an existing ticket
[int]$OtherTicket = 2   # a second ticket, used to link tickets
[int]$CategoryId  = 3   # an ITIL category without a dedicated form (see the note in "Create a ticket")
[int]$RequesterId = 2   # ID of the user who asks for the ticket
[int]$TechnicianId = 4  # ID of the user who will work on the ticket
[int]$GroupId     = 1   # ID of a technical group
[int]$ApproverId  = 2   # ID of the user who approves a validation (must be the user running the script, see below)
[int]$EntityId    = 1   # an entity you can access
[int]$ProfileId   = 4   # a profile you can use

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

# Change the profile.
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

# Get one ticket with extra data. -Parameter accepts the options of the GLPI API,
# such as ExpandDropdowns, WithLogs, WithDocuments and others.
Get-GlpiToolsTickets -TicketId $TicketId -Parameter ExpandDropdowns

# Other ways to read: -All, -TicketName (a saved search) and -SearchInTrash. Check them with:
Get-Help Get-GlpiToolsTickets -Parameter *

# ---------------------------------------------------------------------------
# Create a ticket
# ---------------------------------------------------------------------------
# -Type accepts Incident or Request (or 1 and 2). -urgency, -impact and -priority accept
# "Very low", "Low", "Medium", "High", "Very High" (or 1 to 5).
# Note: a category tied to a dedicated form (a GLPI plugin) is refused by the API.
# Pick a category without a form if you get "Bad Request".
New-GlpiToolsTicket `
    -name 'Title of a ticket created through the API' `
    -content '<p>Description in <b>HTML</b></p><table><tr><td>A table</td><td>12011</td></tr></table>' `
    -itilcategories_id $CategoryId `
    -Type Request `
    -requester_id $RequesterId

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

# ---------------------------------------------------------------------------
# Link tickets
# ---------------------------------------------------------------------------
# Add-GlpiToolsItems creates any item of GLPI. -AddTo is the item type and -HashtableToAdd has
# its fields (the same names as the database columns).
# link: 1 Linked to, 2 Duplicates, 3 Duplicated by, 4 Child of, 5 Parent of.
# GLPI refuses the same pair twice.
$form = @{
    tickets_id_1 = $TicketId
    tickets_id_2 = $OtherTicket
    link         = 1
}
Add-GlpiToolsItems -AddTo 'Ticket_Ticket' -HashtableToAdd $form

# ---------------------------------------------------------------------------
# Validation (approval request)
# ---------------------------------------------------------------------------
# Do this while the ticket is open: GLPI refuses new requests on a closed ticket.
# 1) Ask a user to approve the ticket. The approver is given by itemtype_target and items_id_target.
$form = @{
    tickets_id         = $TicketId
    itemtype_target    = 'User'
    items_id_target    = $ApproverId
    comment_submission = '<p>Comment for the approver</p>'
}
Add-GlpiToolsItems -AddTo 'TicketValidation' -HashtableToAdd $form

# 2) Find the requests that still wait for an answer (status 2). A ticket can have several.
$pending = @(Get-GlpiToolsItems -ItemType 'TicketValidation' -SearchText @{ tickets_id = "^$TicketId$"; status = '^2$' })
$pending | Select-Object id, status, items_id_target

# 3) Answer one of them. status: 3 Approved, 4 Refused.
# GLPI accepts the answer only from the approver: run this with the tokens of that user
# (otherwise the command reports success, but the request stays waiting).
$form = @{
    status             = 3
    comment_validation = '<p>Optional comment from the approver</p>'
}
Update-GlpiToolsItems -UpdateTo 'TicketValidation' -ItemId $pending[0].id -ItemsHashtableWithoutId $form

# ---------------------------------------------------------------------------
# Follow-ups and solutions
# ---------------------------------------------------------------------------
# Add a follow-up to a ticket. -IsPrivate hides it from the requester.
Add-GlpiToolsTicketFollowup -ticket_id $TicketId -content '<p>Follow-up in <b>HTML</b></p>'
Add-GlpiToolsTicketFollowup -ticket_id $TicketId -content '<p>Internal note</p>' -IsPrivate

# Add a solution. -solutiontype_id is the ID of the solution type (the default is 2).
Add-GlpiToolsTicketSolution -ticket_id $TicketId -content '<p>Solution in <b>HTML</b></p>' -solutiontype_id 2

# ---------------------------------------------------------------------------
# Approve or refuse a solution
# ---------------------------------------------------------------------------
# GLPI approves or refuses a solution through a follow-up with an extra flag. The generic
# command is used here because Add-GlpiToolsTicketFollowup does not have these flags.
# Use only one of the two flags:
#   add_close  = $true   approves the solution (the ticket is closed)
#   add_reopen = $true   refuses the solution (the ticket is reopened)
# The comment is optional to approve and expected to refuse.
$form = @{
    itemtype  = 'Ticket'
    items_id  = $TicketId
    content   = '<p>Comment about the solution</p>'
    add_close = $true
}
Add-GlpiToolsItems -AddTo 'ITILFollowup' -HashtableToAdd $form

# ---------------------------------------------------------------------------
# Actors: users and groups
# ---------------------------------------------------------------------------
# Add a user to a ticket. type: 1 Requester, 2 Assigned, 3 Observer.
$form = @{
    tickets_id = $TicketId
    users_id   = $TechnicianId
    type       = 2
}
Add-GlpiToolsItems -AddTo 'Ticket_User' -HashtableToAdd $form

# Add a group to a ticket. type: 1 Requester, 2 Assigned, 3 Observer.
$form = @{
    tickets_id = $TicketId
    groups_id  = $GroupId
    type       = 2
}
Add-GlpiToolsItems -AddTo 'Group_Ticket' -HashtableToAdd $form

# ---------------------------------------------------------------------------
# Satisfaction survey
# ---------------------------------------------------------------------------
# The survey exists only after a ticket is closed, in an entity where the survey is turned on
# with a rate above 0% (Setup > Entities > (entity) > Assistance tab).
# GLPI lets only the requester of the ticket answer, so use the tokens of that user.
# Find the survey of the ticket.
$survey = Get-GlpiToolsItems -ItemType 'TicketSatisfaction' -SearchText @{ tickets_id = "^$TicketId$" }
$survey | Select-Object id, tickets_id, satisfaction, date_answered

# Answer it. satisfaction is a grade from 1 to 5 and the comment is optional.
# The survey is identified by the ID of its ticket, not by its own id, so the ticket ID goes in
# -ItemId and also in the fields. GLPI accepts changes to the answer for 12 hours.
if ($survey) {
    $form = @{
        tickets_id   = $TicketId
        satisfaction = 5
        comment      = '<p>Optional comment in HTML</p>'
    }
    Update-GlpiToolsItems -UpdateTo 'TicketSatisfaction' -ItemId $TicketId -ItemsHashtableWithoutId $form
}

# ---------------------------------------------------------------------------
# Search
# ---------------------------------------------------------------------------
# Search for anything with the search engine of GLPI.
#   -SearchFor  : item type to search
#   -SearchField: IDs of the fields to filter (one or more, separated by commas)
#   -SearchType : contains, equals or notequals (one for each field)
#   -SearchValue: values to search (one for each field)
#   -SearchLink : AND, OR, AND+NOT or OR+NOT between the filters
# Field IDs come from Get-GlpiToolsListSearchOptions.
Get-GlpiToolsListSearchOptions -ListOptionsFor Ticket

# Tickets with "API" in the title (field 1) and that are not solved or closed (field 12, "notold").
Search-GlpiToolsItems -SearchFor Ticket -SearchField 1, 12 -SearchType contains, equals `
    -SearchValue 'API', notold -SearchLink AND

# ---------------------------------------------------------------------------
# Any other item type
# ---------------------------------------------------------------------------
# List items filtered by text. Use ^ and $ to match the whole value.
Get-GlpiToolsItems -ItemType Computer -SearchText @{ name = '^PC-001$' }

# Create and update an item.
Add-GlpiToolsItems -AddTo Computer -HashtableToAdd @{ name = 'PC-001'; comment = 'Created through the API' }
Update-GlpiToolsItems -UpdateTo Computer -ItemId 9 -ItemsHashtableWithoutId @{ comment = 'Updated through the API' }

# History of an item (only for the item types that the command lists).
Get-GlpiToolsItemLogs -LogsFor Computer -ItemId 9

# ---------------------------------------------------------------------------
# Plugins
# ---------------------------------------------------------------------------
# Plugins add their own fields and item types, so the examples depend on your server.
# For instance, a plugin that clones changes would be called with Add-GlpiToolsItems,
# passing the fields that the plugin documents:
#
#   Add-GlpiToolsItems -AddTo 'Change' -HashtableToAdd @{ <fields of the plugin> }
#
# Switch to a profile that can create changes (Set-GlpiToolsChangeActiveProfile) before doing it.
