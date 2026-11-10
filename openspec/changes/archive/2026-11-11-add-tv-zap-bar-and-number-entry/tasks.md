# Tasks

## 1. Formatting in the core package

- [x] 1.1 Add remaining-time text, progress fraction, resolution and audio badge functions to AntennaCore, and verify with core tests citing `tv-zap-bar-and-number-entry/what-is-on-and-what-is-next` and `tv-zap-bar-and-number-entry/picture-and-sound-quality`

## 2. Showing and hiding the bar

- [x] 2.1 Show the bar on every channel change and hide it five seconds after the last one, and verify with a UI test citing `tv-zap-bar-and-number-entry/the-bar-appears-on-every-channel-change`
- [x] 2.2 Show the bar on play/pause in full-screen live TV, dropping half-typed digits, and verify with a UI test citing `tv-zap-bar-and-number-entry/play-pause-shows-the-bar`
- [x] 2.3 Hide the bar on Menu without leaving the player, consume select to open the overlay, and verify with a UI test citing `tv-zap-bar-and-number-entry/menu-hides-the-bar`

## 3. Bar content

- [x] 3.1 Show logo or initials, number, name, and group with position or the Favorites and All channels names, and verify with a UI test citing `tv-zap-bar-and-number-entry/which-channel-this-is`
- [x] 3.2 Show current and next programme, progress and time left, with the no-programme, loading and unavailable wording, and verify with a UI test citing `tv-zap-bar-and-number-entry/what-is-on-and-what-is-next`
- [x] 3.3 Show the LIVE, picture and sound badges from the engine's state, absent while buffering, and verify with a UI test on a fake engine citing `tv-zap-bar-and-number-entry/picture-and-sound-quality`
- [x] 3.4 Show the catch-up footer or the browse hint, and verify with a UI test citing `tv-zap-bar-and-number-entry/catch-up-hint`

## 4. Channel up and down

- [x] 4.1 Track the current group, step through it with wrap-round on swipe, and verify with a UI test citing `tv-zap-bar-and-number-entry/swipe-up-and-down-to-change-channel`

## 5. Number entry

- [x] 5.1 Build the number entry model with injected key events and clock, show the box with the matching name, and verify with an integration test citing `tv-zap-bar-and-number-entry/typing-a-number-shows-the-match`
- [x] 5.2 Tune after two seconds or on Return or select, and verify with an integration test citing `tv-zap-bar-and-number-entry/the-typed-channel-tunes`
- [x] 5.3 Show "No channel n" for one second when nothing matches, and verify with an integration test citing `tv-zap-bar-and-number-entry/no-channel-with-that-number`
- [x] 5.4 Handle Backspace, Menu and Escape, and verify with an integration test citing `tv-zap-bar-and-number-entry/correct-or-cancel-a-number`

## 6. Verify

- [x] 6.1 Each requirement has a test citing `tv-zap-bar-and-number-entry/<requirement-slug>`
- [x] 6.2 `/opsx:verify` passes
