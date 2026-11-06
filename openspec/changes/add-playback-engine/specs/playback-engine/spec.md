# Spec Delta

## Purpose

Plays a channel or a film on every Apple device whatever stream type the provider sends, and tells the player screens what is happening and why something failed, without ever exposing a stream address or password.

## ADDED Requirements

### Requirement: Every common stream type plays
The system SHALL play HLS addresses and ordinary audio and video files through Apple's player, and raw broadcast streams, Matroska, AVI and addresses with no extension through the FFmpeg path, switching to Apple's player with no error when a raw-looking address turns out to be HLS.

#### Scenario: Choosing the path
- **GIVEN** a stream address ending in `.m3u8`, `.mp4`, `.mov`, `.m4v`, `.mp3`, `.aac` or `.m4a`, or in `.ts`, `.mkv`, `.avi` or nothing at all
- **WHEN** the screen asks to play it
- **THEN** the first kind plays through Apple's player and the second through the FFmpeg path

#### Scenario: A raw-looking address that is HLS
- **GIVEN** an address that looks like a raw stream but serves HLS
- **WHEN** the screen asks to play it
- **THEN** it plays through Apple's player with no error shown

#### Scenario: A radio stream
- **GIVEN** a stream with sound and no picture
- **WHEN** it plays
- **THEN** it plays and the screen decides what to show

### Requirement: Starting a channel replaces the old one cleanly
The system SHALL close the old connection before opening a new one, call off planned reconnects, end an abandoned request quietly, report loading until the first frame and playing from then on, and report nothing left over from the previous channel.

#### Scenario: Switching channel
- **GIVEN** the engine idle, or a channel loading, playing, paused or reconnecting
- **WHEN** the screen asks for a channel, asks to stop, or gives up waiting
- **THEN** the old connection closes before the new one opens and any planned reconnect is called off
- **AND** the abandoned request ends quietly rather than as an error
- **AND** the engine reports loading until the first frame is on screen and playing from then on, or idle after stop, with no failure or pause in between
- **AND** nothing from the previous channel (format, languages, time) is reported

#### Scenario: The old picture on the FFmpeg path
- **GIVEN** a channel plays on the FFmpeg path
- **WHEN** the user switches to another channel on that path
- **THEN** the old picture stays until the new one appears

#### Scenario: Zapping with a one-connection provider
- **GIVEN** a provider that allows one connection at a time
- **WHEN** the user zaps quickly
- **THEN** one connection is held at a time and the next channel is not refused for it

### Requirement: Pause and play again
The system SHALL continue live TV from what is on air now after a pause, continue a film within a second of where it stopped, stop reconnect attempts on pause and start the channel again on play, and do nothing when there is nothing to pause or play.

#### Scenario: Live TV
- **GIVEN** a channel playing
- **WHEN** the user pauses and later presses play
- **THEN** it continues from what is on air now, not from where it was paused
- **AND** on the FFmpeg path the provider's connection is let go while paused

#### Scenario: A film
- **GIVEN** a film playing
- **WHEN** the user pauses and later presses play
- **THEN** it continues within a second of where it stopped

#### Scenario: Pausing while reconnecting
- **GIVEN** a channel is reconnecting
- **WHEN** the user pauses and then presses play
- **THEN** pause stops the attempts and play starts the channel again

#### Scenario: Nothing to pause
- **GIVEN** nothing is playing, or nothing is paused
- **WHEN** the user presses pause or play
- **THEN** nothing happens

### Requirement: Films start where you left off, skip, and end
The system SHALL start a film at a saved time within its length, land a skip within a second, finish a film on a skip past the end and fetch nothing more until replay, and SHALL ignore saved times and refuse skips for live TV and films whose server cannot skip.

#### Scenario: Opening at a saved time
- **GIVEN** a film of known length and a saved time
- **WHEN** it is opened
- **THEN** it starts at the saved time, or at the beginning if the saved time is past the end

#### Scenario: Skipping and ending
- **GIVEN** a film is playing
- **WHEN** the user skips to another time, past the end, or it plays to the end
- **THEN** a skip lands within a second of the target and a skip past the end finishes the film
- **AND** a finished film fetches nothing more until play starts it again from the beginning

