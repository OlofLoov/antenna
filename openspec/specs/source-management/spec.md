# source-management Specification

## Purpose
Stores the user's sources once, syncs them through the user's own iCloud account, keeps their passwords in the Keychain only, and loads every source into one channel list. It serves the household setter-upper who wants "sources I add on one device to appear on my other devices, so I never type a URL or password twice", and the user who wants "my passwords kept private, so a synced device or a log never shows them in plain text".

## Requirements

### Requirement: Invalid URL is rejected
The system SHALL refuse to save a source whose URL has no scheme, with the message "Enter a valid URL.", and SHALL store nothing.

#### Scenario: URL without a scheme
- **GIVEN** the URL field holds text without a scheme
- **WHEN** the user taps Save
- **THEN** the save fails with "Enter a valid URL." and no source is stored

#### Scenario: Spaces around the URL
- **GIVEN** the URL field holds a valid URL with spaces or tabs before or after it
- **WHEN** the user taps Save
- **THEN** the spaces are trimmed and the trimmed URL is stored

#### Scenario: Guide link is not checked
- **GIVEN** an M3U source with any text in the guide link field
- **WHEN** the user taps Save
- **THEN** the text is stored as a lenient link, and an empty field stores no guide link

### Requirement: M3U source is saved
The system SHALL store a new M3U source with its playlist URL, its optional guide link, no credential key, and a sort position after the existing sources.

#### Scenario: Third source
- **GIVEN** N existing sources, type M3U, playlist URL U and guide link E
- **WHEN** the user taps Save
- **THEN** exactly one new source exists of kind M3U, with URL U, guide link E, no credential key and sort position N

#### Scenario: Counting the existing sources fails
- **GIVEN** the existing sources cannot be counted during the save
- **WHEN** the user taps Save
- **THEN** the new source gets sort position 0 and the save goes ahead

#### Scenario: Two devices add a source at the same time
- **GIVEN** two devices that each count N sources and save a new one before sync brings the other's
- **WHEN** both sources arrive on a device
- **THEN** both have sort position N and their order relative to each other is unspecified

#### Scenario: Guide link typed before switching type
- **GIVEN** a guide link typed while the type was M3U, then the type switched to Xtream or Stalker
- **WHEN** the user taps Save
- **THEN** the guide link is hidden from the form but still stored

### Requirement: Name defaults to host
The system SHALL name a source after its URL's host when the name field is empty, and "Source" when the URL has no host.

#### Scenario: Empty name
- **GIVEN** an empty name field and URL `http://example.com/list.m3u`
- **WHEN** the source is saved
- **THEN** its name is "example.com"

#### Scenario: No host
- **GIVEN** an empty name field and URL `file:///x.m3u`
- **WHEN** the source is saved
- **THEN** its name is "Source", and a name of only spaces is stored as typed

### Requirement: Xtream credentials go to the Keychain only
The system SHALL store an Xtream username and password as one synchronizable Keychain item keyed by the source's id, and the synced source record SHALL hold only that key.

#### Scenario: Xtream save
- **GIVEN** type Xtream Codes with a username and password
- **WHEN** the source is saved
- **THEN** the Keychain holds a synchronizable item under service `se.codecrave.antenna.sources` whose account is the source's id, and the source record holds the key but neither the username nor the password

#### Scenario: Blank username or password
- **GIVEN** type Xtream Codes with an empty username or password
- **WHEN** the user taps Save
- **THEN** the source is saved and the Keychain item holds the empty values as typed, because neither field is checked

### Requirement: Keychain failure blocks the save
The system SHALL refuse to save a source whose credential cannot be written to the Keychain, with a message beginning "Could not store credentials".

#### Scenario: Keychain write fails
- **GIVEN** the Keychain write fails
- **WHEN** the user taps Save
- **THEN** the save fails with a message beginning "Could not store credentials", the raw status appended, and no source is stored

### Requirement: Deleting a source removes its credential
The system SHALL remove a source's Keychain item when the user deletes the source on iOS or iPadOS.

