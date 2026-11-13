## MODIFIED Requirements

### Requirement: Find the channels without a guide
The system SHALL list a playlist's channels with no current programme in All channels order with a count and a short reason each, and SHALL let the user filter it by name or number on every platform.

#### Scenario: Opening the screen
- **GIVEN** a playlist where some channels have no current programme
- **WHEN** the user opens the Guide sources screen
- **THEN** those channels are listed in All channels order with a count and a short reason each
- **AND** a filter narrows it by name or number

#### Scenario: Filtering on Apple TV
- **GIVEN** the Guide sources screen on Apple TV with channels listed
- **WHEN** the user opens the search field at the top and types a name or number
- **THEN** only the channels that match stay in the list

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
