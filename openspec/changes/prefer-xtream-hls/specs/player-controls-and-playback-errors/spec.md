## MODIFIED Requirements

### Requirement: Extra buttons on iPhone, iPad and Mac
The system SHALL add to the controls on iPhone, iPad and Mac the audio-and-subtitles button, an AirPlay button, and on Mac mute and a volume slider with keyboard shortcuts, each with a spoken label. On a live channel the AirPlay button SHALL show wherever the controls have room for it, and SHALL decide on press: it opens the AirPlay list when the stream plays on Apple's player or can go to AirPlay as HLS, and otherwise says "AirPlay not available for this stream" in a short notice over the picture. In a movie or episode it SHALL show when the stream can go to AirPlay. The audio-and-subtitles menu's stream line SHALL name the format that plays.

#### Scenario: The controls show
- **GIVEN** a channel playing on iPhone, iPad or Mac
- **WHEN** the controls are shown full screen, or at regular width
- **THEN** they include the audio-and-subtitles button and the AirPlay button
- **AND** on Mac a mute button and volume slider
- **AND** each button has a spoken label

#### Scenario: A stream that cannot go to AirPlay
- **GIVEN** a live stream Antuna reads itself that has no HLS link it may send, such as an M3U channel in MPEG-TS or an Xtream channel whose source offers only MPEG-TS
- **WHEN** the user presses AirPlay
- **THEN** the AirPlay list does not open and a short notice says "AirPlay not available for this stream"
- **AND** the audio-and-subtitles menu does not say it up front

#### Scenario: An Xtream channel that can go to AirPlay
- **GIVEN** an Xtream channel playing as MPEG-TS whose source offers HLS
- **WHEN** the user presses AirPlay
- **THEN** the AirPlay list opens and the channel plays on as MPEG-TS until a device is picked

#### Scenario: The stream line
- **GIVEN** an Xtream channel playing on the device, then on an AirPlay TV
- **WHEN** the user opens the audio-and-subtitles menu each time
- **THEN** the stream line names MPEG-TS and Antuna's player first, then HLS and Apple's player

#### Scenario: A movie that cannot go to AirPlay
- **GIVEN** a movie or episode Antuna reads itself rather than through Apple's player
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
