## ADDED Requirements

### Requirement: AV1 and VP9 play where the device decodes them
The system SHALL play AV1 and VP9 pictures on the FFmpeg path with the device's hardware video decoder when the device has one for that codec, SHALL send such a stream to Apple's player when the device has none and Apple's player can read the container, and SHALL otherwise fail with the "can't decode" reason naming the codec. It SHALL never decode AV1 or VP9 in software.

#### Scenario: AV1 on a device that decodes it
- **GIVEN** an iPhone 15 Pro, a Mac with M3 or later, or another device whose video decoder handles AV1
- **WHEN** an AV1 film in Matroska or MP4 plays
- **THEN** it plays with picture and sound

#### Scenario: VP9 on a Mac
- **GIVEN** a Mac whose video decoder handles VP9
- **WHEN** a VP9 film in WebM, Matroska or MP4 plays
- **THEN** it plays with picture and sound

#### Scenario: A device without the decoder
- **GIVEN** a device whose video decoder does not handle AV1, or VP9
- **WHEN** a film in that codec plays
- **THEN** it fails as "can't decode" with the codec named, and the screen offers the usual choices
- **AND** the picture is never decoded in software

### Requirement: Vorbis sound plays
The system SHALL play Vorbis sound on the FFmpeg path on all its channels once the FFmpeg build that carries its decoder is in the app.

#### Scenario: A film with Vorbis sound
- **GIVEN** a Matroska or WebM film whose sound is stereo Vorbis
- **WHEN** it plays
- **THEN** its sound plays, and the stream line names Vorbis with no "(not supported)"

## MODIFIED Requirements

### Requirement: Streams start with sound the device can play
The system SHALL start a stream on a sound track the device can decode when the stream has one, choosing among those by the usual language rules, and SHALL mark sound it cannot decode as not supported in the stream line and the audio list while the picture plays on.

#### Scenario: A DTS default with a Dolby second track
- **GIVEN** a film whose default sound is DTS and whose second track is Dolby Digital
- **WHEN** it starts
- **THEN** it plays the DTS sound, the default, decoded on the device

#### Scenario: An undecodable default with a Dolby second track
- **GIVEN** a film whose default sound is in a format the device cannot decode, such as Windows Media Audio, and whose second track is Dolby Digital
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
