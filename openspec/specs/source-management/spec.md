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
- **WHEN** a source's URL or credential key changes, on this device or through sync
- **THEN** the list loads again

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
The system SHALL store a Stalker portal source with its MAC address as the Keychain username and its password beside it.

#### Scenario: Stalker save
- **GIVEN** type Stalker portal with a MAC address and password
- **WHEN** the source is saved
- **THEN** a source of kind Stalker exists, and the Keychain item under its id holds the MAC address as username and the password

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

### Requirement: Stalker contributes no channels
The system SHALL load no channels from a Stalker portal source and make no request to the portal.

#### Scenario: Stalker beside M3U
- **GIVEN** a Stalker source first in order with a stored credential, and an M3U source second with 2 channels
- **WHEN** the channel list loads
- **THEN** it holds exactly the 2 M3U channels and no request reaches the portal
