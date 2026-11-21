## ADDED Requirements

### Requirement: One button for audio and subtitles
The system SHALL show one audio-and-subtitles button in the player controls on iPhone, iPad and Mac, wherever a channel, movie or episode plays. It shows a captions bubble, filled while full subtitles are on, and opens a system menu of the sound and subtitle choices. There is no separate subtitles button.

#### Scenario: Turning subtitles on in full screen on iPhone
- **GIVEN** a channel with English subtitles playing in full screen on iPhone, with subtitles off
- **WHEN** the user taps the audio-and-subtitles button and picks English under Subtitles
- **THEN** English subtitles show, the menu closes, and the button's bubble is filled

#### Scenario: Turning subtitles off
- **GIVEN** subtitles are on
- **WHEN** the user opens the menu and picks Off
- **THEN** subtitles stop and the bubble is no longer filled

#### Scenario: One button in the controls
- **GIVEN** a channel, movie or episode playing on iPhone, iPad or Mac, in the small player, with timeshift or in full screen
- **WHEN** the controls show
- **THEN** there is one audio-and-subtitles button and no other subtitles button
- **AND** VoiceOver reads it as "Audio and Subtitles" with whether subtitles are on

#### Scenario: What the menu shows
- **GIVEN** the menu is open
- **WHEN** the user reads it
- **THEN** it lists the sound tracks with their format, then Off and the subtitle tracks, the current choice of each checked, then the stream line, which does nothing when tapped

#### Scenario: Only forced subtitles on
- **GIVEN** forced subtitles show because no full subtitles are on
- **WHEN** the user looks at the button
- **THEN** its bubble is not filled, and the menu checks the forced track

## MODIFIED Requirements

### Requirement: Choose audio and subtitles
The system SHALL list audio and subtitle tracks with readable names and sound format, mark the current choice, switch on a pick, offer "Off" first for subtitles, and update the list when tracks change. On iPhone, iPad and Mac the list is the menu of the audio-and-subtitles button and closes on a pick. On Apple TV it is the info panel's Audio and Subtitles tabs, which stay open.

#### Scenario: Picking a track
- **GIVEN** a channel with several audio tracks and subtitle tracks
- **WHEN** the user opens the Audio or Subtitles tab on Apple TV, or the audio-and-subtitles menu on iPhone, iPad or Mac, and picks a track
- **THEN** each track shows a readable name ("English", "English (Commentary)", "Track 4" when it has no language, "Forced" for forced subtitles) with its sound format
- **AND** the current choice is marked, and picking one switches to it
- **AND** the menu closes on iPhone, iPad and Mac, and the panel stays open on Apple TV

#### Scenario: Subtitles
- **GIVEN** the subtitles list is open
- **WHEN** the stream has subtitles, or none
- **THEN** "Off" comes first, or the list says "No subtitles in this stream"

#### Scenario: Tracks change while open
- **GIVEN** the stream's tracks change
- **WHEN** the user opens the menu, or while the Apple TV panel is open
- **THEN** the list shows the new tracks

#### Scenario: Grayed-out button
- **GIVEN** a channel on iPhone, iPad or Mac with one audio track and no subtitles
- **WHEN** the controls show
- **THEN** the audio-and-subtitles button is grayed out

#### Scenario: Changing channel
- **GIVEN** the user picked a language on one channel
- **WHEN** they change channel
- **THEN** the new channel starts fresh without carrying the choice over

### Requirement: Turn subtitles on or off in one step
The system SHALL offer a subtitles switch in the Apple TV info panel that turns subtitles on, in the user's first language the stream has or else its first full track, or off with one press, shows which it is, and is kept for the channel like a pick in the list. On iPhone, iPad and Mac subtitles are turned on and off from the audio-and-subtitles menu.

#### Scenario: Turning subtitles on on iPhone in full screen
- **GIVEN** a channel with English subtitles playing in full screen on iPhone, with subtitles off
- **WHEN** the user looks for a way to turn subtitles on
- **THEN** there is no separate switch, and English under Subtitles in the audio-and-subtitles menu turns them on in two taps

