## ADDED Requirements

### Requirement: Sound in every common format plays
The system SHALL play the sound of a stream on the FFmpeg path in DTS (including the core of DTS-HD), Dolby TrueHD, MLP, Opus, FLAC, uncompressed PCM (16, 24 and 32-bit integer and 32-bit float, either byte order, and SMPTE 302M), AAC whose speakers are named in the stream, HE-AAC v2 and LATM-framed AAC, on all its channels, mixed down by the device when its output has fewer speakers.

#### Scenario: A Blu-ray rip with DTS or TrueHD
- **GIVEN** a Matroska or Blu-ray MPEG-TS film whose sound is 5.1 DTS or 5.1 Dolby TrueHD
- **WHEN** it plays on an Apple TV, iPhone, iPad or Mac
- **THEN** the sound plays on all six channels, or mixed down for headphones and stereo speakers
- **AND** the stream line names the format with its channels, with no "(not supported)"

#### Scenario: Lossless and open formats in a film
- **GIVEN** films with stereo or 5.1 FLAC, stereo or 5.1 Opus, or uncompressed PCM in Matroska, MP4 or QuickTime
- **WHEN** each plays
- **THEN** its sound plays at its normal speed on all its channels

#### Scenario: Broadcast AAC in less common forms
- **GIVEN** raw broadcast streams with four-channel AAC whose speakers the stream names itself, HE-AAC v2, AAC in LATM framing, and SMPTE 302M PCM
- **WHEN** each plays
- **THEN** the four-channel one plays on four channels, HE-AAC v2 plays in stereo, and the LATM and PCM ones play

## MODIFIED Requirements

### Requirement: Streams start with sound the device can play
The system SHALL start a stream on a sound track the device can decode when the stream has one, choosing among those by the usual language rules, and SHALL mark sound it cannot decode as not supported in the stream line and the audio list while the picture plays on.

#### Scenario: A DTS default with a Dolby second track
- **GIVEN** a film whose default sound is DTS and whose second track is Dolby Digital
- **WHEN** it starts
- **THEN** it plays the DTS sound, the default, decoded on the device

#### Scenario: An undecodable default with a Dolby second track
- **GIVEN** a film whose default sound is in a format the device cannot decode, such as Vorbis, and whose second track is Dolby Digital
- **WHEN** it starts
- **THEN** it plays with the Dolby Digital sound, and the audio list ticks that track

#### Scenario: Preferred language only in a format the device cannot play
- **GIVEN** a stream whose only English sound the device cannot decode, and a German track it can, with English preferred
- **WHEN** it starts
- **THEN** the German sound plays, and subtitles start as they would for German sound

#### Scenario: No sound the device can play
- **GIVEN** a stream whose only sound is in a format the device cannot decode
- **WHEN** it plays
- **THEN** the picture plays without sound
- **AND** the stream line and the audio list show the sound's format followed by "(not supported)"

### Requirement: Sound keeps playing when its format changes
The system SHALL keep a stream's sound playing, at the right speed and on the right speakers, when its channel count or rate changes partway through, when it is HE-AAC, when it has eight channels, and when the audio output changes while it plays, up to the last second of a film, and SHALL tell the screen the new channel count.

#### Scenario: A channel goes into a film in 5.1
- **GIVEN** a raw broadcast stream whose AAC, AC-3 or E-AC-3 sound goes from stereo to 5.1
- **WHEN** it plays past the change
- **THEN** the sound goes on without a gap and plays in 5.1
- **AND** the screen learns the sound is now 5.1

#### Scenario: An old SD channel goes mono
- **GIVEN** a raw broadcast stream whose MP2 sound goes from stereo to mono
- **WHEN** it plays past the change
- **THEN** the mono sound plays at its normal speed with no noise

#### Scenario: HE-AAC
- **GIVEN** a raw broadcast stream with HE-AAC sound
- **WHEN** it plays
- **THEN** the sound has its full treble, not only the lower half

#### Scenario: 7.1 sound in a film
- **GIVEN** a Matroska film with 7.1 AAC sound
- **WHEN** it plays
- **THEN** all eight channels play

#### Scenario: The audio output changes
- **GIVEN** a channel playing on an Apple TV, iPhone, iPad or Mac
- **WHEN** a receiver switches mode, or headphones or an AirPlay speaker connect
- **THEN** the sound comes back from where the picture is within a moment, without waiting for new data

#### Scenario: The audio output changes as a film ends
- **GIVEN** a film in its last seconds, with all of it already read from the server
- **WHEN** headphones connect or a receiver switches mode
- **THEN** the sound comes back from where the picture is and plays to the end

#### Scenario: The sound cannot be rendered
- **GIVEN** a stream whose sound the device keeps failing to render
- **WHEN** it plays
- **THEN** the picture plays on without sound and the stream says its sound is not supported
