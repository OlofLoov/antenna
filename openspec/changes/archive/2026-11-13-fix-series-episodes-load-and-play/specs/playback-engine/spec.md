## MODIFIED Requirements

### Requirement: Every common stream type plays
The system SHALL play HLS addresses and ordinary audio and video files through Apple's player, and raw broadcast streams, Matroska, AVI and addresses with no extension through the FFmpeg path, switching to Apple's player with no error when a raw-looking address turns out to be HLS, and to the FFmpeg path with no error when a file address turns out to hold a raw broadcast stream, Matroska or AVI.

#### Scenario: Choosing the path
- **GIVEN** a stream address ending in `.m3u8`, `.mp4`, `.mov`, `.m4v`, `.mp3`, `.aac` or `.m4a`, or in `.ts`, `.mkv`, `.avi` or nothing at all
- **WHEN** the screen asks to play it
- **THEN** the first kind plays through Apple's player and the second through the FFmpeg path

#### Scenario: A raw-looking address that is HLS
- **GIVEN** an address that looks like a raw stream but serves HLS
- **WHEN** the screen asks to play it
- **THEN** it plays through Apple's player with no error shown

#### Scenario: A file address that is Matroska
- **GIVEN** an episode the provider lists as `.mp4`, or with no extension, whose file is Matroska, AVI or a raw broadcast stream
- **WHEN** the user plays it
- **THEN** it plays through the FFmpeg path with no error shown

#### Scenario: A radio stream
- **GIVEN** a stream with sound and no picture
- **WHEN** it plays
- **THEN** it plays and the screen decides what to show

#### Scenario: An old SD channel
- **GIVEN** a raw broadcast stream with MPEG-2 video and MP2 sound
- **WHEN** it plays on iPhone, iPad, Mac or Apple TV
- **THEN** it plays with picture and sound
