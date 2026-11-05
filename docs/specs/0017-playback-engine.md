# 0017. Playback engine: observable state, tuning, errors and live edge

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0004, 0005
- Builds on specs: 0001, 0003, 0014, 0016
- Follow-up ADR: how FFmpeg (the open-source video library) is built, licensed and shipped for the second playback path, as ADR-0001 asks. Meanwhile the spec assumes an LGPL build linked dynamically.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-7, US-8, US-13, US-20

## Summary

This is the part of the app that actually plays a channel or a movie. Once it ships, the channels most providers serve play on every Apple device, switching channels takes about a second on Apple TV, a dropped stream reconnects by itself, and when something cannot play the screens get a plain reason instead of a raw system message. The player screens build on it: they ask it to play something and show what it reports back. It draws no buttons or messages of its own, and it does not pause or rewind live TV; that is spec 0019.

## Design

Boards: none, no UI. The video area shows the picture and subtitles edge to edge and nothing else. Screens that show what the engine reports cite this spec: 0007, 0008, 0009, 0010, 0015, 0018, 0022.
Design rules that apply: none directly. DR-1 (video never stops on tvOS) relies on AC-7; the screen specs claim it.

Not drawn: nothing, no UI.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Today the app plays video through Apple's built-in player, which cannot play the MPEG-TS streams (the raw broadcast format) most IPTV providers send (ADR-0001). When playback fails, the message it passes on can contain the stream address, password included. Eight screen specs are waiting for a player that tells them what is happening, what format is on screen, which audio and subtitle languages exist and why something failed, the same way for every kind of stream.

## Scope

In:
- Two ways to play behind one front door: Apple's player for HLS (Apple's streaming format) and ordinary video files, and a second path that reads raw broadcast streams with FFmpeg and decodes them on the device's video hardware. The app picks the path from the stream address and switches over if the guess was wrong.
- What the screens can ask for: play, pause, stop, jump to a time, pick an audio or subtitle language.
- What the screens are told: whether it is loading, playing, paused, waiting for data, reconnecting, finished or failed; the picture and sound format; the audio and subtitle languages; the current time; subtitle text to draw.
- Retrying a channel that fails to start and reconnecting one that drops. Screens show the reconnect count the engine reports and do not retry on their own (0018, 0022).
- A short list of failure reasons, with no stream address or password in any reason or log line (ADR-0003).
- Live TV resumes at the live point after a pause; films start at a saved time, can jump, and end.
- Pausing when the app goes to the background or a call comes in, resuming afterwards; Picture in Picture; matching the TV's frame rate and HDR mode on Apple TV.

Out (explicitly):
- Pausing and rewinding live TV: spec 0019.
- Player buttons, error messages the user reads, Retry, language pickers, subtitle styling, lock-screen controls: spec 0018.
- Several channels at once: spec 0022.
- Catch-up and start-over addresses.
- Custom headers some playlists ask for (user agent, referrer).
- `rtsp`, `rtmp`, `udp` multicast and `mms` streams.
- DRM-protected streams.
- AirPlay and external displays for the FFmpeg path.
- Recording.
- MPEG-2 video (old SD channels) on iPhone, iPad and Apple TV, which have no decoder for it (see Open questions).
- Picture-based subtitles and closed captions inside the video.
- Saving how far the user got: spec 0011.
- Stalker portal addresses.
- The paywall check before playback.

## User flow

The engine has no screen of its own. What the user sees through the screens built on it:

1. The user picks a channel. The old channel's picture stays up until the new one's first frame appears.
2. The new channel plays, and the screen can show its resolution, sound format and languages.
3. The connection drops. The picture freezes on the last frame while the screen shows "reconnecting, attempt 2 of 8". If every attempt fails, the screen gets a reason.
4. The user pauses live TV and presses play later. It continues from what is on air now.
5. The user switches app or takes a call. Playback pauses and starts again on return.
6. The user opens a film where they left off, skips ahead, and watches to the end.

## Acceptance criteria

The "test server" is a small web server inside the tests that serves made-up streams and can stall, cut or refuse a connection when told to.

