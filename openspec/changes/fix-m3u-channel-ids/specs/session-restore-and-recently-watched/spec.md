## MODIFIED Requirements

### Requirement: Links with passwords are never stored
The system SHALL never store a stream link in Recents or in what is saved for restore, and SHALL add M3U channels to Recents and save them for restore like any other channel. A channel whose internal id still contains a stream link SHALL be neither added nor saved, with no error shown.

#### Scenario: An M3U channel
- **GIVEN** a channel from an M3U playlist whose links carry a username and password
- **WHEN** the user watches it for ten seconds
- **THEN** it is added to Recents and saved as the channel to restore, and neither stored value holds the link, the username or the password

#### Scenario: An M3U channel with a stream link in its id
- **GIVEN** a channel whose internal id (Antenna's own reference to the channel) still contains a stream link
- **WHEN** the user watches it
- **THEN** it is neither added to Recents nor saved as the channel to restore, and no error is shown

#### Scenario: Xtream channels
- **GIVEN** a channel from an Xtream source
- **WHEN** the user watches it for ten seconds
- **THEN** it is added to Recents and saved as the channel to restore
