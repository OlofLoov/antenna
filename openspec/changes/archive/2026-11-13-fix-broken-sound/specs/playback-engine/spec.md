## ADDED Requirements

### Requirement: Sound keeps playing when its format changes
The system SHALL keep a stream's sound playing, at the right speed and on the right speakers, when its channel count or rate changes partway through, when it is HE-AAC, when it has eight channels, and when the audio output changes while it plays, and SHALL tell the screen the new channel count.

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

#### Scenario: The sound cannot be rendered
- **GIVEN** a stream whose sound the device keeps failing to render
- **WHEN** it plays
- **THEN** the picture plays on without sound and the stream says its sound is not supported

### Requirement: Streams start with sound the device can play
The system SHALL start a stream on a sound track the device can decode when the stream has one, choosing among those by the usual language rules, and SHALL mark sound it cannot decode as not supported in the stream line and the audio list while the picture plays on.

#### Scenario: A DTS default with a Dolby second track
- **GIVEN** a film whose default sound is DTS, which no Apple device decodes, and whose second track is Dolby Digital
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
