# Spec Delta

## Purpose

Lets viewers whose guide shows "No programme information" on channels that should have one choose and order the guides each playlist uses, see why a channel has no guide, and pick the right guide entry by hand, with every choice synced to their other devices.

## ADDED Requirements

### Requirement: Every guide a playlist names is used
The system SHALL list and download, once each, every guide a playlist names in its header, the guide link saved with the source, and the provider's guide for an Xtream login, the first time its guides load.

#### Scenario: First load
- **GIVEN** a playlist that names guide links in its header, a guide link saved with the source, or an Xtream login
- **WHEN** its guides load for the first time
- **THEN** each of those guides is listed and downloaded once, and a link named twice is used once

#### Scenario: The header reorders its links
- **GIVEN** a playlist whose header reorders its guide links
- **WHEN** it refreshes
- **THEN** the guide at each position changes with the header

### Requirement: Add a guide link
The system SHALL add a guide link the user enters to the end of the playlist's guide list and start downloading it, and SHALL refuse a link that is not a web address or is already listed.

#### Scenario: Adding a link
- **GIVEN** the Guide sources screen for a playlist
- **WHEN** the user enters a guide link and saves it
- **THEN** it joins the end of the list and starts downloading

#### Scenario: A bad or repeated link
- **GIVEN** the user enters a link that is not a web address, or one already in the list
- **WHEN** they save it
- **THEN** it is refused with a message

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user adds a guide
- **THEN** its row says it will retry when the device is back online

### Requirement: Choose which guide wins
The system SHALL give a channel covered by several guides the programmes of the highest guide in the list, and SHALL follow a reorder within seconds without downloading again.

#### Scenario: Moving a guide up
- **GIVEN** two loaded guides that both have programmes for the same channel
- **WHEN** the user moves the lower one above the other
- **THEN** that channel shows the programmes of the guide now on top, within seconds and without downloading anything again

#### Scenario: A guide that lists the id with no programmes
- **GIVEN** a higher guide lists a channel's id with no programmes and a lower one has programmes for it
- **WHEN** the channel's programmes are looked up
- **THEN** the lower guide supplies them

### Requirement: Turn off or remove a guide
The system SHALL remove a turned-off or removed guide's programmes from every screen, let other guides fill the channels they also cover, allow removing only guides the user added, and SHALL NOT download a turned-off guide.

#### Scenario: Turning off or removing
- **GIVEN** several loaded guides for a playlist
- **WHEN** the user turns one off, or removes one they added
- **THEN** its programmes leave every screen, and other guides fill the channels they also cover

#### Scenario: Guides the user did not add
- **GIVEN** a guide from the playlist or the provider
- **WHEN** the user looks at its actions
- **THEN** it can be turned off but not removed

### Requirement: One broken guide does not break the others
The system SHALL say on a failed guide's row what went wrong, and channels covered by the other guides SHALL still show their programmes.

#### Scenario: One guide fails
- **GIVEN** a playlist with two guides, one of which fails because of a server error, a web page instead of a guide, a corrupt file, or no network
- **WHEN** the guides load
- **THEN** that guide's row says what went wrong
- **AND** channels covered by the other guide still show their programmes

#### Scenario: A guide login not on this device
- **GIVEN** a guide whose provider login or link password has not synced to this device
- **WHEN** the guide list shows
- **THEN** its row says it is waiting for the login
- **AND** on Apple TV it offers to enter the link again there

### Requirement: See why a channel has no guide
The system SHALL say in plain words why a selected channel has no current programme, choosing from a fixed set of reasons.

#### Scenario: A channel without a programme
- **GIVEN** a channel with no current programme
- **WHEN** the user selects it on the Guide sources screen
- **THEN** the screen says why: the playlist is still loading, there is no guide, the login has not synced yet, the device is offline, every guide failed, the playlist gives no guide id, the guide does not list that id, the guide lists it with no programmes, its programmes have run out, or a hand-picked entry has no programmes

### Requirement: Find the channels without a guide
The system SHALL list a playlist's channels with no current programme in All channels order with a count and a short reason each, and SHALL let the user filter it by name or number on iPhone, iPad and Mac.

#### Scenario: Opening the screen
- **GIVEN** a playlist where some channels have no current programme
- **WHEN** the user opens the Guide sources screen
- **THEN** those channels are listed in All channels order with a count and a short reason each
- **AND** on iPhone, iPad and Mac a filter narrows it by name or number

#### Scenario: Every channel has a guide
- **GIVEN** no channel lacks a guide
- **WHEN** the screen shows
- **THEN** the list says every channel has one

#### Scenario: The same reason for every channel
- **GIVEN** every channel in a large playlist shares the same reason, such as the guide still downloading
- **WHEN** the screen shows
- **THEN** it shows that reason once with a "Show n channels" button instead of a long list

#### Scenario: No channels loaded
- **GIVEN** the playlist has not loaded any channels
- **WHEN** the screen shows
- **THEN** the guide list still works and the channel list says channels have not loaded

### Requirement: Pick the right guide entry by hand
The system SHALL let the user search the playlist's guide entries, starting from the channel's name, and pick one, after which the channel SHALL show that entry's programmes everywhere within seconds, leave the list, and read "Mapped by you".

