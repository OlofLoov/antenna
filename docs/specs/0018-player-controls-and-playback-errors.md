# 0018. Player controls and playback errors on every platform

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0004, 0006, 0007, 0008, 0009, 0010, 0013, 0014, 0015, 0017
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-7, US-9, US-13

## Summary

This spec is for anyone watching a channel who wants to change the language, see what is on, or understand why a stream stopped. Once it ships, Apple TV users hold select to see programme and stream details and pick audio and subtitles; iPhone, iPad and Mac users get a languages button, AirPlay and (on Mac) volume. When a stream struggles the player shows a spinner or the engine's reconnect count, and if playback gives up, it says in plain words what went wrong with a "Try again" button. It does not choose how streams are played or when they reconnect (0017), pause or rewind live TV (0019), or remember a preferred language across channels.

## Design

Boards: `docs/design/boards/TV-Player.dc.html`, `TV-Player-Tracks.dc.html`, `TV-Player-Error.dc.html`, `TV-Player-Buffering.dc.html`, `iPad-Player.dc.html`, `iPad-Player-Tracks.dc.html`, `iPad-Player-Error.dc.html`, `iPhone-Player.dc.html`, `iPhone-Player-Tracks.dc.html`, `iPhone-Player-Error.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-7, DR-8, DR-11, DR-12, DR-13, DR-15.
Not drawn: the Apple TV Subtitles tab and its "No subtitles in this stream" row; the Info tab without guide data; the reconnecting caption; the spinner on iPhone, iPad and Mac; the Picture in Picture and AirPlay placeholders; the iPhone full-screen controls; the error in full screen on iPhone, iPad and Mac; the greyed tracks button; the Apple TV "Sign in" button on the error; the error with the zap bar showing. Each is a variant of a drawn board with the same geometry.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Today the player is Apple's stock video view with its own controls, and a failed stream leaves a blank screen. The user cannot tell whether the channel is gone, the internet dropped, the login has not synced yet, or the device cannot play the format. Earlier screen specs (0008, 0010, 0015) placed their buttons and left buffering, errors, language choice, Picture in Picture and background audio to this one.

## Scope

In:
- Apple TV: an info panel opened by holding select, with Info, Audio and Subtitles tabs, closed with Menu.
- iPhone, iPad and Mac: an audio-and-subtitles button with a picker, an AirPlay button, and on Mac a volume slider, mute and volume keys.
- Every platform: a buffering spinner, the engine's reconnect count while it reconnects, an error screen with a plain reason and "Try again", and recovery on its own when the network or login comes back.
- A one-line description of the stream format ("MPEG-TS · H.264 1080p · AAC 5.1").
- Picture in Picture on iPhone and iPad, including on leaving the app; background audio; lock-screen and Control Center playback info; pausing for phone calls.

Out (explicitly):
- How streams are played, what failures are detected, which tracks exist, and when to reconnect: 0017.
- Pausing and rewinding live TV, its Apple TV rewind row and the keyboard skip keys: 0019.
- Movie and episode player screens (scrub bar, resume, back to the card).
- Catch-up and start over.
- The zap bar, channel number entry and format badges in full-screen live: 0008.
- Where play/pause, progress, LIVE, PiP and full screen sit on iPhone, iPad and Mac: 0010.
- Remembering a preferred language across channels and a background-audio switch: a settings spec.
- Picture in Picture on Mac and Apple TV.
- Several channels at once.
- Recording.

## User flow

Apple TV:
1. A channel plays full screen. The user holds select. A panel slides down over the top of the picture showing what is on, how far in, and the stream format. The picture keeps playing.
2. The user moves right to Audio or Subtitles and picks a track. The panel stays open until Menu.
3. A stream fails. The picture is replaced by the reason in plain words and a focused "Try again" button. Swiping up or down still changes channel.

iPhone, iPad and Mac:
1. The controls gain a speech-bubble button. Tapping it opens a picker with Audio and Subtitles and a footer naming the stream format.
2. An AirPlay button appears when the stream can be sent to AirPlay. On a Mac a speaker button and slider set the volume.
3. A slow stream shows a spinner; after ten seconds a line says the source is sending data slowly. A dropped stream shows the reconnect attempts before any error.
4. Leaving the app on iPhone or iPad continues the channel in Picture in Picture, or as audio with the channel on the lock screen.

## Acceptance criteria

### AC-1a See what's on without stopping the picture (Apple TV)
Given a channel playing full screen on Apple TV
When the user holds select
Then a panel opens over the top of the still-playing picture showing the channel number, name and source, the current programme with its times, minutes left and a progress bar, its summary, the format badges and a stream line such as "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna player" ("Stream details not available yet" while loading); Menu closes it; while it is open swipes move within it and never change channel, and play/pause does nothing.

### AC-3 Choose audio and subtitles
Given a channel with several audio tracks and subtitle tracks
When the user opens the Audio or Subtitles tab on Apple TV, or the audio-and-subtitles button on iPhone, iPad or Mac, and picks a track
Then each track shows a readable name ("English", "English (Commentary)", "Track 4" when it has no language, "Forced" for forced subtitles) with its sound format, the current choice is ticked, picking one switches to it and leaves the list open, subtitles offer "Off" first or "No subtitles in this stream", and the list updates if the tracks change while it is open; on iPhone, iPad and Mac the button is greyed out until there is more than one audio track or any subtitle.

### AC-9a Extra buttons on iPhone, iPad and Mac
Given a channel playing on iPhone, iPad or Mac
When the controls are shown
Then they include the audio-and-subtitles button, an AirPlay button when the stream can go to AirPlay (otherwise the picker footer says "AirPlay not available for this stream"), and on Mac a mute button and volume slider; while AirPlay is in use the video area says "Playing on AirPlay"; each button has a spoken label; on Mac M mutes and Command-Up and Command-Down change the volume.

### AC-33 The Mac remembers its volume
Given the volume or mute changed on a Mac
When the app is quit and opened again
Then the same volume comes back, unmuted if it was muted.

### AC-16a A spinner while waiting, and a reason if it is slow
Given a channel loading or waiting for data for more than half a second
When the player is shown
Then a spinner appears over the picture and goes as soon as it plays, pauses or fails; after ten seconds a line under it says "Still buffering. <source name> is sending data slowly."; on iPhone, iPad and Mac play/pause still works while it spins.

### AC-19a A dropped stream shows that it is reconnecting
Given a channel that drops while playing and the engine reconnecting as in 0017
When the player is shown
Then it says "Reconnecting… attempt n of m" with the engine's count instead of the spinner, the last picture stays, and the error shows only when the engine gives up or reports a failure reconnecting cannot fix.

### AC-17a A failed stream says what went wrong
Given a channel whose playback has failed
When the player is shown
Then the picture is replaced by a title, a plain explanation naming the source, and a "Try again" button (focused on Apple TV, where a line also names the source and when it was tried and says how to change channel); any open panel, picker or Picture in Picture window closes first; on iPhone, iPad and Mac the channel name stays visible; the messages, one per reason 0017 reports, are:

| What happened | Title | Explanation (source "Acme TV") |
|---|---|---|
| No internet | You're offline | Connect to the internet and try again. Playback resumes on its own when the connection returns. |
| Server unreachable | Could not reach Acme TV | The connection failed (<reason>). Check the network, or a VPN if one is on. |
| Secure connection failed | Could not reach Acme TV | The secure connection failed. Check the network, or a VPN if one is on. |
| Login not on this device yet | Waiting for login | The login for Acme TV has not reached this device from iCloud Keychain yet. (On Apple TV: "Sign in needed", "Sign in to Acme TV on this Apple TV to play its channels.") |
| Login rejected | Sign-in refused | Acme TV rejected the login. Check the username and password in Settings, or ask the provider whether the account has expired. (On Apple TV: "Sign in again on this Apple TV" in place of the Settings sentence.) |
| Channel not found | Stream not found | Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider. |
| Server busy | Provider busy | Acme TV is busy right now. Try again in a moment. |
| Provider's server failing | Provider error | Acme TV returned <code>. Its server is having trouble. Try again in a moment. |
| Any other refusal | Stream unavailable | Acme TV returned <code> for this channel. |
| Nothing arrived | Stream stopped | Acme TV did not send any data for <n> seconds. |
| Data stopped | Stream stopped | Acme TV stopped sending data. |
| Not a stream | Stream could not be read | Acme TV sent data that is not a playable stream. The address may point to a web page or an empty file. |
| Codec the device cannot play | Format not supported | This stream uses <codec>, which this device cannot play. Trying again will not help. Pick another channel or ask the provider for a stream in a supported format. |
| No decoder free | Can't play another stream | This device is already playing as many streams as it can. |

No message, label, Now Playing field or log line contains the stream address, server name, username or password.

### AC-6a Try again, or recover on its own
Given the error screen shown
When the user taps "Try again" (select or play/pause on Apple TV), the network comes back after an offline error, or a missing login arrives on the device
Then the same channel loads once more without counting as a channel change, the error goes and the spinner shows; on Apple TV a missing login offers a "Sign in" button that runs the sign-in step and comes back to the channel.

### AC-22a Picture in Picture on iPhone and iPad
Given a channel playing on iPhone or iPad where Picture in Picture is possible
When the user taps the PiP button or leaves the app with the Home gesture
Then the channel keeps playing in the small window without reloading and the player area says "Playing in Picture in Picture"; picking another channel plays it in the same window; restoring the window brings the picture back with no reload; closing the window pauses; if the engine gives up reconnecting the window closes and the error shows in the app.

### AC-25a Keep listening in the background
Given a channel playing on iPhone, iPad or Mac without Picture in Picture
When the user locks the screen, switches app or hides the window
Then the sound keeps playing for at least a minute, and a phone call or alarm pauses it and it resumes if the system says it may.

### AC-26a The channel shows on the lock screen
Given a channel playing or paused on iPhone, iPad or Mac
When the user looks at the lock screen or Control Center
Then it shows the programme title (or the channel name when there is none), a "104 Sport One" style channel line, the logo once it is cached and a live marker; play and pause there work, skip buttons are off, and the details update within five seconds of a programme or channel change.

## Edge cases

- No sources or channels: the player never appears, so nothing here applies.
- A source whose login has not synced has no channels; the "waiting for login" error appears only when the login disappears after the list loaded.
- With no guide data the panel shows 0008's guide status text in place of the programme.
- Offline with no network shows the error and waits; a dropped connection on a working network is the engine's reconnect.
- A failure while the overlay, guide or another tab is open draws the error in the player behind them.
- Changing channel while the error or the panel is shown closes both and starts fresh, without carrying the language choice over.
- Remote only: every part of the panel and the error screen is reachable by swiping.
- AirPlay is not offered for streams Antenna reads itself (not Apple's player), because their picture cannot be sent; screen mirroring still works.
- Reduce Motion: the panel, picker and error appear without sliding or fading.
- VoiceOver reads the error title and explanation once when it appears and says "Buffering" when the spinner appears.
- Large text: the error explanation wraps and the picker rows grow.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1a | core (stream line) + ui (tvOS) |
| AC-3 | core (track names) + ui (tvOS, iPhone, iPad) |
| AC-9a | ui (iPhone, iPad, macOS) + device (AirPlay) |
| AC-33 | integration (stored volume) |
| AC-16a | integration (simulated clock) + ui |
| AC-19a | integration (fake engine reconnect states) + ui |
| AC-17a | core (message table, secret scan) + ui (per platform) + integration (log scan) |
| AC-6a | integration (simulated network and keychain) + ui |
| AC-22a | integration (simulated PiP) + ui (iPhone) + device (Home gesture) |
| AC-25a | integration (simulated app and audio events) + device |
| AC-26a | integration |

## Open questions

- Holding select opens the Apple TV panel because swipe down already changes channel (0008). Swiping left or right is the alternative; changes AC-1a, decide before Accepted.
- "Try again" is shown even for a format the device cannot play, so every error has the same focused button on Apple TV. Hiding it and offering "Choose another channel" is the alternative; can be decided in the plan.
- AirPlay has no button on a narrow iPhone layout; it is in full screen and Control Center. An overflow menu is the alternative; can be decided in the plan.
- Closing Picture in Picture pauses rather than stops; with no live buffer the paused frame can be minutes old. 0019 decides what resume means.

## Notes for the plan

- The engine interface this spec assumed while 0017 was in flight is superseded by 0017. The message table maps one row to each 0017 failure reason; the "login missing" case needs 0017 to build the Xtream address from the Keychain at load time, and those parts of AC-6a and AC-17a wait for it. The copy for "Server busy", "Secure connection failed" and "No decoder free" was added in the trim and needs the owner's eye.
- Pure parts live in AntennaCore and take no URL: failure text, stream line, codec display names (h264/avc1 "H.264", hevc/hvc1/hev1 "HEVC", mpeg2video "MPEG-2", aac/mp4a "AAC", ac3 "AC-3", eac3/ec-3 "E-AC-3", others upper-cased), track display names. Player behaviour sits in a `@MainActor` `PlayerModel` in `Apps/Shared/Player/` with an injected engine, clock, `UserDefaults`, credential store, path monitor, audio session, scene phase, log sink and Now Playing sink.
- Identifiers use the `player.` prefix and follow the boards (DR-11).
- Owner's numbers: long press 0.5 s; spinner after 0.5 s, caption after 10 s; Mac volume step 0.1; buttons at least 44 pt; offline recovery fires within 1 s of the network returning; missing-login check every 5 s. The track picker is a sheet at compact width and a popover otherwise; AirPlay shows in full screen and regular width only; in full screen the error leaves only the exit-full-screen button.
- Mac volume and the pre-mute value live in `UserDefaults` under `player.volume` and `player.volume.beforeMute`, per device, not synced. No SwiftData or CloudKit field and no secret is added (ADR-0002, ADR-0003).
- Apple TV: holding select on the error acts as Try again; a single audio track is still listed rather than hidden; play/pause on the Guide and content tabs does nothing (0015 governs resume).
- `project.yml`: `UIBackgroundModes` gains `audio` on the Mobile target (0017 adds it on tvOS for PiP). Audio session `.playback` / `.moviePlayback`.
- Refinements owed to other specs: 0008 (play/pause with a failed engine retries; long press and an open panel suppress its select and swipe actions), 0010 (the extra buttons; PiP behaviour), 0015 (the play/pause button and full-screen error), 0007 and 0009 (a tune closes the error and the panel), 0006 (sign-in from the error returns to the channel).

## Dropped

- Split in earlier review rounds (kept for history): AC-1, AC-2, AC-4, AC-6, AC-8, AC-9, AC-10, AC-12, AC-13, AC-14, AC-16, AC-17, AC-19, AC-21, AC-22, AC-24, AC-25 and AC-26 were each split into lettered criteria because they held several Givens or Whens. AC-19's first version required 30 s of play before every reconnect, which made attempts 2 and 3 unreachable.
- Merged into AC-1a: AC-1b, AC-2a, AC-2b, AC-2d, AC-2e, AC-5, AC-5a, AC-29.
- Merged into AC-3: AC-4a, AC-4b, AC-10a, AC-10b, AC-10c, AC-10e, AC-11, AC-12a, AC-12b.
- Merged into AC-6a: AC-6b, AC-20, AC-21a, AC-21b.
- Merged into AC-9a: AC-9b, AC-9c, AC-13a, AC-13b, AC-13c, AC-14a, AC-14b, AC-14c.
- Merged into AC-33: AC-14d.
- Merged into AC-16a: AC-16b.
- Merged into AC-17a: AC-17b, AC-17c, AC-17e, AC-18, AC-32.
- Merged into AC-19a: AC-19b, AC-19e.
- Merged into AC-22a: AC-19d, AC-22b, AC-23, AC-24a, AC-24b.
- Merged into AC-25a: AC-25b, AC-27.
- Merged into AC-26a: AC-26b, AC-26c.
- Moved to 0017, which owns reconnecting: AC-19c, AC-20b, AC-30, AC-28.
- Moved to 0019, which owns the rewind row and skip keys: AC-8a, AC-8b, AC-8c, AC-15.
- Moved to the implementation plan: AC-1c, AC-2c, AC-7, AC-10d, AC-12c, AC-17d, AC-31.