#### Scenario: Swipe to delete
- **GIVEN** a saved Xtream source on iOS or iPadOS
- **WHEN** the user swipes to delete it in the Settings list
- **THEN** the source is gone and the Keychain item for its key is gone

#### Scenario: Delete on Apple TV or Mac
- **GIVEN** a saved source on Apple TV or Mac
- **WHEN** the user opens Settings
- **THEN** the source is listed but there is no way to delete it there

#### Scenario: Keychain delete fails
- **GIVEN** the Keychain delete fails
- **WHEN** the user deletes the source
- **THEN** the source is still deleted and the Keychain item is left behind

### Requirement: Empty state
The system SHALL make no network request when the user has no sources.

#### Scenario: No sources
- **GIVEN** no sources
- **WHEN** the channel list is shown
- **THEN** no network request is made

#### Scenario: First source added
- **GIVEN** no sources and the channel list on screen
- **WHEN** a source is added on this device or arrives through sync
- **THEN** the source loads without the user leaving the channel list

#### Scenario: Every source deleted
- **GIVEN** a loaded channel list
- **WHEN** every source is deleted and the list loads again
- **THEN** the channels and the recorded error are cleared

### Requirement: Channels from all sources are combined
The system SHALL load every source in sort order into one channel list, and SHALL load again when a source is added, removed, reordered or changed by sync, without downloading unchanged sources that already produced channels.

#### Scenario: M3U and Xtream together
- **GIVEN** an M3U source with 2 channels and an Xtream source with 3 streams
- **WHEN** the channel list loads for the first time
- **THEN** 5 channels are listed, the M3U ones first, in source sort order

#### Scenario: Repeated Xtream category id
- **GIVEN** an Xtream source whose categories repeat a `category_id`
- **WHEN** the channel list loads
- **THEN** the source loads instead of crashing and the first name for that id is used

#### Scenario: Unchanged sources
- **GIVEN** a loaded channel list
- **WHEN** it loads again with the same sources unchanged
- **THEN** nothing is downloaded again

#### Scenario: A changed source
- **GIVEN** a loaded channel list
- **WHEN** a source's name, type, URL, guide link or credential key changes, on this device or through sync
- **THEN** the list loads again

#### Scenario: Previous load gave no channels
- **GIVEN** a load whose sources produced no channels at all
- **WHEN** the list loads again with the same sources
- **THEN** every source is downloaded again

#### Scenario: Source record without a URL
- **GIVEN** a source record that has no URL, such as one that synced only in part
- **WHEN** the channel list loads
- **THEN** that source is skipped and the others load

#### Scenario: A newer load starts first
- **GIVEN** a load still running
- **WHEN** the sources change and a newer load starts
- **THEN** the older load's result is dropped and the list shows the newer load's channels

### Requirement: Missing credential yields no channels
The system SHALL load no channels for an Xtream source whose Keychain item is absent on this device, make no request to its server, and still load the other sources.

#### Scenario: Credential not synced yet
- **GIVEN** an Xtream source first in order whose Keychain item is absent, and an M3U source second with 2 channels
- **WHEN** the channel list loads
- **THEN** it holds exactly the M3U source's 2 channels and no request reaches the Xtream server

### Requirement: One failing source does not block the rest
The system SHALL keep loading the remaining sources when one source fails.

#### Scenario: Transport error
- **GIVEN** an M3U source first in order whose request fails with a transport error, and an M3U source second with 2 channels
- **WHEN** the channel list loads
- **THEN** it holds exactly the second source's 2 channels

#### Scenario: Playlist URL answering 404
- **GIVEN** an M3U source whose URL answers a non-2xx status
- **WHEN** the channel list loads
- **THEN** that source fails like a transport error and the others still load

### Requirement: Stalker type is stored
The system SHALL store a Stalker portal source with its MAC address as the Keychain username, its password beside it, and an optional login.