#### Scenario: Picking an entry
- **GIVEN** a channel without a guide and at least one loaded guide
- **WHEN** the user searches the guide's entries, starting from the channel's name, and picks one
- **THEN** the channel shows that entry's programmes everywhere in the app within seconds
- **AND** it leaves the list of channels without a guide and its reason changes to "Mapped by you"
- **AND** this works even when the playlist gives the channel no guide id at all

#### Scenario: Searching offline
- **GIVEN** the device is offline
- **WHEN** the user searches guide entries
- **THEN** the search uses whatever guide this device already holds

### Requirement: Undo a hand-picked match
The system SHALL return a channel to the playlist's own guide id when the user removes its hand-picked match, and put it back in the channels-without-guide list if that id still finds nothing.

#### Scenario: Removing a match
- **GIVEN** a channel the user matched by hand
- **WHEN** the user removes the match
- **THEN** the channel goes back to the playlist's own guide id
- **AND** it returns to the list of channels without a guide if that id still finds nothing

### Requirement: Matches survive a playlist refresh
The system SHALL keep applying a hand-picked match when the playlist refreshes and the channel is renumbered or moved, or renamed in an Xtream, Stalker, Jellyfin or Channels DVR source, and SHALL keep a match whose channel left the playlist while applying it to nothing. A channel an M3U playlist renames counts as a channel that left and a new one, as its favorites do.

#### Scenario: Renumbered or moved
- **GIVEN** channels the user matched by hand
- **WHEN** the playlist refreshes and a channel is renumbered or moved within the list
- **THEN** the match still applies

#### Scenario: Renamed by the provider
- **GIVEN** a channel of an Xtream source the user matched by hand
- **WHEN** the provider renames it and the source refreshes
- **THEN** the match still applies

#### Scenario: A channel that left
- **GIVEN** a matched channel leaves the playlist
- **WHEN** the playlist refreshes
- **THEN** the match applies to nothing and is kept

#### Scenario: Too many matches
- **GIVEN** a playlist's settings reach their size cap
- **WHEN** the user adds another match
- **THEN** matches for channels that left the playlist are dropped first, then the user is asked to remove some

### Requirement: Channels matched by name
The system SHALL give a channel without a guide id the programmes of the one guide entry with the same name, ignoring case, accents and quality marks such as "HD", and only when no other entry has that name. The user SHALL see these matches and can undo each one or replace it by hand.

#### Scenario: One entry with the same name
- **GIVEN** a channel "Sport One HD" with no guide id, and one guide entry named "Sport One" across the playlist's guides
- **WHEN** the guide and the channel list have both loaded
- **THEN** the channel shows that entry's programmes everywhere in the app
- **AND** the Guide sources screen lists it under "Matched by name" and its detail reads "Matched by name"

#### Scenario: More than one candidate, or a near match
- **GIVEN** a channel with no guide id whose name equals two guide entries with different ids, or only resembles one, such as "Sport 1" against "Sport One"
- **WHEN** the guide loads
- **THEN** the channel is not matched and stays in the list of channels without a guide

#### Scenario: A channel with a guide id
- **GIVEN** a channel whose guide id is not in any guide, and a guide entry with its exact name
- **WHEN** the guide loads
- **THEN** the channel is not matched by name and its reason is that the id is not in the guide

#### Scenario: Undoing a match by name
- **GIVEN** a channel matched by name
- **WHEN** the user removes the match
- **THEN** the channel returns to the list of channels without a guide, stays unmatched after the next refresh and on the user's other devices, and can still be matched by hand

#### Scenario: A hand-picked entry wins
- **GIVEN** a channel matched by name
- **WHEN** the user picks another entry by hand
- **THEN** the channel shows the picked entry's programmes and reads "Mapped by you"

### Requirement: Settings follow you to every device
The system SHALL show the same guides in the same order and the same matched programmes on every device on the user's iCloud account within seconds of a change.

#### Scenario: A change on another device
- **GIVEN** the user adds a guide, reorders guides or matches a channel on one device
- **WHEN** their other device, signed into the same iCloud account, receives the change
- **THEN** it shows the same guides in the same order and the matched channel's programmes within seconds

#### Scenario: Two devices at once
- **GIVEN** two devices match different channels at the same moment
- **WHEN** their settings merge
- **THEN** both matches are kept

#### Scenario: Offline changes
- **GIVEN** the device is offline
- **WHEN** the user adds, reorders, turns off or matches
- **THEN** the changes apply here and sync later

#### Scenario: The playlist is deleted elsewhere
- **GIVEN** the Guide sources screen is open
- **WHEN** the playlist is deleted on another device
- **THEN** the screen closes

### Requirement: Passwords in guide links stay private
The system SHALL show a guide link with its username, password and token hidden on every device, and SHALL keep those parts only in the secure password store, never in synced settings or a log.

#### Scenario: A link with a login
- **GIVEN** the user adds a guide link that contains a username, password or token
- **WHEN** the guide list is shown on any device and the app writes its logs
- **THEN** the link appears with those parts hidden
- **AND** they are kept only in the secure password store, never in the synced settings or a log
