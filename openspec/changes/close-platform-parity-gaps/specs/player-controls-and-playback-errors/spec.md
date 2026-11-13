## ADDED Requirements

### Requirement: Choose audio and subtitles in a movie or episode
The system SHALL offer in the movie and episode player the same audio and subtitle lists as Live, with the subtitles switch, on every platform, and SHALL start each title by the Subtitles setting.

#### Scenario: Picking a track on iPhone, iPad or Mac
- **GIVEN** a movie with several audio tracks and subtitles playing on iPhone, iPad or Mac
- **WHEN** the user taps the audio-and-subtitles button at the top of the player and picks a track
- **THEN** the list opens as a sheet at compact width and as a popover otherwise, with the same names, tick and Off row as in Live
- **AND** the movie switches to the track without restarting, and the list stays open

#### Scenario: The subtitles switch
- **GIVEN** an episode with full subtitles playing on iPhone, iPad or Mac
- **WHEN** the user taps the subtitles button next to the audio-and-subtitles button
- **THEN** subtitles turn on or off with no list, as in Live

#### Scenario: Apple TV
- **GIVEN** a movie playing on Apple TV
- **WHEN** the user holds select
- **THEN** a panel opens over the playing picture with Audio and Subtitles tabs and the Subtitles switch, and no Info tab
- **AND** Menu closes the panel first and the movie on the next press

#### Scenario: One sound and no subtitles
- **GIVEN** a title with one audio track and no subtitles
- **WHEN** the player shows
- **THEN** both buttons are grayed out on iPhone, iPad and Mac, and on Apple TV the Subtitles tab says there are none

#### Scenario: The next title
- **GIVEN** the user picked a language in one title
- **WHEN** another title or the next episode starts
- **THEN** it starts by the Subtitles setting and the device's languages, without carrying the pick over

### Requirement: Picture in Picture on a Mac
The system SHALL let a Mac user move the playing channel into the Picture in Picture window from the Live controls, on either playback path, without reloading, and SHALL pause when the window closes and bring the picture back without reloading when the user returns it.

#### Scenario: Entering Picture in Picture
- **GIVEN** a channel playing in the Mac window
- **WHEN** the user clicks the Picture in Picture button in the controls
- **THEN** the channel keeps playing in a floating window without reloading
- **AND** the player area says "Playing in Picture in Picture"

#### Scenario: Back and closed
- **GIVEN** the channel plays in the floating window
- **WHEN** the user clicks the window's return button, or closes it
- **THEN** returning puts the picture back in the player with no reload, and closing it pauses

#### Scenario: Another channel
- **GIVEN** the channel plays in the floating window
- **WHEN** the user picks another channel in the list
- **THEN** the new channel plays in the same window
