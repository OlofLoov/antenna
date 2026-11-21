## ADDED Requirements

### Requirement: Pictures show at their shape and in their colors
The system SHALL show every picture on the FFmpeg path at the shape the stream gives it, widescreen SD included, and in the colors the stream names, and SHALL show SD that names no colors in SD colors.

#### Scenario: A widescreen SD channel
- **GIVEN** a 720x576 broadcast channel marked 16:9, in MPEG-2 or in interlaced H.264
- **WHEN** it plays
- **THEN** the picture is shown at 16:9, not at the 5:4 of its stored size

#### Scenario: Deinterlaced pictures
- **GIVEN** an interlaced channel whose stream names its picture shape and colors
- **WHEN** its pictures are deinterlaced
- **THEN** the shown pictures keep that shape and those colors

#### Scenario: SD with no color tags
- **GIVEN** an SD channel whose stream does not say which colors it uses
- **WHEN** it plays
- **THEN** it is shown in SD colors, not HD ones

### Requirement: The display stays on while a stream plays
The system SHALL keep a Mac's display from sleeping while a stream plays on either path, and SHALL let it sleep again when the stream is paused, ends, fails or stops.

#### Scenario: A live channel on a Mac
- **GIVEN** a raw broadcast channel playing on a Mac whose display sleeps after a few minutes
- **WHEN** the channel plays for longer than that
- **THEN** the display stays on

#### Scenario: Paused on a Mac
- **GIVEN** a channel paused on a Mac
- **WHEN** the display's sleep time passes
- **THEN** the display may sleep

## MODIFIED Requirements

### Requirement: Every common stream type plays
The system SHALL play HLS addresses and ordinary audio and video files through Apple's player, and raw broadcast streams, Matroska, AVI and addresses with no extension through the FFmpeg path. It SHALL switch with no error to Apple's player when a raw-looking address turns out to be HLS or MP3 or AAC radio, and to the FFmpeg path when a file or HLS address turns out to hold a raw broadcast stream, Matroska or AVI, or a file Apple's player cannot decode.

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

#### Scenario: An HLS address that serves a raw broadcast stream
- **GIVEN** a channel address ending in `.m3u8` whose server sends a raw broadcast stream instead of a playlist
- **WHEN** the screen asks to play it
- **THEN** it plays through the FFmpeg path with no error shown

#### Scenario: A film Apple's player cannot decode
- **GIVEN** an MP4 film whose picture or sound Apple's player cannot decode, such as HEVC marked `hev1`, or MP2 or DTS sound
- **WHEN** the user plays it
- **THEN** it plays through the FFmpeg path with picture and sound, not black or silent
- **AND** an HLS stream is never moved this way

#### Scenario: A radio stream
- **GIVEN** a stream with sound and no picture
- **WHEN** it plays
- **THEN** it plays and the screen decides what to show

#### Scenario: Internet radio at an address with no extension
- **GIVEN** an Icecast or Shoutcast radio address such as `/stream` or `/;` that sends MP3 or AAC
- **WHEN** the screen asks to play it
- **THEN** it plays through Apple's player with no error shown

#### Scenario: A channel whose picture never comes
- **GIVEN** a raw broadcast channel that lists a picture but sends only sound, as off-air and radio channels do
- **WHEN** it plays
- **THEN** its sound starts within about 2 seconds and plays on without a picture

#### Scenario: An old SD channel
- **GIVEN** a raw broadcast stream with MPEG-2 video and MP2 sound
- **WHEN** it plays on iPhone, iPad, Mac or Apple TV
- **THEN** it plays with picture and sound

### Requirement: Streams that cannot play fail with a clear reason
The system SHALL fail a stream that cannot play with one reason from a short fixed list, give the same reason on both paths for the same cause, and fail a broken address without contacting any server.

#### Scenario: Causes and reasons
- **GIVEN** a stream that cannot play because of an unsupported or broken address, no internet, an unreachable server or refused local network access, a failed secure connection, a login not yet on this device, a server refusal, a web page or garbage instead of video, silence for 8 seconds, data but no picture for 15 seconds, a stream that stops after it played, or no free decoder
- **WHEN** the screen asks to play it
- **THEN** playback fails with one reason from: offline, unreachable, secure connection failed, login not on this device, not allowed, not found, server busy, server error, refused with the code kept, timed out, stopped sending data, stream could not be read, can't decode with the codec named, or no decoder free
- **AND** both paths give the same reason for the same cause

#### Scenario: Server answers
- **GIVEN** a server that answers 401 or 403, 404, 429, or 5xx
- **WHEN** the screen asks to play its stream
- **THEN** it fails as not allowed, not found, server busy, or server error, and any other refusal keeps its code

#### Scenario: A broken address
- **GIVEN** an address that cannot be a stream
- **WHEN** the screen asks to play it
- **THEN** it fails without contacting any server

#### Scenario: Offline at start
- **GIVEN** there is no internet
- **WHEN** a channel starts
- **THEN** it fails at once so the screen can offer Retry

#### Scenario: Local network refused
- **GIVEN** the first stream from a server on the home network and the user says no to Apple's local network prompt
- **WHEN** it plays
- **THEN** it fails like an unreachable server

### Requirement: A channel that won't start is retried briefly
The system SHALL retry a channel that fails to start because the server is busy, has a server error or the connection broke up to 3 times while reporting loading, SHALL try once more after a second a channel refused or timed out within 3 seconds of another channel from the same server closing, and SHALL otherwise fail at once on a refused login, missing stream, unreadable stream or failed secure connection.

#### Scenario: Busy server
- **GIVEN** a channel that fails to start because the server is busy, has a server error or the connection broke
- **WHEN** the engine retries
- **THEN** it tries up to 3 times while the screen still shows loading

#### Scenario: Zapping on a one-connection account
- **GIVEN** a provider that allows one connection and frees it a moment after the old channel closes
- **WHEN** the user switches channel and the server refuses the new one, answers with an unusual code or does not answer in time
- **THEN** the engine tries the new channel once more after a second while the screen still shows loading
- **AND** a second refusal fails with its reason

#### Scenario: Failures that are not retried
- **GIVEN** a refused login, a missing stream, an unreadable stream or a failed secure connection on a channel that starts with no channel closed just before it
- **WHEN** the channel fails to start
- **THEN** it fails at once without asking the server again

#### Scenario: A revoked password
- **GIVEN** the provider has revoked the password
- **WHEN** a channel starts
- **THEN** it fails as "not allowed" without a retry, or after one retry when another channel from that server closed just before
