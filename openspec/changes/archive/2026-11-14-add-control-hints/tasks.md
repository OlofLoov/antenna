# Tasks

## 1. Remote hints

- [x] 1.1 AntennaCore: `RemoteControl`, `ControlHint`, `ControlHintScreen` with its hints, corner and spoken sentence, `ControlHintSchedule`, `ControlHintsSetting`, with tests
- [x] 1.2 `ControlHints.Legend` component with previews for Live, the overlay and Movies
- [x] 1.3 `ControlHintsHost`, `.controlHints(_:)` and `.controlHintsLegend()`, on the shell window and on Settings
- [x] 1.4 One `.controlHints` per screen: the live picture, the overlay columns and panel, the guide, the tab bar, the Movies and Series section, the title page, the movie player, Settings
- [x] 1.5 "Show remote hints" row in Settings on Apple TV
- [x] 1.6 `-ui-testing-hints` and a tvOS UI test that follows the legend across screens and switches it off and on
- [x] 1.7 Boards `TV-Hints-Live`, `TV-Hints-Overlay`, `TV-Hints-Movies`, `TV-Settings-Hints`

## 2. Verify

- [x] 2.1 Each requirement has a test citing `control-hints/<requirement-slug>`
- [x] 2.2 `/opsx:verify` passes
