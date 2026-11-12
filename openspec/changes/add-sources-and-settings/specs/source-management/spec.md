# Spec Delta

## MODIFIED Requirements

### Requirement: Xtream credentials go to the Keychain only
The system SHALL store an Xtream username and password as one synchronizable Keychain item keyed by the source's id, and the synced source record SHALL hold only that key.

#### Scenario: Xtream save
- **GIVEN** type Xtream Codes with a username and password
- **WHEN** the source is saved
- **THEN** the Keychain holds a synchronizable item under service `se.codecrave.antenna.sources` whose account is the source's id, and the source record holds the key but neither the username nor the password

#### Scenario: Blank username or password
- **GIVEN** type Xtream Codes with an empty username or password
- **WHEN** the user taps Connect
- **THEN** nothing is saved and no Keychain item is written, because an Xtream source needs a username and password

### Requirement: Deleting a source removes its credential
The system SHALL remove a source's Keychain item when the user deletes the source on any platform, after the user confirms the delete.

#### Scenario: Swipe to delete
- **GIVEN** a saved Xtream source on iOS or iPadOS
- **WHEN** the user swipes to delete it in the Settings list and confirms
- **THEN** the source is gone and the Keychain item for its key is gone

#### Scenario: Delete on Apple TV or Mac
- **GIVEN** a saved Xtream source on Apple TV or Mac
- **WHEN** the user chooses Delete source in its details and confirms
- **THEN** the source is gone and the Keychain item for its key is gone

#### Scenario: Keychain delete fails
- **GIVEN** the Keychain delete fails
- **WHEN** the user deletes the source
- **THEN** the source is still deleted and the Keychain item is left behind

### Requirement: Channels from all sources are combined
The system SHALL load every source in sort order into one channel list at every launch, and SHALL load a source again when it is added or changed by sync, by hand or on schedule. Reordering SHALL change the order without downloading, and unchanged sources SHALL not download again on another source's change.

#### Scenario: M3U and Xtream together
- **GIVEN** an M3U source with 2 channels and an Xtream source with 3 streams
- **WHEN** the channel list loads at launch
- **THEN** 5 channels are listed, the M3U ones first, in source sort order

#### Scenario: Repeated Xtream category id
- **GIVEN** an Xtream source whose categories repeat a `category_id`
- **WHEN** the channel list loads
- **THEN** the source loads instead of crashing and the first name for that id is used

#### Scenario: Unchanged sources
- **GIVEN** a loaded channel list
- **WHEN** another source is added or changed
- **THEN** sources that did not change are not downloaded again

#### Scenario: A changed source
- **GIVEN** a loaded channel list
- **WHEN** a source's URL or credential key changes, on this device or through sync
- **THEN** that source loads again

#### Scenario: Reordered sources
- **GIVEN** a loaded channel list
- **WHEN** the sources are reordered, on this device or through sync
- **THEN** the channels follow the new order and nothing is downloaded

#### Scenario: Previous load gave no channels
- **GIVEN** a source whose last load produced no channels
- **WHEN** the channel list loads again
- **THEN** that source is downloaded again

#### Scenario: Source record without a URL
- **GIVEN** a source record that has no URL, such as one that synced only in part
- **WHEN** the channel list loads
- **THEN** that source is skipped and the others load

#### Scenario: A newer load starts first
- **GIVEN** a load still running
- **WHEN** the sources change and a newer load starts
- **THEN** the older load's result is dropped and the list shows the newer load's channels

## REMOVED Requirements

### Requirement: Load failure is recorded
**Reason**: One recorded error for the whole list is replaced by a status per source, shown on each source's row and kept on this device only.
**Migration**: See `sources-and-settings` requirements "See how each source is doing" and "A failed refresh keeps your channels".

## ADDED Requirements

### Requirement: An Xtream source needs a username and password
The system SHALL refuse to save an Xtream source whose username or password is empty or only spaces, because the provider issues both, and SHALL save an M3U playlist link with neither.

#### Scenario: Adding an Xtream source without a login
- **GIVEN** the add-source form, in onboarding or in Settings, with type Xtream and an empty username or password
- **WHEN** the user taps Connect
- **THEN** nothing is sent or saved and the form names the empty field

#### Scenario: Adding an M3U playlist link
- **GIVEN** the add-source form with type M3U and a playlist link
- **WHEN** the user taps Connect
- **THEN** the playlist is fetched and saved without asking for a username or password

#### Scenario: Emptying the username in a source's details
- **GIVEN** a saved Xtream source's details
- **WHEN** the user empties the username and saves, or saves an empty password on a device without the source's login
- **THEN** the save is refused with "Enter your username and password." and nothing changes
- **AND** with the login on this device, an empty password field keeps the saved password
