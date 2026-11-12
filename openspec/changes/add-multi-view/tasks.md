# Tasks

## 1. Playback engine support

- [x] 1.1 Add muted start and mute without reload to the engine, and verify a test that switches sound between two fake engines never has both unmuted
- [x] 1.2 Add the 1080p cap and the option to leave the TV's display mode alone, and verify an integration test reads both back while tiles play
- [x] 1.3 Add the "no decoder free" reason and the no-retry rule for 503 and 509 while another tile on the same source plays, and verify engine tests for both

## 2. Session model in AntennaCore

- [x] 2.1 Add the capacity table and the session cap that drops after a decoder refusal, and verify tests for Apple TV HD, Intel Mac, 4K and the drop
- [x] 2.2 Add the layout rule for two to four tiles on both containers, and verify tests against the worked frames
- [x] 2.3 Add the session that applies start, add, change, remove, enlarge and leave and returns ordered commands, and verify a test per action
- [x] 2.4 Add the failure text for a refused stream, a 403 and a busy decoder, and verify tests for each wording

## 3. Apple TV

- [x] 3.1 Add "Add to multi-view" to the overlay and the two-tile start, and verify a UI test with fake engines for the start and for each case where the option is hidden
- [x] 3.2 Move sound with focus and make swipes, number entry and play/pause inert, and verify with fake engine logs
- [x] 3.3 Add pick mode for changing a tile and "Add as new tile", and verify UI tests for change, add, the full limit and duplicates
- [x] 3.4 Add tile actions, full screen and back, remove and leave, and verify UI tests including VoiceOver actions
- [x] 3.5 Add per-tile loading and failure states and the pause on background, and verify UI and lifecycle tests

## 4. Mac

- [ ] 4.1 Add the right-click item and Command-Shift-M, the folded sidebar and the 1024 pt minimum width, and verify a macOS UI test and an iOS test that the option is absent
  - Open: built, and the menu rules and the iOS absence are tested on the shared model; there is no macOS UI test target, and this Mac runs macOS 15.6, below the app's 26.0 target, so the window cannot be driven here
- [ ] 4.2 Add selection by click and Command-1 to 4, the list that fills the selected tile, double-click to enlarge, remove and exit, and verify macOS UI tests
  - Open: built, and the list filling the tile, the limit and exit are tested on the shared model; clicks, keys and the window need a macOS UI test target and a Mac on macOS 26
- [x] 4.3 Make Now Playing follow the selected tile and keep tiles playing in the background, and verify integration tests

## 5. Shell

- [x] 5.1 Host multi-view in the Apple TV shell and keep the surviving tile's player on leave, and verify a UI test that the tab bar stays hidden

## 6. Hardware

- [ ] 6.1 Run four tiles for 30 minutes with 20 sound changes on each Apple TV 4K generation and an M1 Mac against the fixture server, and record the signpost log
  - Open: needs the hardware; the "tile audible" signpost is in place

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
  - Open: every requirement but `multi-view/four-tiles-hold-up-on-real-hardware` is cited; that one is the device run in 6.1
- [ ] 7.2 `/opsx:verify` passes
  - Open: waits for 4.1, 4.2 and 6.1, which need a Mac on macOS 26 and the hardware
