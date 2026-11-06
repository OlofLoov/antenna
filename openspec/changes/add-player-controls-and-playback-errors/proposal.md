# Proposal

## Why

Today the player is Apple's stock video view with its own controls, and a failed stream leaves a blank screen. The user cannot tell whether the channel is gone, the internet dropped, the login has not synced yet, or the device cannot play the format. The zap bar, Live on iPhone, iPad and Mac, and the tvOS shell placed their buttons and left buffering, errors, language choice, Picture in Picture and background audio to this change.

User stories served:
- "As a user, I want my passwords kept private, so a synced device or a log never shows them in plain text."
- "As a viewer, I want to see what is on now and next without leaving the picture, so I can decide whether to stay."
- "As a viewer, I want simple player controls (pause, audio track, subtitles, programme info) and a clear message when a stream fails, so I know what happened and what to try."

Not reviewed yet.

## What Changes

- Apple TV gets an info panel opened by holding select, with Info, Audio and Subtitles tabs, closed with Menu.
- iPhone, iPad and Mac get an audio-and-subtitles button with a picker, an AirPlay button, and on Mac a volume slider, mute and volume keys.
- Every platform gets a buffering spinner, the engine's reconnect count while it reconnects, an error screen with a plain reason and "Try again", and recovery on its own when the network or login comes back.
- A one-line description of the stream format ("MPEG-TS · H.264 1080p · AAC 5.1").
- Picture in Picture on iPhone and iPad, including on leaving the app; background audio; lock-screen and Control Center playback info; pausing for phone calls.

Out of scope:
- How streams are played, what failures are detected, which tracks exist, and when to reconnect (`playback-engine`).
- Pausing and rewinding live TV, its Apple TV rewind row and the keyboard skip keys.
- Movie and episode player screens (scrub bar, resume, back to the card).
- Catch-up and start over.
- The zap bar, channel number entry and format badges in full-screen live.
- Where play/pause, progress, LIVE, PiP and full screen sit on iPhone, iPad and Mac.
- Remembering a preferred language across channels, and a background-audio switch.
- Picture in Picture on Mac and Apple TV.
- Several channels at once.
- Recording.

## Capabilities

### New Capabilities
- `player-controls-and-playback-errors`: the info panel, track pickers, AirPlay and volume, buffering and reconnect feedback, plain error messages with Try again, Picture in Picture, background audio and lock-screen info.

### Modified Capabilities
None.

## Impact

- A player model shared by every platform and the Mobile target's background audio mode.
- Refines the zap bar (play/pause retries a failed stream; long press and an open panel suppress its select and swipe), Live on iPhone, iPad and Mac (the extra buttons and PiP), the tvOS shell (the play/pause button and full-screen error), the channel overlay and guide grid (a tune closes the error and the panel), and onboarding (sign-in from the error returns to the channel).
- Depends on: `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, change `add-playback-engine`, change `add-first-run-onboarding`, change `add-tv-channel-overlay`, change `add-tv-zap-bar-and-number-entry`, change `add-tv-guide-grid`, change `add-live-tv-on-iphone-ipad-mac`.