#### Scenario: Turning subtitles off on Apple TV
- **GIVEN** subtitles are on and the info panel is open
- **WHEN** the user moves focus to the subtitles switch and presses select
- **THEN** subtitles turn off, the switch reads "Subtitles Off", and the panel stays open

#### Scenario: No subtitles in the stream
- **GIVEN** a stream with no subtitles
- **WHEN** the panel shows on Apple TV
- **THEN** the subtitles switch is not shown

#### Scenario: Only forced subtitles on
- **GIVEN** forced subtitles show because no full subtitles are on
- **WHEN** the user looks at the switch on Apple TV
- **THEN** it reads as off, and pressing it turns full subtitles on

#### Scenario: The switch is remembered for the channel
- **GIVEN** the user turned subtitles on with the switch on a channel
- **WHEN** they come back to that channel on the same device
- **THEN** it starts with those subtitles

#### Scenario: The narrow player on iPhone
- **GIVEN** the small player above the channel list on iPhone
- **WHEN** the controls show
- **THEN** the strip has the same one audio-and-subtitles button as full screen, and subtitles are turned on or off from its menu

### Requirement: Choose audio and subtitles in a movie or episode
The system SHALL offer in the movie and episode player the same audio and subtitle choices as Live on every platform, and SHALL start each title by the Subtitles setting.

#### Scenario: Picking a track on iPhone, iPad or Mac
- **GIVEN** a movie with several audio tracks and subtitles playing on iPhone, iPad or Mac
- **WHEN** the user taps the audio-and-subtitles button at the top of the player and picks a track
- **THEN** the menu shows the same names, check and Off row as in Live
- **AND** the movie switches to the track without restarting, and the menu closes

#### Scenario: The subtitles switch
- **GIVEN** an episode with full subtitles playing on iPhone, iPad or Mac
- **WHEN** the user picks a subtitle track in the menu
- **THEN** subtitles turn on and the button's bubble is filled, as in Live

#### Scenario: Apple TV
- **GIVEN** a movie playing on Apple TV
- **WHEN** the user holds select
- **THEN** a panel opens over the playing picture with Audio and Subtitles tabs and the Subtitles switch, and no Info tab
- **AND** Menu closes the panel first and the movie on the next press

#### Scenario: One sound and no subtitles
- **GIVEN** a title with one audio track and no subtitles
- **WHEN** the player shows
- **THEN** the audio-and-subtitles button is grayed out on iPhone, iPad and Mac, and on Apple TV the Subtitles tab says there are none

#### Scenario: The next title
- **GIVEN** the user picked a language in one title
- **WHEN** another title or the next episode starts
- **THEN** it starts by the Subtitles setting and the device's languages, without carrying the pick over

### Requirement: Extra buttons on iPhone, iPad and Mac
The system SHALL add to the controls on iPhone, iPad and Mac the audio-and-subtitles button, an AirPlay button when the stream can go to AirPlay, and on Mac mute and a volume slider with keyboard shortcuts, each with a spoken label.

#### Scenario: The controls show
- **GIVEN** a channel playing on iPhone, iPad or Mac
- **WHEN** the controls are shown
- **THEN** they include the audio-and-subtitles button and an AirPlay button when the stream can go to AirPlay
- **AND** on Mac a mute button and volume slider
- **AND** each button has a spoken label

#### Scenario: A stream that cannot go to AirPlay
- **GIVEN** a stream Antenna reads itself rather than through Apple's player
- **WHEN** the user opens the audio-and-subtitles menu
- **THEN** there is no AirPlay button and the menu's last section says "AirPlay not available for this stream"

#### Scenario: Playing on AirPlay
- **GIVEN** the stream is playing on AirPlay
- **WHEN** the user looks at the video area
- **THEN** it says "Playing on AirPlay"

#### Scenario: Mac keys
- **GIVEN** a channel playing on a Mac
- **WHEN** the user presses M, Command-Up or Command-Down
- **THEN** M mutes, and Command-Up and Command-Down change the volume
