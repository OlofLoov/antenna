## MODIFIED Requirements

### Requirement: Sideways on iPhone fills the screen
The system SHALL show the playing channel full screen, with no tab bar and no channel line below the picture, whenever an iPhone is held sideways on Live with a channel playing, however it got there, and SHALL return to the list when the phone turns upright. A movie or episode that ends while Live is the open tab SHALL count as coming back to Live: the channel it stopped plays again, full screen when the phone is sideways.

#### Scenario: Turn sideways, then pick a channel
- **GIVEN** Live is open on an iPhone held sideways with no channel playing
- **WHEN** the user picks a channel
- **THEN** the picture fills the screen and the tab bar is gone

#### Scenario: Launch sideways
- **GIVEN** the last channel plays again at launch
- **WHEN** the app opens on Live with the iPhone held sideways
- **THEN** the picture fills the screen as soon as the channel plays

#### Scenario: Back to Live sideways
- **GIVEN** a channel plays and the iPhone is held sideways on another tab
- **WHEN** the user opens Live, or comes back to Live after a movie or episode
- **THEN** the picture fills the screen

#### Scenario: A movie from Siri over Live
- **GIVEN** a channel fills the screen on an iPhone held sideways
- **WHEN** Siri or a shortcut plays a movie and the user closes it, still holding the phone sideways
- **THEN** the channel plays again and the picture fills the screen

#### Scenario: Turn upright
- **GIVEN** the picture fills the screen because the iPhone is sideways
- **WHEN** the user turns the iPhone upright
- **THEN** the list, the tab bar and the channel line come back and the channel plays on without restarting

#### Scenario: Exit full screen while sideways
- **GIVEN** the picture fills the screen on an iPhone held sideways
- **WHEN** the user taps Exit full screen
- **THEN** the list shows sideways and the channel plays on
- **AND** picking or changing channel, or turning the phone upright and sideways again, fills the screen again
