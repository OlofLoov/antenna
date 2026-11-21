# playback-engine Specification

## Purpose
Plays a channel or a film on every Apple device whatever stream type the provider sends, and tells the player screens what is happening and why something failed, without ever exposing a stream address or password.

## Requirements

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

### Requirement: Starting a channel replaces the old one cleanly
The system SHALL close the old connection before opening a new one, keep the old picture on screen until the new channel's first frame, call off planned reconnects, end an abandoned request quietly, report loading until the first frame and playing from then on, and report nothing left over from the previous channel.

#### Scenario: Switching channel
- **GIVEN** the engine idle, or a channel loading, playing, paused or reconnecting
- **WHEN** the screen asks for a channel, asks to stop, or gives up waiting
- **THEN** the old connection closes before the new one opens and any planned reconnect is called off
- **AND** the abandoned request ends quietly rather than as an error
- **AND** the engine reports loading until the first frame is on screen and playing from then on, or idle after stop, with no failure or pause in between
- **AND** nothing from the previous channel (format, languages, time) is reported

#### Scenario: The old picture stays
- **GIVEN** a channel is playing, on either path
- **WHEN** the user switches to another channel, on either path
- **THEN** the last picture of the old channel stays on screen until the new channel's first frame replaces it
- **AND** the screen never goes black in between

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
The system SHALL start a film at a saved time within its length, land a skip within a second, finish a film on a skip past the end and fetch nothing more until replay, and SHALL ignore saved times and refuse skips for live TV and films whose server cannot skip. A server that sends part of a film when asked SHALL count as able to skip.

#### Scenario: Opening at a saved time
- **GIVEN** a film of known length and a saved time
- **WHEN** it is opened
- **THEN** it starts at the saved time, or at the beginning if the saved time is past the end

#### Scenario: Skipping and ending
- **GIVEN** a film is playing
- **WHEN** the user skips to another time, past the end, or it plays to the end
- **THEN** a skip lands within a second of the target and a skip past the end finishes the film
- **AND** a finished film fetches nothing more until play starts it again from the beginning

#### Scenario: A server that skips without saying so
- **GIVEN** a film whose server sends part of the file when asked, but never says it accepts ranges and gives no length unless asked for a part
- **WHEN** the user skips
- **THEN** the film moves to the new time

#### Scenario: A film behind a redirect
- **GIVEN** a film whose address redirects to another server that takes ranges
- **WHEN** the user skips
- **THEN** the film moves to the new time

#### Scenario: A skip while a skip is on its way
- **GIVEN** a film is reopening at a skipped time
- **WHEN** the user skips again before the picture comes back
- **THEN** the film moves to the second time and the skip is not refused

#### Scenario: Live TV and films that cannot skip
- **GIVEN** live TV, or a film whose server cannot skip
- **WHEN** it is opened at a saved time or asked to skip
- **THEN** it ignores the saved time and refuses to skip
- **AND** the player knows the film cannot skip from the moment it starts
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

#### Scenario: Zapping between channels in the same mode
- **GIVEN** an Apple TV matching the TV's mode, and two channels with the same frame rate and dynamic range
- **WHEN** the user switches from one to the other
- **THEN** the TV does not switch mode again

### Requirement: Audio and subtitle languages
The system SHALL give the screen the audio and subtitle lists with their languages named, start with the user's preferred languages in order, apply a pick within 2 seconds, remove subtitles when turned off, choose by preference again on the next channel, and start a channel with the languages last picked on it on this device.

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

#### Scenario: Returning to a channel
- **GIVEN** the user picked German sound and Swedish subtitles on a channel
- **WHEN** the user comes back to that channel later on the same device, and it still has those tracks
- **THEN** it starts with German sound and Swedish subtitles

#### Scenario: Provider track names
- **GIVEN** the provider names its tracks with its own branding
- **WHEN** the lists reach the screen
- **THEN** the names are passed on as written

### Requirement: Interlaced broadcasts are deinterlaced
The system SHALL show interlaced video on the FFmpeg path as full progressive frames at the field rate, with no combing on motion, and SHALL leave progressive video untouched.

#### Scenario: Interlaced sport and SD channels
- **GIVEN** a raw broadcast stream in 1080i at 50 fields a second, and one in 576i
- **WHEN** each plays
- **THEN** it is shown at 50 full frames a second with no combing on moving edges
- **AND** the screen is told the stream is interlaced and the frame rate it is shown at

#### Scenario: Progressive video
- **GIVEN** a progressive stream
- **WHEN** it plays
- **THEN** its frames are shown as they arrive, with nothing added

### Requirement: Surround sound reaches the speakers
The system SHALL send Dolby Digital, Dolby Digital Plus and Dolby Atmos undecoded to a receiver or TV that takes them, and decode them for any other output, on both paths.

