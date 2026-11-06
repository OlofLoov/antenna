# Spec Delta

## Purpose

Lets anyone who has added an IPTV source look after it on every device: see whether it loaded, fix its link or login, sign in on an Apple TV, reorder, refresh or delete it, and set a few app preferences.

## ADDED Requirements

### Requirement: See how each source is doing
The system SHALL list every source in the user's order with its name, its type and one plain status line, and SHALL never show a source's link in the list.

#### Scenario: Sources in every state
- **GIVEN** sources that are loaded, loading, failed, waiting for their login, waiting for iCloud, or a Stalker portal
- **WHEN** the user opens Sources and Settings
- **THEN** each source is listed in the user's order with its name, its type, and one status line: the channel count, guide days and when it last loaded, or what it is waiting for, or why it failed
- **AND** no row shows a source's link

#### Scenario: Offline at launch
- **GIVEN** the device is offline when the app launches
- **WHEN** the user opens Sources and Settings
- **THEN** every source shows the offline reason
- **AND** each is tried again when the app comes back to the front

#### Scenario: Signed out of iCloud
- **GIVEN** the user is signed out of iCloud
- **WHEN** the user opens Sources and Settings
- **THEN** the list footer says sources stay on this device

### Requirement: Your password stays hidden
The system SHALL never show a saved Xtream password in any field, label or log, and SHALL keep the saved password when the user leaves the password field empty.

#### Scenario: Open an Xtream source's details
- **GIVEN** an Xtream source with a saved login
- **WHEN** the user opens its details
- **THEN** the username is filled in and the password field is empty
- **AND** leaving it empty keeps the saved password
- **AND** the saved password appears in no field, label or log

### Requirement: Fix a source's link or login
The system SHALL check a changed link or login against the server before saving it, and SHALL save it and reload the source only when the check works.

#### Scenario: Save a change that works
- **GIVEN** a source's details with a changed link or login
- **WHEN** the user saves and the server accepts it
- **THEN** the change is saved and the source reloads

#### Scenario: Save a change that fails
- **GIVEN** a source's details with a changed link or login
- **WHEN** the user saves and the check fails
- **THEN** the reason is shown and nothing changes

#### Scenario: Change only the name
- **WHEN** the user changes a source's name and saves
- **THEN** the name saves at once without a check

#### Scenario: A bad or duplicate link
- **WHEN** the user saves a link that is not a web address, or one already added as another source
- **THEN** the save is refused with a message

#### Scenario: A changed M3U link
- **GIVEN** favorites on an M3U source
- **WHEN** the user changes its link and the new playlist loads
- **THEN** favorites with a stable channel id survive, and those that depended on the channel's position in the playlist may not

#### Scenario: Another device deletes the source being edited
- **GIVEN** this device has a source's details open
- **WHEN** another device deletes that source
- **THEN** the deletion wins and the details close

### Requirement: Sign in on this Apple TV
The system SHALL let the user enter an Xtream login on an Apple TV that has not received it, and load the source once the login works.

#### Scenario: Sign in with a login that works
- **GIVEN** an Xtream source whose login has not reached this Apple TV
- **WHEN** the user opens its details, chooses Sign in on this Apple TV and enters a login that works
- **THEN** the source loads, its guide follows, and its row stops saying it is waiting

#### Scenario: The login arrives through iCloud
- **GIVEN** a source waiting for its login
- **WHEN** the login arrives through iCloud
- **THEN** the source loads by itself

#### Scenario: A source that cannot sign in here
- **GIVEN** a source of another type whose login cannot reach the Apple TV
- **WHEN** the user opens its details
- **THEN** it offers no Sign in on this Apple TV and says the login cannot reach this device

### Requirement: Delete a source and everything that came with it
The system SHALL delete a source only after a confirmation that says what will go, and SHALL then remove the source, its login, its favorites, its guide and its channels from this device and the user's other devices.

#### Scenario: Confirm a delete
- **GIVEN** a source with channels, favorites and a guide
- **WHEN** the user chooses Delete, reads the confirmation that says what will go, and confirms
- **THEN** the source, its login, its favorites, its guide and its channels are gone from this device and, through iCloud, from the user's other devices
- **AND** if one of its channels was playing, playback stops

