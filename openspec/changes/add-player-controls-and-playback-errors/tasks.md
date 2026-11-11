# Tasks

## 1. Core text

- [x] 1.1 Add the stream line, codec names and track names to AntennaCore, and verify with core tests citing `player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv` and `player-controls-and-playback-errors/choose-audio-and-subtitles`
- [x] 1.2 Add the failure message table with a secret scan over every string, and verify with core and integration log-scan tests citing `player-controls-and-playback-errors/error-messages-for-each-reason`

## 2. Player model

- [ ] 2.1 Build the player model with injected engine, clock, defaults, credential store, path monitor, audio session, scene phase and sinks
- [x] 2.2 Show the spinner after 0.5 s and the slow-source caption after 10 s, and verify with integration and UI tests citing `player-controls-and-playback-errors/a-spinner-while-waiting-and-a-reason-if-it-is-slow`
- [x] 2.3 Show the reconnect count from the engine and the error only on give-up, and verify with integration and UI tests citing `player-controls-and-playback-errors/a-dropped-stream-shows-that-it-is-reconnecting`
- [x] 2.4 Retry on Try again, on network return and on login arrival, with Sign in on Apple TV, and verify with integration and UI tests citing `player-controls-and-playback-errors/try-again-or-recover-on-its-own`

## 3. Error screen

- [x] 3.1 Build the error screen on each platform, closing panels, pickers and PiP first, and verify with UI tests citing `player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong`

## 4. Apple TV panel and track pickers

- [x] 4.1 Open the info panel on a long press with Info, Audio and Subtitles tabs, swallowing swipes and play/pause, and verify with a tvOS UI test citing `player-controls-and-playback-errors/see-what-s-on-without-stopping-the-picture-on-apple-tv`
- [x] 4.2 Build the track pickers on every platform with the grayed-out rule, and verify with UI tests citing `player-controls-and-playback-errors/choose-audio-and-subtitles`

## 5. iPhone, iPad and Mac controls

- [ ] 5.1 Add the audio-and-subtitles, AirPlay, mute and volume controls and the Mac keys, and verify with UI and device tests citing `player-controls-and-playback-errors/extra-buttons-on-iphone-ipad-and-mac`
  - Open: built and tested on simulators; the AirPlay hand-off to a real device, "Playing on AirPlay" on a real route and the Mac's M and Command-Up/Down keys need a device or a Mac UI test target
- [x] 5.2 Store the Mac volume per device, and verify with an integration test citing `player-controls-and-playback-errors/the-mac-remembers-its-volume`

## 6. Background, PiP and lock screen

- [ ] 6.1 Add Picture in Picture entry, channel change, restore and close, and verify with integration, UI and device tests citing `player-controls-and-playback-errors/picture-in-picture-on-iphone-and-ipad`
- [ ] 6.2 Add the background audio mode and interruption handling, and verify with integration and device tests citing `player-controls-and-playback-errors/keep-listening-in-the-background`
- [ ] 6.3 Publish Now Playing info with play and pause only, and verify with an integration test citing `player-controls-and-playback-errors/the-channel-shows-on-the-lock-screen`

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `player-controls-and-playback-errors/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
