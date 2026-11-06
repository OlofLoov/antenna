# Proposal

## Why

Today the app plays video through Apple's built-in player, which cannot play the MPEG-TS streams (the raw broadcast format) most IPTV providers send. When playback fails, the message it passes on can contain the stream address, password included. Eight screen changes are waiting for a player that tells them what is happening, what format is on screen, which audio and subtitle languages exist and why something failed, the same way for every kind of stream.

User stories served:
- "As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text."
- "As a living-room viewer, I want to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable."
- "As a viewer, I want simple player controls (pause, audio track, subtitles, programme info) and a clear message when a stream fails, so I know what happened and what to try."
- "As a watcher, I want to resume a movie or episode where I left off, on any of my devices, and keep a list of things to watch later."

Not reviewed yet.

## What Changes

- Two ways to play behind one front door: Apple's player for HLS (Apple's streaming format) and ordinary video files, and a second path that reads raw broadcast streams with FFmpeg and decodes them on the device's video hardware. The app picks the path from the stream address and switches over if the guess was wrong.
- Screens can ask to play, pause, stop, jump to a time, and pick an audio or subtitle language.
- Screens are told whether it is loading, playing, paused, waiting for data, reconnecting, finished or failed; the picture and sound format; the audio and subtitle languages; the current time; and subtitle text to draw.
- A channel that fails to start is retried, and one that drops reconnects. Screens show the reconnect count the engine reports and do not retry on their own.
- A short list of failure reasons, with no stream address or password in any reason or log line.
- Live TV resumes at the live point after a pause. Films start at a saved time, can jump, and end.
- Playback pauses when the app goes to the background or a call comes in and resumes afterwards. Picture in Picture. Apple TV matches the TV's frame rate and HDR mode.

Out of scope:
- Pausing and rewinding live TV (change `add-timeshift-catch-up-and-start-over`).
- Player buttons, error messages the user reads, Retry, language pickers, subtitle styling and lock-screen controls (change `add-player-controls-and-playback-errors`).
- Several channels at once.
- Catch-up and start-over addresses.
- Custom headers some playlists ask for (user agent, referrer).
- `rtsp`, `rtmp`, `udp` multicast and `mms` streams.
- DRM-protected streams.
- AirPlay and external displays for the FFmpeg path.
- Recording.
- MPEG-2 video (old SD channels) on iPhone, iPad and Apple TV, which have no hardware decoder for it.
- Picture-based subtitles and closed captions inside the video.
- Saving how far the user got (change `add-movies-and-series-browsing`).
- Stalker portal addresses.
- The paywall check before playback.

## Capabilities

### New Capabilities
- `playback-engine`: playing channels and films on every platform behind one interface, reporting state, format, languages, time and failure reasons, with retries, reconnects and no leaked credentials.

### Modified Capabilities
None.

## Impact

- Replaces the current player view's direct use of Apple's player; the rules script narrows where Apple's player types may appear.
- Adds an FFmpeg build to the app targets, local network and background audio entries to the targets' settings, and a stream fixture script for tests.
- Depends on: `m3u-playlists`, `xtream-live-source`, `guide-data` (address redaction), `xtream-vod-client`.
- Blocked on: a decision on how FFmpeg is built, licensed and shipped for the second playback path. Until it lands, the change assumes an LGPL build linked dynamically, and the first step ships with Apple's player on both routes.
