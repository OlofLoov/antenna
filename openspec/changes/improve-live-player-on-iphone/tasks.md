# Tasks

## 1. Sideways full screen and the phone layout (PR 1)

- [ ] 1.1 Keep every iPhone on the tab bar layout with a compact size class below the root, and verify `LiveRegularUITests` still pass on an iPad simulator
- [ ] 1.2 Derive full screen from the tab, the vertical size class, the device and the playing channel, and verify `LivePlayerUITests` for turning sideways then picking a channel, launching sideways, returning to Live sideways and exiting sideways on iPhone 17 and iPhone 17 Pro Max
- [ ] 1.3 Draw the channel line at the top of the full-screen picture with the controls, update `iPhone-FullScreen`, add previews, and verify a UI test that the line hides with the controls and comes back on a tap

## 2. Gestures and Previous channel (PR 2)

- [ ] 2.1 Add the list step in AntennaCore with wrapping and the All channels fallback, and verify swift-testing tests
- [ ] 2.2 Add swipe up and down on the picture and the Channel up and Channel down actions, and verify a UI test that swipes both ways in full screen
- [ ] 2.3 Add Previous channel with the last-switch memory and the Recents fallback, update `iPhone-Player` and `iPhone-FullScreen`, add previews, and verify a UI test that flips between two channels
- [ ] 2.4 Add double-tap skips of 15 seconds with the notes for no rewind and already live, and verify `TimeshiftUITests` for a skip back and a note on a channel that cannot rewind

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `live-tv-on-iphone-ipad-mac/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 3.2 `/opsx:verify` passes

## Workflow follow-up

- Archive the change in PR 2.