#### Scenario: Cancel a delete
- **WHEN** the user cancels the delete confirmation
- **THEN** nothing changes

#### Scenario: Delete while signed out of iCloud
- **GIVEN** the user is signed out of iCloud
- **WHEN** the user deletes a source
- **THEN** it is removed from this device only

#### Scenario: Delete the last source
- **GIVEN** one source left
- **WHEN** the user deletes it
- **THEN** the app returns to onboarding

### Requirement: Changes from other devices show up by themselves
The system SHALL show sources added, edited, renamed, reordered or deleted on another device without the user doing anything, and SHALL leave unchanged sources loaded.

#### Scenario: Another device changes a source
- **GIVEN** the app is open with its sources loaded
- **WHEN** another device adds, edits, renames, reorders or deletes a source
- **THEN** this device shows the change without the user doing anything
- **AND** sources that did not change keep their channels without reloading

### Requirement: Refresh by hand
The system SHALL reload one source or every source, with its guide, when the user asks, keeping the channels available while it loads.

#### Scenario: Refresh one or all
- **GIVEN** loaded sources
- **WHEN** the user chooses Refresh now on one source or Refresh all
- **THEN** that source, or every source in order, loads again together with its guide
- **AND** the channels stay available while it loads

#### Scenario: A huge playlist
- **GIVEN** a very large playlist among the sources
- **WHEN** sources load
- **THEN** one source loads at a time and the screens stay responsive

#### Scenario: A source that never answers
- **WHEN** a source does not answer
- **THEN** the app gives up after a while and moves on to the next source

### Requirement: Sources refresh on a schedule
The system SHALL reload a source when the user comes back to the app and the source is older than the chosen refresh interval, and SHALL not reload any source on a schedule when the user chose manual refresh.

#### Scenario: One source is due
- **GIVEN** a refresh interval of 12 hours and two sources last loaded 13 and 2 hours ago
- **WHEN** the user comes back to the app
- **THEN** the 13-hour-old source reloads and the other does not

#### Scenario: Manual only
- **GIVEN** "Only manually" chosen and two sources last loaded 13 and 2 hours ago
- **WHEN** the user comes back to the app
- **THEN** neither reloads

### Requirement: A failed refresh keeps your channels
The system SHALL keep a source's loaded channels and current playback when a refresh fails, and SHALL say on the source's row that the refresh failed and why.

#### Scenario: Refresh fails offline
- **GIVEN** a loaded source whose refresh fails, for example because the device is offline
- **WHEN** the failure comes in
- **THEN** the channels already loaded stay and whatever is playing keeps playing
- **AND** the source's row shows the channel count with a line saying the refresh failed and why

#### Scenario: A broken response
- **WHEN** a source's playlist or provider response is broken
- **THEN** the source shows why, and any channels it had stay

### Requirement: Put sources in your order
The system SHALL let the user reorder sources, and SHALL apply the new order to the list and to the channels from those sources on every device without reloading.

#### Scenario: Move the last source to the top
- **GIVEN** three sources
- **WHEN** the user moves the last one to the top, by dragging or with Move up on Apple TV
- **THEN** the list and the channels from those sources follow the new order on every device
- **AND** nothing reloads

### Requirement: Choose how the app behaves
The system SHALL let the user change which screen opens at launch, how many hours the guide shows, how often sources refresh and, on Apple TV, whether swiping changes channel, and SHALL apply a change on this device and carry it to the user's other devices.

#### Scenario: Change a preference
- **GIVEN** the preferences, which start at Live, 2 hours, every 12 hours and swipe changes channel
- **WHEN** the user changes one
- **THEN** the row shows the new value, the change takes effect on this device, and it reaches the user's other devices through iCloud

#### Scenario: The purchase ends while Settings is open
- **GIVEN** Settings open with unsaved changes
- **WHEN** the purchase ends
- **THEN** the paywall replaces Settings and the unsaved changes are lost