#### Scenario: Stalker save
- **GIVEN** type Stalker portal with a MAC address and password
- **WHEN** the source is saved
- **THEN** a source of kind Stalker exists, and the Keychain item under its id holds the MAC address as username and the password

#### Scenario: Stalker save with a login
- **GIVEN** type Stalker portal with a MAC address, password and login
- **WHEN** the source is saved
- **THEN** the Keychain item under its id also holds the login, and the synced source holds none of the three

### Requirement: Load failure is recorded
The system SHALL record the description of the latest failure of each load, and SHALL clear it when a load has no failure.

#### Scenario: One failing source
- **GIVEN** a source whose request fails and a second source that loads
- **WHEN** the channel list loads
- **THEN** the recorded error is the failure's description

#### Scenario: Two failing sources
- **GIVEN** two failing sources and a later source that loads
- **WHEN** the channel list loads
- **THEN** the recorded error is the later failure, and the successful source does not clear it

### Requirement: Source without a credential key yields no channels
The system SHALL load no channels for an Xtream source that has no credential key, and make no request to its server.

#### Scenario: No credential key
- **GIVEN** an Xtream source first in order with no credential key, and an M3U source second with 2 channels
- **WHEN** the channel list loads
- **THEN** it holds exactly the M3U source's 2 channels and no request reaches the Xtream server

### Requirement: Unreadable credential
The system SHALL treat a Keychain item that cannot be read or decoded as a failure of that source.

#### Scenario: Keychain read fails
- **GIVEN** an Xtream source whose Keychain read fails with a status other than not found, or whose stored data does not decode
- **WHEN** the channel list loads
- **THEN** the source adds no channels, the other sources still load, and the failure is recorded

### Requirement: Loading until the first channel
On iPhone, iPad and Mac, the system SHALL show "Loading channels…" in the channel list while at least one source exists and no channel is loaded, and SHALL list the channels in load order once there are any. The recorded load failure is not shown on screen.

#### Scenario: Sources still loading
- **GIVEN** saved sources and no loaded channels yet
- **WHEN** the channel list is shown
- **THEN** "Loading channels…" is shown

#### Scenario: Every source fails or adds nothing
- **GIVEN** saved sources that all fail, wait for a credential or produce no channels
- **WHEN** the load finishes
- **THEN** "Loading channels…" stays on screen and no failure message is shown

### Requirement: Add form follows the type
The system SHALL offer the types M3U playlist, Xtream Codes and Stalker portal. M3U SHALL ask for a name, a playlist URL and an optional guide link; Xtream for a name, a server URL, a username and a password; Stalker for a name, a server URL, a MAC address and a password. The password field SHALL hide what is typed, and Cancel SHALL close the form and store nothing.

#### Scenario: Switching to Xtream
- **GIVEN** the add form with type M3U playlist
- **WHEN** the user picks Xtream Codes
- **THEN** the URL field is labeled "Server URL", the guide link field is hidden, and Username and a hidden Password field appear

#### Scenario: Stalker fields
- **GIVEN** the add form
- **WHEN** the user picks Stalker portal
- **THEN** the fields are Name, Server URL, MAC address and a hidden Password

### Requirement: Stalker channels are combined with other sources
The system SHALL load a Stalker portal source's channels into the combined channel list alongside every other source, and SHALL record a portal failure like any other source's.

#### Scenario: Stalker beside M3U
- **GIVEN** a Stalker source first in order with a stored credential and 3 channels, and an M3U source second with 2 channels
- **WHEN** the channel list loads
- **THEN** it holds the 3 Stalker channels followed by the 2 M3U channels

### Requirement: A source can wait for its credential
The system SHALL report a source whose password has not reached this device as waiting for its credential, separately from a source that loaded or failed.

#### Scenario: Password not synced yet
- **GIVEN** a source that needs a password and whose Keychain item has not arrived on this device
- **WHEN** the sources load
- **THEN** that source reports waiting for its credential, sends no request, and the other sources load