#### Scenario: Live TV and films that cannot skip
- **GIVEN** live TV, or a film whose server cannot skip
- **WHEN** it is opened at a saved time or asked to skip
- **THEN** it ignores the saved time and refuses to skip
- **AND** such a film starts again from the beginning after a pause

#### Scenario: A film that cannot skip in Apple's player
- **GIVEN** a film whose server cannot skip, in a container Apple's player handles
- **WHEN** it is asked to play
- **THEN** it fails as "stream could not be read"

### Requirement: The screen learns the picture and sound format
The system SHALL tell the screen the resolution, frame rate, HDR type, video codec, sound codec and channel count within 2 seconds of the first frame, update them when they change, say when sound cannot be decoded, and match the TV's mode on Apple TV when the user has that on.

#### Scenario: Known formats
- **GIVEN** streams with a known resolution, frame rate, HDR type (none, HDR10 or HLG), video codec, sound codec and channel count
- **WHEN** each plays
- **THEN** within 2 seconds of the first frame the screen is told those values

#### Scenario: Radio, mid-stream change and undecodable sound
- **GIVEN** a radio stream with no picture, one that changes resolution partway, and one whose only sound the device cannot decode
- **WHEN** each plays
- **THEN** the radio stream reports no picture, the changing stream reports the new values after the change, and the undecodable one plays without sound and says so

#### Scenario: Matching the TV on Apple TV
- **GIVEN** an Apple TV with Match Frame Rate and Match Dynamic Range on
- **WHEN** a stream plays, and later stops
- **THEN** the TV switches to the stream's mode, and leaves it when playback stops

### Requirement: Audio and subtitle languages
The system SHALL give the screen the audio and subtitle lists with their languages named, start with the user's preferred languages in order, apply a pick within 2 seconds, remove subtitles when turned off, and choose by preference again on the next channel.

#### Scenario: Starting by preference
- **GIVEN** a stream with English (the default) and German sound and English and Swedish subtitles, and the user's preferred languages set
- **WHEN** it starts
- **THEN** the screen gets both lists with their languages named
- **AND** the starting choice follows the user's preferences in order, or default sound and no subtitles when nothing matches

#### Scenario: Picking and turning off
- **GIVEN** the stream is playing
- **WHEN** the user picks Swedish subtitles, and later turns subtitles off
- **THEN** Swedish subtitles appear on cue within 2 seconds
- **AND** turning subtitles off removes them

#### Scenario: The next channel
- **GIVEN** the user picked a language on one channel
- **WHEN** the next channel starts
- **THEN** it chooses by preference again

#### Scenario: Provider track names
- **GIVEN** the provider names its tracks with its own branding
- **WHEN** the lists reach the screen
- **THEN** the names are passed on as written

### Requirement: Streams that cannot play fail with a clear reason
The system SHALL fail a stream that cannot play with one reason from a short fixed list, give the same reason on both paths for the same cause, and fail a broken address without contacting any server.

#### Scenario: Causes and reasons
- **GIVEN** a stream that cannot play because of an unsupported or broken address, no internet, an unreachable server or refused local network access, a failed secure connection, a login not yet on this device, a server refusal, a web page or garbage instead of video, raw video at an HLS address, silence for 8 seconds, data but no picture for 15 seconds, a stream that stops after it played, or no free decoder
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

#### Scenario: MPEG-2 on iPhone, iPad and Apple TV
- **GIVEN** an old SD channel in MPEG-2
- **WHEN** it plays on iPhone, iPad or Apple TV
- **THEN** it fails with "can't decode" naming the codec

#### Scenario: Local network refused
- **GIVEN** the first stream from a server on the home network and the user says no to Apple's local network prompt
- **WHEN** it plays
- **THEN** it fails like an unreachable server

### Requirement: Passwords never leak
The system SHALL keep the username, password, token, path and stream number of a stream address out of everything it reports, every log line, and the app's caches, cookies and temporary files, and each log line SHALL show only the server, port, file type and failure reason.

#### Scenario: A failing, refused, playing and stalling stream
- **GIVEN** a stream address with a username, password and token in it that fails, is refused, then plays and stalls, on each path
- **WHEN** everything the engine reports is printed, every log line is collected, and the app's caches, cookies and temporary files are searched
- **THEN** the username, password, token, path and stream number appear nowhere
- **AND** each log line shows only the server, port, file type and failure reason

