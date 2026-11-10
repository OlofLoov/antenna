# Tasks

## 1. Layouts

- [ ] 1.1 Build the three-column iPad and Mac layout with folding at 904 and 672 pt and the "Select a channel" state, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/sidebar-list-and-picture-side-by-side`
- [ ] 1.2 Build the iPhone and narrow Split View layout with the pinned picture, now-playing line, chips and tab bar, keeping playback across size changes, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/picture-pinned-at-the-top-on-iphone`
- [x] 1.3 Remove the iOS and macOS Channels and Favorites tabs and the separate full-screen player

## 2. Groups, list and filter

- [ ] 2.1 Show the picked group's channels with header, empty Favorites message and filter reset, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/pick-a-group`
- [ ] 2.2 Add name and number filtering with Search's matching rules in the core package, and verify with core and UI tests citing `live-tv-on-iphone-ipad-mac/type-to-narrow-the-list`
- [ ] 2.3 Check the 20 000 channel budgets on an iPhone 15 and the 50 ms filter budget in `swift test`

## 3. Playing in place

- [x] 3.1 Play a picked channel in place without restarting the playing one, and verify with a UI test on the fake engine citing `live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list`
- [ ] 3.2 Show now and next in the details and the now-playing line, refreshing when a programme ends, and verify with core and UI tests citing `live-tv-on-iphone-ipad-mac/see-what-is-on-now-and-next`
- [ ] 3.3 Show and hide the player controls and place the Picture in Picture button on iPhone and iPad, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/player-controls-when-you-want-them`
- [ ] 3.4 Enter and leave full screen from the button and iPhone rotation, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/full-screen`
- [ ] 3.5 Add the keyboard shortcuts, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/keyboard-shortcuts`

## 4. Favorites

- [ ] 4.1 Add the star that toggles a favorite and updates the group and count, and verify with integration and UI tests citing `live-tv-on-iphone-ipad-mac/star-a-channel`
- [ ] 4.2 Update the favorites sync check to look in the Favorites group, citing `favorites/favorites-sync-between-devices`

## 5. Loading and failure states

- [ ] 5.1 Show the per-source loading list, the failure banner with Retry and dismiss, the offline and empty messages, without source error text, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/sources-that-fail-are-empty-or-wait-for-a-login`
- [ ] 5.2 Load a source on its own once its credential arrives, and verify with a UI test citing `live-tv-on-iphone-ipad-mac/a-login-that-syncs-later`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `live-tv-on-iphone-ipad-mac/<requirement-slug>`
- [ ] 6.2 `/opsx:verify` passes
