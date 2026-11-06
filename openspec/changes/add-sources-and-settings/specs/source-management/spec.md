# Spec Delta

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Load failure is recorded
**Reason**: One recorded error for the whole list is replaced by a status per source, shown on each source's row and kept on this device only.
**Migration**: See `sources-and-settings` requirements "See how each source is doing" and "A failed refresh keeps your channels".