### AC-1 Every common stream type plays
Given a stream address ending in `.m3u8`, `.mp4`, `.mov`, `.m4v`, `.mp3`, `.aac` or `.m4a`, or in `.ts`, `.mkv`, `.avi` or nothing at all
When the screen asks to play it
Then the first kind plays through Apple's player and the second through the FFmpeg path, and an address that looks like a raw stream but turns out to be HLS plays through Apple's player with no error shown.

### AC-7 Starting a channel replaces the old one cleanly
Given the engine idle, or a channel loading, playing, paused or reconnecting
When the screen asks for a channel, asks to stop, or gives up waiting
Then the old connection closes before the new one opens, any planned reconnect is called off, the abandoned request ends quietly rather than as an error, and the engine reports loading until the first frame is on screen and playing from then on (idle after stop), with no failure or pause in between and nothing from the previous channel (format, languages, time) reported; on the FFmpeg path the old picture stays until the new one appears.

### AC-10a Pause and play again
Given a channel or film playing
When the user pauses and later presses play
Then live TV continues from what is on air now, not from where it was paused (the FFmpeg path also lets go of the provider's connection while paused), a film continues within a second of where it stopped, pausing while reconnecting stops the attempts and play starts the channel again, and pressing pause or play when there is nothing to pause or play does nothing.

### AC-13 Films start where you left off, skip, and end
Given a film of known length
When it is opened at a saved time, the user skips to another time, or it plays to the end
Then it starts at the saved time (or at the beginning if the saved time is past the end), a skip lands within a second of the target, a skip past the end finishes the film, and a finished film fetches nothing more until play starts it again from the beginning; live TV, and a film whose server cannot skip, ignore the saved time and refuse to skip, and such a film starts again from the beginning after a pause.

### AC-16 The screen learns the picture and sound format
Given streams with a known resolution, frame rate, HDR type (none, HDR10 or HLG), video codec, sound codec and channel count, including a radio stream with no picture, one that changes resolution partway, and one whose only sound the device cannot decode
When each plays
Then within 2 seconds of the first frame the screen is told those values (no picture for the radio stream), is told the new values after the change, and the stream with undecodable sound plays without sound and says so; on Apple TV with Match Frame Rate and Match Dynamic Range on, the TV switches to the stream's mode.

### AC-19 Audio and subtitle languages
Given a stream with English (the default) and German sound and English and Swedish subtitles
When it starts with the user's preferred languages set, and the user later picks a different language
Then the screen gets both lists with their languages named, the starting choice follows the user's preferences in order (default sound and no subtitles when nothing matches), a pick takes effect within 2 seconds with Swedish subtitles appearing on cue, turning subtitles off removes them, and the next channel chooses by preference again.

### AC-26 Streams that cannot play fail with a clear reason
Given a stream that cannot play: an unsupported or broken address, no internet, an unreachable server or local network access refused, a failed secure connection, a login not yet on this device, a server answer of 401, 403, 404, 429, 5xx or another refusal, a login web page or garbage instead of video, raw video at an HLS address, nothing sent for 8 seconds, data but no picture for 15 seconds, a stream that stops sending after it played, or no video decoder free
When the screen asks to play it
Then playback fails with one reason from a short list (offline, unreachable, secure connection failed, login not on this device, not allowed, not found, server busy, server error, refused with the code kept, timed out, stopped sending data, stream could not be read, can't decode with the codec named, or no decoder free), a broken address fails without contacting any server, and both paths give the same reason for the same cause.

### AC-27 Passwords never leak
Given a stream address with a username, password and token in it that fails, is refused, then plays and stalls, on each path
When everything the engine reports is printed, every log line is collected, and the app's caches, cookies and temporary files are searched
Then the username, password, token, path and stream number appear nowhere, and each log line shows only the server, port, file type and failure reason.

### AC-31 A channel that won't start is retried briefly
Given a channel that fails to start because the server is busy, has a server error or the connection broke
When the engine retries
Then it tries up to 3 times while the screen still shows loading, and a refused login, a missing stream, an unreadable stream or a failed secure connection fails at once without asking the server again.

### AC-48 A dropped channel reconnects
Given a channel that drops, stalls for more than 10 seconds or loses the internet after it was playing
When the engine reconnects
Then it reports numbered attempts, up to 8 over about 45 seconds, with the last frame held; a film resumes at the time it dropped with the user's language picks kept; the count starts over after a minute of steady play; a short stall recovers without a new connection; and when attempts run out it fails with the last reason.

### AC-41 Leaving the app, phone calls and Picture in Picture
Given a channel playing on iPhone, iPad or Apple TV
When the user leaves the app while neither Picture in Picture nor background audio (0018 decides when that applies) is on, a call or another app takes the sound, or headphones are unplugged
Then playback pauses (a channel still loading or reconnecting stops instead of playing in the background), and it plays again when the user returns, or when the call ends and the system allows it, unless the user had paused it; unplugging headphones pauses it and nothing resumes it; on iPhone and iPad with Picture in Picture on, it keeps playing in the small window, whose play and pause buttons work.

### AC-44 Channel switching is fast
Given 50 channel changes between raw broadcast streams with a keyframe (a full picture a player can start from) every second, over wired Ethernet on an Apple TV 4K (3rd generation), and 50 between HLS streams with 2-second segments
When the time from asking for a channel to its first frame is measured
Then on the FFmpeg path half the switches take at most 1.0 second and nine in ten at most 1.5 seconds, and on Apple's player half take at most 2.0 seconds; iPhone, iPad and Mac are measured for comparison only.

## Edge cases

- No internet when a channel starts: it fails at once so the screen can offer Retry. Internet lost during playback: it keeps reconnecting until attempts run out.
- Zapping fast holds one connection at a time, so providers that allow one connection do not refuse the next channel. A provider that answers 403 for "too many connections" fails as "not allowed" (see Open questions).
- Old SD channels in MPEG-2 fail with "can't decode" on iPhone, iPad and Apple TV.
- Radio streams have no picture; the screen decides what to show.
- The first stream from a server on the home network triggers Apple's local network prompt; saying no fails it like an unreachable server.
- Leaving the app during a reconnect stops the attempts rather than connecting in the background.
- A source whose password has not synced yet has no channels to play. A revoked password fails as "not allowed" and is not retried.
- Language track names come from the provider and are shown as written, branding included.
- A film whose server cannot skip, in a container Apple's player handles, fails as "stream could not be read".
- Picture in Picture shows 15-second skip buttons on films and none on live TV.
- On Apple TV the TV leaves the stream's frame-rate and HDR mode when playback stops.
- On a Mac playback never pauses for being in the background.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core (choosing the path, switching over) + integration (test server) |
| AC-7 | core + integration (last frame on the FFmpeg path) |
| AC-10a | integration (both paths, test server) |
| AC-13 | integration |
| AC-16 | integration + device (HDR10 and TV mode switch on Apple TV 4K) |
| AC-19 | core (language names and choice) + integration (both paths) |
| AC-26 | core (reason mapping) + integration (test server) + device (local network refused) |
| AC-27 | core + integration (collected logs, app container) |
| AC-31 | core (simulated clock) |
| AC-48 | core (simulated clock) + integration (stalls on the test server) |
| AC-41 | integration (simulated app and audio events) + device (Picture in Picture) |
| AC-44 | device (Instruments over 50 switches per path) |

## Open questions

- iPhone, iPad and Apple TV cannot decode MPEG-2 video in hardware. An ADR-0001 amendment allowing software decoding for MPEG-2 only is the likely answer. No criterion changes until then; a test before the plan settles whether the Mac can.
- A 403 is "not allowed" and never retried, though some Xtream servers answer 403 for "too many connections" just after a switch. Retrying it once would change AC-31; decide with 0022, which treats a 403 while another tile plays as "provider refused another stream".
- Apple's player shows black between channels, because the old stream is removed to free its connection. Keeping a still of the last frame would hide it; can be decided in the plan.
- Reporting Dolby Vision waits for a test stream; can be decided in the plan.

## Notes for the plan

- Ships in two steps. Until the FFmpeg engine exists (it waits on the FFmpeg ADR), the router is built with `AVPlayerEngine` for both routes. Implemented only after the FFmpeg step.
- The old spec's Types section is the agreed contract: `PlaybackEngine` with `states()`, `presentation()`, `tracks()`, `position()` and `subtitleCues()` streams; `load(_:)` kept as an extension forwarding `PlaybackOptions()` so the screen specs' `load(channel.streamURL)` holds; `RoutedEngine` is "the same engine instance" in 0007, 0009, 0010 and 0015; engines and `PlaybackLifecycle` live in `Apps/Shared/Player/` (ADR-0005). `PlaybackOptions` has `startPosition`, an `isLive` override (catch-up passes false) and preferred audio and subtitle languages.
- Numbers the owner chose: tune policy 3 attempts (0.5 s, 1 s); drop policy 8 attempts (0.5, 1, 2, 4, 8, 10, 10, 10 s); reset after 60 s of play; stall budget 10 s; connect timeout 8 s; no-frame timeout 15 s; read-ahead at most 8 s; `position()` 1 to 4 times a second while playing and once on pause. `.offline` is retried during a reconnect, not at tune.
- Redaction: 0014 owns `redacted(_:)` and changes it first. Keep scheme, host and port; path becomes "/…" plus the last component's extension; query values become "…"; drop userinfo and fragment. Errors never hold the failing URL or an underlying error (`NSURLErrorFailingURL*`, `NSUnderlyingErrorKey`).
- Both engines fetch through an ephemeral `URLSession` with no `URLCache` and no cookies. `DemuxEngine` feeds FFmpeg through a custom AVIO context, so ATS and the `URLError` mapping apply to both, and replaces `av_log` without forwarding FFmpeg's messages.
- Text subtitles reach the app as cues on both routes (`AVPlayerItemLegibleOutput`, player rendering suppressed). Track ids are "audio-n" and "subtitle-n" in stream order.
- Lifecycle: `AVAudioSession` `.playback` / `.moviePlayback`; `UIBackgroundModes: audio` added to the tvOS target for PiP; `NSLocalNetworkUsageDescription` on both targets. Display criteria from `PresentationInfo` on the demuxer route and `AVAsset.preferredDisplayCriteria` on the system route, not cleared between channels.
- `scripts/check-rules.sh` replaces its AVPlayer check: `AVPlayer`, `AVQueuePlayer`, `AVPlayerItem`, `AVPlayerViewController` and `VideoPlayer` only in `AVPlayerEngine.swift`, `AVPlayerLayer` also in `PlayerSurfaceView.swift`. Supersedes the player view's own `AVPlayer` from 0004.
- Owed to other specs as refinements: 0008 and 0009 read badges from `PresentationInfo`; 0010 reads PiP support from `capabilities`; 0011 passes the saved time as `startPosition`; 0015 treats `.buffering` like `.playing` for its pause deadline; 0022 needs 503 and 509 not retried while another tile on the same account plays; 0019 supersedes the live pause and seek rules here.
- A contract suite runs against both engines with the fixture server; fixtures come from `scripts/make-stream-fixtures.sh` with synthetic patterns and tones, no third-party content (DR-12).

## Dropped

- Split earlier (kept for history): AC-10 into AC-10a and AC-10b; AC-37 into AC-37a and AC-37b, so each scenario passes or fails on its own.
- Merged into AC-1: AC-3, AC-3a, AC-4.
- Merged into AC-7: AC-5, AC-6, AC-7a, AC-8, AC-8a, AC-8b, AC-15a, AC-24b, AC-36.
- Merged into AC-10a: AC-9, AC-9a, AC-10b, AC-11.
- Merged into AC-13: AC-12, AC-12a, AC-12b, AC-13a, AC-13b, AC-13c, AC-14, AC-14a, AC-14c, AC-14d, AC-15c.
- Merged into AC-16: AC-17, AC-18, AC-26a, AC-43, AC-43a.
- Merged into AC-19: AC-20, AC-21, AC-22, AC-22a, AC-22b, AC-23.
- Merged into AC-26: AC-2, AC-14e, AC-24, AC-24a, AC-25, AC-38, AC-38a, AC-38b, AC-47.
- Merged into AC-27: AC-28, AC-29, AC-29a.
- Merged into AC-31: AC-30, AC-30a, AC-34, AC-35.
- Merged into AC-48: AC-31a, AC-31b, AC-32, AC-33, AC-34a, AC-37a, AC-37b.
- Merged into AC-41: AC-40, AC-40a, AC-41a, AC-41b, AC-41c, AC-41d, AC-41e, AC-42.
- Moved to the implementation plan: AC-7b, AC-14b, AC-15, AC-15b, AC-31c, AC-39, AC-39a, AC-40b, AC-45, AC-46.
