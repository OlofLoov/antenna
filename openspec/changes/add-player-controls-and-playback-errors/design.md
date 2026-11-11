# Design

## Context

See proposal.md for why. The controls sit on top of change `add-playback-engine`, which decides how streams play, what failures exist, which tracks a stream has and when to reconnect.

Boards, under `openspec/specs/design-system/boards/`: `TV-Player.dc.html`, `TV-Player-Tracks.dc.html`, `TV-Player-Error.dc.html`, `TV-Player-Buffering.dc.html`, `iPad-Player.dc.html`, `iPad-Player-Tracks.dc.html`, `iPad-Player-Error.dc.html`, `iPhone-Player.dc.html`, `iPhone-Player-Tracks.dc.html`, `iPhone-Player-Error.dc.html`.

Not drawn: the Apple TV Subtitles tab and its "No subtitles in this stream" row; the Info tab without guide data; the reconnecting caption; the spinner on iPhone, iPad and Mac; the Picture in Picture and AirPlay placeholders; the iPhone full-screen controls; the error in full screen on iPhone, iPad and Mac; the grayed tracks button; the Apple TV "Sign in" button on the error; the error with the zap bar showing. Each is a variant of a drawn board with the same geometry.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “A current programme always shows its progress”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”, “Loading shows real progress per step”.

On Apple TV, holding select slides a panel down over the top of the playing picture; right moves to Audio or Subtitles; the panel stays until Menu. A failed stream is replaced by the reason and a focused "Try again", and swiping up or down still changes channel.

On iPhone, iPad and Mac a speech-bubble button opens Audio and Subtitles with a footer naming the stream format. AirPlay appears when the stream can be sent. On Mac a speaker button and slider set the volume. Leaving the app on iPhone or iPad continues in Picture in Picture, or as audio with the channel on the lock screen.

## Goals / Non-Goals

**Goals:**
- Every user-facing failure text comes from one table keyed by the engine's reasons, built without any URL.

**Non-Goals:**
- A preferred language across channels and a background-audio switch, which belong to a settings change.
- Picture in Picture on Mac and Apple TV.

## Decisions

- The engine contract is the one from change `add-playback-engine`. The message table has one row per engine failure reason. The login-missing case needs the engine to build the Xtream address from the Keychain at load time, and that part of the recovery and error requirements waits for it. The copy for "Server busy", "Secure connection failed" and "No decoder free" was added in a trim and needs the owner's review.
- Pure parts live in AntennaCore and take no URL: failure text, stream line, codec display names (h264/avc1 "H.264", hevc/hvc1/hev1 "HEVC", mpeg2video "MPEG-2", aac/mp4a "AAC", ac3 "AC-3", eac3/ec-3 "E-AC-3", others upper-cased), and track display names.
- Player behavior sits in a `@MainActor` `PlayerModel` in `Apps/Shared/Player/` with an injected engine, clock, `UserDefaults`, credential store, path monitor, audio session, scene phase, log sink and Now Playing sink.
- Identifiers use the `player.` prefix and follow the boards (“Accessibility identifiers follow the board”).
- Numbers: long press 0.5 s; spinner after 0.5 s, caption after 10 s; Mac volume step 0.1; buttons at least 44 pt; offline recovery fires within 1 s of the network returning; missing-login check every 5 s.
- The track picker is a sheet at compact width and a popover otherwise. AirPlay shows in full screen and regular width only. In full screen the error leaves only the exit-full-screen button.
- Mac volume and the pre-mute value live in `UserDefaults` under `player.volume` and `player.volume.beforeMute`, per device, not synced. No SwiftData or CloudKit field and no secret is added.
- Apple TV: holding select on the error acts as Try again; a single audio track is still listed rather than hidden; play/pause on the Guide and content tabs does nothing (the shell governs resume).
- `project.yml`: `UIBackgroundModes` gains `audio` on the Mobile target (the engine change adds it on tvOS for PiP). Audio session `.playback` / `.moviePlayback`.
- The panel opens on a long press of select, because a swipe down already changes channel in the zap bar.
- Test layers: the stream line, track names and message table run as core tests with a secret scan; spinner, reconnect and recovery run as integration tests on a fake engine and simulated clock, network and keychain; each platform has UI tests; AirPlay, the Home gesture and background audio run on device.

## Risks / Trade-offs

- [Several error strings have not had the owner's review] → flagged above; review before implementation.
- Open question: holding select opens the Apple TV panel because swipe down already changes channel. Swiping left or right is the alternative and would change the Apple TV panel requirement; decide before review.
- Open question: "Try again" is shown even for a format the device cannot play, so every error has the same focused button on Apple TV. Hiding it and offering "Choose another channel" is the alternative. Can be decided during implementation.
- Open question: AirPlay has no button on a narrow iPhone layout; it is in full screen and Control Center. An overflow menu is the alternative. Can be decided during implementation.
- Open question: closing Picture in Picture pauses rather than stops. With no live buffer the paused frame can be minutes old. Change `add-timeshift-catch-up-and-start-over` decides what resume means.

## Implementation decisions

Made while building, without a review round. Each names what was picked and why.

- `PlayerModel` does not load streams. `LiveModel` and `ShellModel` keep tuning, tell it about each tune with `tuned(_:)`, and hand it `reload` (load the same channel without counting as a channel change) and `hasLogin`. Moving loading into the player model would have rewritten the launch tune, the last-channel store and the language picks of two finished changes for no visible gain.
- Try again shows the spinner at once instead of after half a second, so the press has a visible answer.
- The slow-source line comes ten seconds after the spinner appears, as the "spinner has shown for ten seconds" scenario reads, so 10.5 seconds after waiting starts.
- While the engine reconnects, the count replaces the ring entirely, as "in place of the spinner" reads; the board draws it in the caption's position and style.
- Recovery after an offline error waits for the connection to go and come back. Reloading whenever the system reports a connection would loop when the system says online and the server still fails the same way.
- No engine reports a missing login yet: a source whose login has not arrived never loads its channels, so nothing plays. The model, its five-second check and the messages are built and tested on a scripted engine; they take effect once the engine builds the Xtream address from the Keychain at load time, as Decisions says.
- Spec conflict: "Provider error" reads "Acme TV returned <code>", but the engine's server-error reason in change `add-playback-engine` carries no status code. The message says "returned a server error" until the engine passes the code on. The other change's spec is left as it is.
- The Apple TV shell numbers the channel in player messages by the playlist's own number, since the catalogue number lives in the shell's view; the info panel reads the catalogue number.
- UI tests script the player with `UITESTING_PLAYBACK` (`stall`, `reconnect`, `fail-<reason>`), `UITESTING_SLOW_SECONDS` and `UITESTING_NETWORK_SECONDS`, read by the Debug engines of `UITestingLive` and `UITestingShell`.
