## MODIFIED Requirements

### Requirement: Leave multi-view
The system SHALL end multi-view by keeping the highlighted or selected tile's channel playing on its own, without a reload, and stopping every other tile.

#### Scenario: Leave from the grid
- **GIVEN** multi-view with tile k highlighted or selected and nothing else open
- **WHEN** the user presses Menu on Apple TV, or "Exit multi-view" on Mac
- **THEN** every other tile stops and tile k's channel keeps playing full screen (Apple TV) or in the normal player with the sidebar back as it was (Mac), without a reload, at full quality and with the TV's mode matching again
- **AND** this counts as one channel change to tile k's channel, which is remembered as the last channel
- **AND** on Apple TV that Menu press does not also open the tab bar

#### Scenario: Another channel after leaving
- **GIVEN** the user left multi-view and tile k's channel plays on its own
- **WHEN** the user picks another channel from the channel list, the guide or by changing channel
- **THEN** that channel plays with its picture, as it would had multi-view never started

#### Scenario: Close the app in multi-view
- **GIVEN** multi-view with several tiles
- **WHEN** the app is closed and opened again
- **THEN** nothing about the tiles is restored and the last single channel plays

#### Scenario: The purchase lapses
- **GIVEN** multi-view playing
- **WHEN** the purchase lapses
- **THEN** the paywall replaces everything and every tile stops