#### Scenario: A receiver that takes Dolby
- **GIVEN** an Apple TV connected to a receiver that takes Dolby Digital Plus with Atmos
- **WHEN** a channel with 5.1 Dolby Digital Plus, or a film with Atmos, plays
- **THEN** the receiver gets the surround sound as sent, Atmos included

#### Scenario: Speakers or headphones
- **GIVEN** an iPhone, iPad or Mac playing through its speakers or headphones
- **WHEN** the same channel plays
- **THEN** the sound is decoded and mixed for that output

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

### Requirement: Passwords never leak
The system SHALL keep the username, password, token, path and stream number of a stream address out of everything it reports, every log line, and the app's caches, cookies and temporary files, and each log line SHALL show only the server, port, file type and failure reason.

#### Scenario: A failing, refused, playing and stalling stream
- **GIVEN** a stream address with a username, password and token in it that fails, is refused, then plays and stalls, on each path
- **WHEN** everything the engine reports is printed, every log line is collected, and the app's caches, cookies and temporary files are searched
- **THEN** the username, password, token, path and stream number appear nowhere
- **AND** each log line shows only the server, port, file type and failure reason

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

### Requirement: Subtitles start by the subtitle setting
The system SHALL start a stream's subtitles by the Subtitles setting and the device's languages in their order: with Auto, subtitles start off when the sound is in one of those languages and otherwise in the first of them the stream has; with Always, in the first of them the stream has; with Off, off. A language last picked on the channel on this device wins. This extends "Audio and subtitle languages" for live TV, catch-up, movies and episodes.

#### Scenario: Auto with sound the user understands
- **GIVEN** the device's languages are English then Swedish, the setting is Auto, and a channel has English sound and English and Swedish subtitles
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: Auto with sound in another language
- **GIVEN** the device's languages are English then Swedish, the setting is Auto, and a channel has German sound and German, Swedish and English subtitles
- **WHEN** the channel starts
- **THEN** English subtitles show

#### Scenario: Auto when the stream has none of the user's languages
- **GIVEN** the setting is Auto, the device's language is English, and a channel has German sound and only German subtitles
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: Sound with no language
- **GIVEN** the setting is Auto and the playing sound has no language tag
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: Always
- **GIVEN** the setting is Always, the device's languages are Swedish then English, and a channel has English sound and English subtitles only
- **WHEN** the channel starts
- **THEN** English subtitles show

#### Scenario: Off
- **GIVEN** the setting is Off and a channel has German sound and English subtitles, with English as the device's language
- **WHEN** the channel starts
- **THEN** it plays with subtitles off

#### Scenario: A pick on the channel wins
- **GIVEN** the setting is Auto, the sound is in the user's language, and the user turned Swedish subtitles on for this channel last time
- **WHEN** the user comes back to the channel
- **THEN** Swedish subtitles show
- **AND** a channel where the user turned subtitles off starts with them off, even with Always

#### Scenario: A movie
- **GIVEN** the setting is Auto, the device's language is English, and a movie has French sound and English subtitles
- **WHEN** the movie starts
- **THEN** English subtitles show

#### Scenario: Changing the setting while watching
- **GIVEN** a channel is playing
- **WHEN** the user changes the Subtitles setting
- **THEN** the playing channel keeps its subtitles and the next channel starts by the new setting

### Requirement: Forced subtitles in your language show
The system SHALL report forced subtitle tracks, the ones that translate only foreign speech or signs, with the other subtitles, name them as forced, and show a forced track in the user's first language that has one whenever no full subtitles are on, whatever the setting.

#### Scenario: Forced subtitles with subtitles off
- **GIVEN** the device's language is English, a movie has English sound, English subtitles and forced English subtitles, and the setting is Auto
- **WHEN** the movie starts
- **THEN** the forced English subtitles show and full subtitles stay off

#### Scenario: Forced subtitles in the list
- **GIVEN** a stream with forced subtitles
- **WHEN** the user opens the subtitle list
- **THEN** the forced track reads "English (Forced)", or "Forced" when it has no language

#### Scenario: Full subtitles replace forced ones
- **GIVEN** the setting starts full subtitles in the user's language
- **WHEN** the stream also has forced subtitles in that language
- **THEN** only the full subtitles show

### Requirement: Picture subtitles in broadcast streams
The system SHALL list the picture subtitles that broadcast MPEG-TS streams carry (DVB subtitles) as subtitle tracks with their languages, start them by the same rule as text subtitles, and draw each picture over the video in its place, scaled with the picture, at its time and for its duration, on every platform. Teletext subtitles are not listed.

#### Scenario: A broadcast channel with picture subtitles
- **GIVEN** a raw MPEG-TS channel with German sound and DVB subtitles in German and English, and English as the device's language with the setting on Auto
- **WHEN** the channel starts
- **THEN** the subtitle list shows German and English, English is on, and its pictures appear over the video at their times

