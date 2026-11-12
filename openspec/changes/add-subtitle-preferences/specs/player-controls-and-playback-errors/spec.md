## ADDED Requirements

### Requirement: Turn subtitles on or off in one step
The system SHALL offer a subtitles switch in the player that turns subtitles on, in the user's first language the stream has or else its first full track, or off with one press, shows which it is, and is kept for the channel like a pick in the list. It sits next to the audio-and-subtitles button on iPhone, iPad and Mac wherever AirPlay can show, and in the info panel on Apple TV.

#### Scenario: Turning subtitles on on iPhone in full screen
- **GIVEN** a channel with English subtitles playing in full screen on iPhone, with subtitles off and English as the device's language
- **WHEN** the user taps the subtitles button
- **THEN** English subtitles show, the button reads as on, and no list opens

#### Scenario: Turning subtitles off on Apple TV
- **GIVEN** subtitles are on and the info panel is open
- **WHEN** the user moves focus to the subtitles switch and presses select
- **THEN** subtitles turn off, the switch reads "Subtitles Off", and the panel stays open

#### Scenario: No subtitles in the stream
- **GIVEN** a stream with no subtitles
- **WHEN** the controls or the panel show
- **THEN** the subtitles switch is grayed out on iPhone, iPad and Mac, and not shown on Apple TV

#### Scenario: Only forced subtitles on
- **GIVEN** forced subtitles show because no full subtitles are on
- **WHEN** the user looks at the switch
- **THEN** it reads as off, and pressing it turns full subtitles on

#### Scenario: The switch is remembered for the channel
- **GIVEN** the user turned subtitles on with the switch on a channel
- **WHEN** they come back to that channel on the same device
- **THEN** it starts with those subtitles

#### Scenario: The narrow player on iPhone
- **GIVEN** the small player above the channel list on iPhone
- **WHEN** the controls show
- **THEN** the subtitles button is not in the strip, and subtitles are turned on or off from the audio-and-subtitles list or in full screen
