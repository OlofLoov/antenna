# Tasks

## 1. Store and tracker in AntennaCore

- [x] 1.1 Add the on-device store for recents, the session and the last channel with the 20-entry newest-first rule, and verify core tests for move-to-top, overflow and damaged data
- [x] 1.2 Refuse channel ids that contain a stream link, and verify a core test that such a channel is neither listed nor saved while an Xtream channel is
- [x] 1.3 Add the session tracker with the ten-second count and its cancel rules, and verify an integration test for each interruption

## 2. Source deletion

- [ ] 2.1 Add the source observer that clears a deleted source's recents, session group and last channel, and verify core and integration tests for local and remote deletions

## 3. Catalogue

- [x] 3.1 Add the Recents group between Favorites and All channels and its replace-without-rebuild path, and verify core tests for order, absence when empty, ambiguous ids and the 20 ms bound

## 4. Recents on screen

- [ ] 4.1 Show Recents in the iPhone chips, the iPad and Mac sidebar and the Apple TV overlay, and verify UI tests for order, hiding and the VoiceOver label
- [ ] 4.2 Keep an open Recents list in place while playing from it, and verify a UI test
- [ ] 4.3 Keep the current group on Apple TV when playing from Recents, and verify a UI test that up and down still step through it

## 5. Restore on iPhone, iPad and Mac

- [ ] 5.1 Restore the tab and the user-picked group with the fallbacks, and verify UI tests including a missing and a late group
- [ ] 5.2 Start sources at the app root and replay the last channel once its source loads, and verify UI tests for success, offline retry and a missing channel
- [ ] 5.3 Restore after the system closes the app in the background, and verify a UI test that terminates the app

## 6. Apple TV swipes and shell

- [ ] 6.1 Add swipe left for the previous channel and swipe right for the overlay on Recents, and verify UI tests including no other channel and no Recents
- [ ] 6.2 Read the shell's last channel from the shared store, and verify the existing shell launch test still passes with the debug mirror file

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
