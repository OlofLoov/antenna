# Tasks

## 1. Overlay over the player

- [x] 1.1 Open the overlay on select over the running player without touching playback, slide in unless Reduce Motion is on, and verify with a UI test on the fake engine citing `tv-channel-overlay/the-picture-keeps-playing`
- [x] 1.2 Restore the last tuned group and highlight the playing channel with its fallbacks, and verify with a UI test citing `tv-channel-overlay/it-opens-where-the-user-left-off`
- [ ] 1.3 Check on an Apple TV 4K (3rd generation) that rows show within one second with 20 000 channels

## 2. Group and channel columns

- [x] 2.1 List Favorites, All channels, every group with its count and a Search entry, updating in place, and verify with a UI test citing `tv-channel-overlay/every-group-with-its-size`
- [x] 2.2 Show the highlighted group's channels under a heading with name and sort order, and verify with a UI test citing `tv-channel-overlay/picking-a-group-shows-its-channels`
- [x] 2.3 Build channel rows with number, logo or initials, name, current programme with progress, catch-up mark and the no-guide and loading states, and verify with a UI test citing `tv-channel-overlay/each-channel-shows-what-is-on`
- [x] 2.4 Show the empty Favorites and All channels explanations and keep focus out of the empty column, and verify with a UI test citing `tv-channel-overlay/empty-groups-tell-the-user-what-to-do`

## 3. Now-and-next panel

- [ ] 3.1 Show channel details, the current programme with times, time left, progress and description, and up to three following programmes, and verify with a UI test citing `tv-channel-overlay/now-and-next-for-the-highlighted-channel`
- [ ] 3.2 Toggle favorites from the panel button with its label and the Favorites count, and verify with an integration test citing `tv-channel-overlay/add-or-remove-a-favorite`

## 4. Tuning, closing and Search

- [ ] 4.1 Tune on select or Watch, close, show the info bar and set the channel up and down group, and verify with a UI test citing `tv-channel-overlay/select-changes-channel`
- [ ] 4.2 Close without restarting when the playing channel is selected, resuming a paused stream and reloading a failed one, and verify with a UI test citing `tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it`
- [ ] 4.3 Close on Menu without leaving the player, and verify with a UI test citing `tv-channel-overlay/menu-closes-without-changing-anything`
- [ ] 4.4 Open the Search tab ready to type from the Search entry, with Menu there not reopening the overlay, and verify with a UI test citing `tv-channel-overlay/a-way-into-search`

## 5. Verify

- [ ] 5.1 Each requirement has a test citing `tv-channel-overlay/<requirement-slug>`
- [ ] 5.2 `/opsx:verify` passes
