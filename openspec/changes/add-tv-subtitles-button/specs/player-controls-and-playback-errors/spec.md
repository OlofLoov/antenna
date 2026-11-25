## ADDED Requirements

### Requirement: Audio and subtitles from the bar on Apple TV
The system SHALL show an Audio and Subtitles button on the Apple TV bar of a playing movie or episode, SHALL move focus to it when the viewer swipes or clicks down, and SHALL open the audio and subtitles panel on Subtitles when the viewer selects it. The bar SHALL stay while the button has focus. The button SHALL be grayed out and out of reach when the title has one sound and no subtitles.

#### Scenario: Swiping down
- **GIVEN** a movie playing full screen on Apple TV with the bar hidden
- **WHEN** the viewer swipes or clicks down
- **THEN** the bar shows with the Audio and Subtitles button highlighted at the end of the title row
- **AND** the bar stays up while the button has focus

#### Scenario: Selecting the button
- **GIVEN** the Audio and Subtitles button has focus
- **WHEN** the viewer presses select
- **THEN** the panel opens over the playing picture on the Subtitles tab, with focus on that tab
- **AND** Menu closes the panel and the next Menu closes the movie

#### Scenario: Back from the button
- **GIVEN** the Audio and Subtitles button has focus
- **WHEN** the viewer presses Back or swipes up
- **THEN** focus goes back to the picture, the movie keeps playing, and the bar hides a few seconds later

#### Scenario: The remote on the button
- **GIVEN** the Audio and Subtitles button has focus
- **WHEN** the viewer clicks left or right, or presses play/pause
- **THEN** the movie skips 10 seconds, or pauses and plays, as it does with focus on the picture

#### Scenario: Subtitles on
- **GIVEN** full subtitles are on in the playing title
- **WHEN** the bar shows
- **THEN** the button's bubble is filled, and VoiceOver reads it as "Audio and Subtitles, Subtitles On"

#### Scenario: One sound and no subtitles
- **GIVEN** a title with one audio track and no subtitles
- **WHEN** the viewer swipes down
- **THEN** the bar shows with the button grayed out and focus stays on the picture

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
- **WHEN** the user selects the Audio and Subtitles button on the bar, or holds select
- **THEN** a panel opens over the playing picture with Audio and Subtitles tabs and the Subtitles switch, and no Info tab
- **AND** it opens on Subtitles from the button and on Audio from the hold
- **AND** Menu closes the panel first and the movie on the next press

#### Scenario: One sound and no subtitles
- **GIVEN** a title with one audio track and no subtitles
- **WHEN** the player shows
- **THEN** the audio-and-subtitles button is grayed out on every platform, and on Apple TV the panel's Subtitles tab says there are none

#### Scenario: The next title
- **GIVEN** the user picked a language in one title
- **WHEN** another title or the next episode starts
- **THEN** it starts by the Subtitles setting and the device's languages, without carrying the pick over
