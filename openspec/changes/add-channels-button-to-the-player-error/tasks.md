## 1. Channels on the error

- [x] 1.1 Add `PlayerStatusText.channels` to AntennaCore with a test in every language
- [x] 1.2 Add `UITESTING_FAIL_ONLY` to `UITestingPlayback`
- [x] 1.3 iPhone, iPad and Mac: `openChannelGroups` set by `LiveCompactView` and `LiveRegularView`, read by `LivePicture`; the Groups sheet state moves out of `LiveGroupButton`
- [x] 1.4 Apple TV: `ShellFocus.channels`, the button in `PlayerTVFailure`, the overlay opened on the current group, the error's buttons disabled under the overlay
- [x] 1.5 Update the boards `TV-Player-Error`, `iPhone-Player-Error` and `iPad-Player-Error`, and the error previews
- [x] 1.6 UI tests in `PlayerErrorUITests` and `PlayerErrorTVUITests`

## 2. Verify

- [x] 2.1 Each changed requirement has a test citing `player-controls-and-playback-errors/a-failed-stream-says-what-went-wrong` or `player-controls-and-playback-errors/go-to-another-group-from-the-error`
- [x] 2.2 `/opsx:verify` passes
