## MODIFIED Requirements

### Requirement: Channel list over the picture
The system SHALL open the channel overlay over a dark scrim when the user presses select on the full-screen picture, highlighting the playing channel in the group the user last tuned from as the channel overlay describes. Selecting a row SHALL tune that channel and go back to full screen, and Menu SHALL close the list without changing channel.

#### Scenario: Changing channel
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses select, moves down one row and presses select
- **THEN** the list closes and the channel below the playing one plays full screen with no tab bar

#### Scenario: The channel already playing
- **GIVEN** the list is open
- **WHEN** the user selects the channel that is already playing
- **THEN** the list closes and the stream is not loaded again
