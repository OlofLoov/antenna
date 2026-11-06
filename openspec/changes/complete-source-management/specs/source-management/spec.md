## ADDED Requirements

### Requirement: Invalid URL keeps the sheet open
The system SHALL keep the add-source sheet open, showing its error, when a save fails because the URL has no scheme.

#### Scenario: URL without a scheme
- **GIVEN** the URL field holds text without a scheme
- **WHEN** the user taps Save
- **THEN** the sheet stays open and shows "Enter a valid URL."

### Requirement: No sources shows the empty state
The system SHALL show the empty state in the channel list when the user has no sources.

#### Scenario: No sources
- **GIVEN** no sources
- **WHEN** the channel list is shown
- **THEN** the empty state is shown

#### Scenario: Every source deleted
- **GIVEN** a loaded channel list
- **WHEN** the user deletes every source
- **THEN** the list is cleared and the empty state is shown

### Requirement: Settings lists sources in order
The system SHALL list the user's sources in Settings in their sort order, each row showing the source's name and URL.

#### Scenario: Three sources
- **GIVEN** three sources with sort order 0, 1 and 2
- **WHEN** Settings is shown
- **THEN** their rows appear in that order, each with its name and URL

#### Scenario: Source with no URL
- **GIVEN** a source that arrived through a partial sync without its URL
- **WHEN** Settings is shown
- **THEN** its row shows an empty URL line

### Requirement: Sources sync between devices
The system SHALL show a source saved on one device in the Settings of every other device signed into the same iCloud account, without any action from the user. This is checked by hand on two devices.

#### Scenario: Second device
- **GIVEN** a source saved on device A
- **WHEN** device B, signed into the same iCloud account, finishes importing from iCloud
- **THEN** the source is listed in device B's Settings

### Requirement: Tapping a channel starts playback
The system SHALL open the player on the channel's stream when the user selects a channel in the list, titled with the channel's name on every platform. This is a stopgap until a playback change replaces it.

#### Scenario: Select a channel
- **GIVEN** a listed channel
- **WHEN** the user selects it, by tap on iOS and iPadOS, click on macOS or select on tvOS
- **THEN** the player is pushed onto the channel list's navigation stack, playing the channel's stream, with the channel's name as its title
