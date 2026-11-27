# Tasks

Ships as a stack: `feat/play-on-apple-tv-1` (groups 1 to 3, the network send), `-2` (group 4, the iCloud queue), `-3` (group 5, browsing while connected), `-4` (groups 6 and 7).

## 1. Decisions and boards

- [x] 1.1 Get the owner's answer on shipping this after v1, and on keeping Trailer while connected (design.md, one place decides where a play goes), and record both in design.md with the date
- [x] 1.2 Draw the states design.md lists as not drawn yet that groups 2 and 3 build: the Play on menu with access refused, the channel and episode context menus, the Guide details button, the error messages and the TV's banner
- [ ] 1.3 Ask Apple for the user-assigned device name entitlement for the iOS target, and on an Apple TV check what `UIDevice.current.name` returns and whether tvOS 26 shows a local network prompt for a listener; record the results in design.md
- [x] 1.4 Add to `docs/architecture/c4-container.drawio.svg` the play requests and device records on the iCloud edge and an app-to-app edge over the local network, using the drawio skill

## 2. Formats and keys in AntennaCore

- [x] 2.1 Add `PlayRequest`, its items, `PlayDeviceInfo` and the `PlayMessage` frames with versioning, and verify core tests for round trips, an unknown version and the encoded request holding no URL-shaped string
- [x] 2.2 Add the expiry rules and the numbering of TVs that share a name, and verify core tests with a fixed clock for each item kind and for two TVs called Apple TV
- [x] 2.3 Add the HKDF inputs for the link key, and verify core tests against fixed test vectors

## 3. Send over the home network

- [x] 3.1 Add the device id, the per-launch P-256 key and the `PlayDevices` zone store with its in-memory fake, written on launch and foreground and swept after 60 days, and verify integration tests against the fake
- [x] 3.2 Add `NSBonjourServices` and the new `NSLocalNetworkUsageDescription` text with its translations to all three targets in `project.yml`, and verify `scripts/check-translations.sh`
- [x] 3.3 Add the tvOS listener and the iOS and macOS browser with TLS-PSK and the framer, and verify the loopback test for `play`, `answer`, `status` and a refused identity
- [x] 3.4 Add `PlayDestination` and the Play on button and menu on the title page, channel and episode context menus and the Guide details, absent with no TV on the account, and verify UI tests against a scripted fake TV
- [x] 3.5 Add `PlayRequestInbox` on tvOS: play at once with the banner, end multi-view first, keep the request behind the paywall and "Who's watching?", run the lock and adult-content checks, answer each refusal, and verify integration tests for every `answer` result
- [x] 3.6 Stop every local engine and Picture in Picture before the first send, and verify an app test that the engine reports stopped before the frame goes out
- [x] 3.7 Start the browser only after the first tap on Play on with a TV on the account, list TVs as waiting when access is refused, and verify a UI test for the refused state
- [x] 3.8 Add a Journeys step for `iPhone-Title-PlayOn` anchored on `title.playOn.menu`

## 4. The iCloud queue

- [x] 4.1 Add the `PlayRequests` zone store with replace-on-send, delete and the expiry sweep, and its in-memory fake, and verify integration tests against the fake
- [x] 4.2 Fall back to iCloud when no endpoint answers within 3 seconds, show the sent confirmation, and verify an integration test that a request sent both ways plays once
- [x] 4.3 On tvOS, register the zone subscription and fetch on push, launch, foreground and every 30 seconds, then show the offer with focus on Play and Menu as Not now, and verify a UI test for the offer, Not now and an expired request
- [x] 4.4 Add a TV Journeys step for `TV-FromIPhone-Offer` anchored on `playOn.offer`

## 5. Browse while connected

- [x] 5.1 Draw the connected sheet, the bar on iPad and Mac and "Stopped on Living Room" before building them
- [x] 5.2 Add `PlayOnConnection` with `status`, the liveness timer, Disconnect, reconnect on foreground and the end on stop or leaving the network, and verify app tests with a scripted fake TV
- [x] 5.3 Make every play entry point call `PlayDestination`, make `AppEngine` refuse streams while connected, and verify the counting test that Live, the Guide, a title page, an episode, Search, a reminder and multi-view open no stream while connected
- [x] 5.4 Add `PlayingOnBar`, `ConnectedPicture` and the connected sheet with play, pause and "Play on this iPhone", with deterministic previews on iPhone, iPad and Mac, and verify UI tests for pause from the phone and handing a film back at the TV's position
- [x] 5.5 Remove "Add to Multi-view" while connected on iPad and Mac, and verify a UI test
- [x] 5.6 Add a Journeys step for `iPhone-Live-Connected` anchored on `playOn.live`

## 6. Accessibility and copy

- [ ] 6.1 Label the bar, the connected picture, the menu rows and the TV's offer for VoiceOver, and verify UI tests on iOS and tvOS
- [ ] 6.2 Run `scripts/sync-strings.sh` and translate the new strings in every language in `Config/languages`, and verify `scripts/check-translations.sh`

## 7. Verify

- [ ] 7.1 Each requirement in `play-on-apple-tv` has a test citing `play-on-apple-tv/<requirement-slug>`
- [ ] 7.2 Run the device checklist in design.md's Testing section on an iPhone and an Apple TV on one account, and record the tap-to-tune times and results in design.md
- [ ] 7.3 `/opsx:verify` passes