### Requirement: A channel that won't start is retried briefly
The system SHALL retry a channel that fails to start because the server is busy, has a server error or the connection broke up to 3 times while reporting loading, and SHALL fail at once on a refused login, missing stream, unreadable stream or failed secure connection.

#### Scenario: Busy server
- **GIVEN** a channel that fails to start because the server is busy, has a server error or the connection broke
- **WHEN** the engine retries
- **THEN** it tries up to 3 times while the screen still shows loading

#### Scenario: Failures that are not retried
- **GIVEN** a refused login, a missing stream, an unreadable stream or a failed secure connection
- **WHEN** the channel fails to start
- **THEN** it fails at once without asking the server again

#### Scenario: A revoked password
- **GIVEN** the provider has revoked the password
- **WHEN** a channel starts
- **THEN** it fails as "not allowed" and is not retried

### Requirement: A dropped channel reconnects
The system SHALL reconnect a channel that drops, stalls over 10 seconds or loses the internet after playing, with numbered attempts up to 8 over about 45 seconds holding the last frame, resume a film where it dropped, reset the count after a minute of play, and fail with the last reason when attempts run out.

#### Scenario: Reconnecting
- **GIVEN** a channel that drops, stalls for more than 10 seconds or loses the internet after it was playing
- **WHEN** the engine reconnects
- **THEN** it reports numbered attempts, up to 8 over about 45 seconds, with the last frame held
- **AND** when attempts run out it fails with the last reason

#### Scenario: A film drops
- **GIVEN** a film that drops while playing with the user's language picks
- **WHEN** it reconnects
- **THEN** it resumes at the time it dropped with the language picks kept

#### Scenario: Steady play and short stalls
- **GIVEN** a channel reconnected earlier
- **WHEN** it plays steadily for a minute, or stalls briefly
- **THEN** the count starts over after the minute, and a short stall recovers without a new connection

#### Scenario: Leaving the app during a reconnect
- **GIVEN** a channel is reconnecting
- **WHEN** the user leaves the app
- **THEN** the attempts stop rather than connecting in the background

### Requirement: Leaving the app, phone calls and Picture in Picture
The system SHALL pause playback when the user leaves the app without Picture in Picture or background audio, when a call or app takes the sound, or when headphones are unplugged, and SHALL resume on return or when the call ends unless the user had paused or unplugged headphones.

#### Scenario: Leaving the app
- **GIVEN** a channel playing on iPhone, iPad or Apple TV, with neither Picture in Picture nor background audio on
- **WHEN** the user leaves the app
- **THEN** playback pauses, and a channel still loading or reconnecting stops instead of playing in the background
- **AND** it plays again when the user returns, unless the user had paused it

#### Scenario: A call or another app takes the sound
- **GIVEN** a channel is playing
- **WHEN** a call or another app takes the sound, and later gives it back
- **THEN** playback pauses, and plays again when the system allows it unless the user had paused it

#### Scenario: Headphones unplugged
- **GIVEN** a channel is playing through headphones
- **WHEN** they are unplugged
- **THEN** playback pauses and nothing resumes it

#### Scenario: Picture in Picture
- **GIVEN** a channel playing on iPhone or iPad with Picture in Picture on
- **WHEN** the user leaves the app
- **THEN** it keeps playing in the small window, whose play and pause buttons work
- **AND** the window shows 15-second skip buttons on films and none on live TV

#### Scenario: Mac
- **GIVEN** a channel playing on a Mac
- **WHEN** the app goes to the background
- **THEN** playback does not pause

### Requirement: Channel switching is fast
The system SHALL switch between raw broadcast channels on an Apple TV 4K (3rd generation) over Ethernet within 1.0 second for half the switches and 1.5 seconds for nine in ten, and between HLS channels on Apple's player within 2.0 seconds for half.

#### Scenario: Measured switches
- **GIVEN** 50 channel changes between raw broadcast streams with a keyframe every second, over wired Ethernet on an Apple TV 4K (3rd generation), and 50 between HLS streams with 2-second segments
- **WHEN** the time from asking for a channel to its first frame is measured
- **THEN** on the FFmpeg path half the switches take at most 1.0 second and nine in ten at most 1.5 seconds
- **AND** on Apple's player half take at most 2.0 seconds
- **AND** iPhone, iPad and Mac are measured for comparison only