#### Scenario: Scaled with the picture
- **GIVEN** picture subtitles are on
- **WHEN** the picture shows in the small player or in full screen
- **THEN** the subtitles keep their place on the picture and scale with it

#### Scenario: A subtitle clears
- **GIVEN** a picture subtitle is on screen
- **WHEN** its display time ends, or the broadcaster sends an empty page
- **THEN** it disappears

#### Scenario: Teletext
- **GIVEN** a raw MPEG-TS channel whose only subtitles are teletext
- **WHEN** the user opens the subtitle list
- **THEN** it says there are no subtitles in this stream

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

### Requirement: Undecodable pictures are not shown
The system SHALL show only pictures the device can decode in full on the FFmpeg path: pictures that depend on pictures it never read are left out, and the picture goes on from the next picture that is whole.

#### Scenario: Starting or skipping into a 4K film
- **GIVEN** an HEVC film encoded with open GOPs, as UHD films often are
- **WHEN** it starts, resumes or skips to a point between two keyframes
- **THEN** the first picture shown is the keyframe, with no green or broken picture before or after it

#### Scenario: A Dolby Vision film
- **GIVEN** an HEVC film that carries a Dolby Vision enhancement layer and its metadata in the same track
- **WHEN** it plays on the FFmpeg path
- **THEN** its base layer plays as HDR10 or SDR, with no green blocks

#### Scenario: A channel that loses data
- **GIVEN** a raw broadcast stream that loses packets on the way
- **WHEN** a picture arrives with data missing
- **THEN** the last whole picture stays on screen until the next keyframe, and the channel plays on from there with no green or smeared blocks

#### Scenario: The decoder stops
- **GIVEN** a channel or film playing on the FFmpeg path
- **WHEN** the device's video decoder fails on a picture, or needs restarting after the app comes back from the background
- **THEN** the picture goes on from the next keyframe, with no broken picture in between

### Requirement: Film sound plays without clicks
The system SHALL play the sound of a film or channel as one unbroken stream when its times are within a few milliseconds of each other, and SHALL name every speaker of 5.1, 6.1 and 7.1 sound as the stream does.

#### Scenario: TrueHD or DTS in a Matroska film
- **GIVEN** a Matroska film with Dolby TrueHD or DTS sound, whose container times are rounded to the millisecond
- **WHEN** it plays
- **THEN** the sound plays with no clicks, crackle or gaps, and stays in step with the picture

#### Scenario: 7.1 sound on a receiver
- **GIVEN** a film with 7.1 TrueHD sound
- **WHEN** it plays on an Apple TV connected to a 7.1 receiver
- **THEN** the side and back channels come out of the side and back speakers

### Requirement: Live keeps playing across a timestamp jump
The system SHALL keep a live broadcast on the FFmpeg path playing when the stream's clock jumps forward or back or wraps around, with picture and sound in step and no pause longer than the wait for the next whole picture.

#### Scenario: An ad break or a feed switch
- **GIVEN** a live channel playing
- **WHEN** the provider switches to another feed and the stream's clock jumps forward or back by seconds or hours
- **THEN** the picture and sound carry on from the new feed without freezing, going silent or dropping the channel
- **AND** the sound stays in step with the picture

#### Scenario: The new feed starts between keyframes
- **GIVEN** a live channel playing
- **WHEN** the clock jumps and the new feed does not start on a keyframe
- **THEN** the last whole picture stays on screen until the new feed's first keyframe, with no green or broken picture

#### Scenario: A channel left on for more than a day
- **GIVEN** a broadcast stream whose clock wraps back to zero every 26.5 hours
- **WHEN** the clock wraps while the channel plays
- **THEN** the channel plays on with no pause or jump

### Requirement: Sound that starts late is played
The system SHALL play the sound of a live broadcast on the FFmpeg path when it starts after the picture, and SHALL go on to another sound of the channel when the one that plays stops while the other goes on.

#### Scenario: Sound that appears after the picture
- **GIVEN** a live channel that starts with picture only
- **WHEN** a sound track appears in the stream
- **THEN** it plays within a moment, in step with the picture
- **AND** the audio list and the sound format on screen show it

#### Scenario: The program moves its sound
- **GIVEN** a live channel playing with sound
- **WHEN** the broadcast moves the program's sound to another track and the old one stops
- **THEN** the sound goes on from the new track within two seconds, chosen by the user's languages as at the start
- **AND** the audio list shows the new track as the one that plays

### Requirement: Audio description is not the default sound
The system SHALL pass over sound marked as audio description when it chooses the sound a stream starts with, as long as the stream has other sound. The described track stays in the audio list.

#### Scenario: A channel with a described track first
- **GIVEN** a channel whose first sound track is English audio description and whose second is the main English sound
- **WHEN** it starts
- **THEN** the main English sound plays
- **AND** the audio list has both tracks

#### Scenario: Only described sound
- **GIVEN** a stream whose only sound is audio description
- **WHEN** it starts
- **THEN** that sound plays

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
