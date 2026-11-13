## 1. Proposal and movie player tracks

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate close-platform-parity-gaps --strict`
- [x] 1.2 Add `iPhone-Title-Player-Tracks`, `iPad-Title-Player-Tracks` and `TV-Title-Player-Tracks`
- [x] 1.3 Add `TitleTracks` and make `ShelfPlayback` follow a title's tracks, with app tests citing `player-controls-and-playback-errors/choose-audio-and-subtitles-in-a-movie-or-episode`
- [x] 1.4 Add the tracks and subtitles buttons with the sheet and popover to `ShelfPlayerView` on iPhone, iPad and Mac
- [x] 1.5 Add the Audio and Subtitles panel to the Apple TV movie player, opened by holding select, closed by Menu
- [x] 1.6 UI tests on iPhone and Apple TV: open the list in a movie, pick a track

## 2. Multi-view on iPad

- [x] 2.1 Rename `MultiViewMacScreen` to `MultiViewGridScreen`, build it on iOS, and drop the minimum width on iPad
- [x] 2.2 Offer Add to Multi-view and Command-Shift-M on iPad in the regular size class, and leave multi-view when the window turns compact, with app tests citing `multi-view/start-multi-view-on-an-ipad`
- [x] 2.3 Note iPad on `iPad-MultiView`
- [x] 2.4 UI test on iPad: add a channel from the list's menu, tap a tile

## 3. Picture in Picture and the clipboard on Mac

- [ ] 3.1 Create the Picture in Picture controller on macOS for both engines and watch it with `PictureInPictureWatch`
- [ ] 3.2 Add the Picture in Picture button to the Mac controls and mark it on `iPad-Player`, citing `player-controls-and-playback-errors/picture-in-picture-on-a-mac`
- [ ] 3.3 Add `Clipboard.system` on macOS with pattern detection, citing `first-run-onboarding/fill-the-form-from-a-copied-link`

## 4. Apple TV: Search bell, Guide sources filter, Trailer

- [ ] 4.1 Show the bell on later programmes in Search on Apple TV, update `TV-Search`, and add a UI test citing `programme-reminders/remind-me-appears-only-before-a-programme-starts`
- [ ] 4.2 Add `.searchable` to the Guide sources channel list on Apple TV, update `TV-GuideSources`, and add a UI test citing `guide-sources-and-channel-mapping/find-the-channels-without-a-guide`
- [ ] 4.3 Add `TrailerLink.playsInApp` with core tests citing `title-detail-and-episode-picker/trailer`
- [ ] 4.4 Add the trailer target to `ShelfPlayback` and the Trailer button to the Apple TV title page, update `TV-Title`, with an app test citing `title-detail-and-episode-picker/trailer`

## 5. Filter on iPhone

- [ ] 5.1 Add the pull-down search field to the iPhone guide, update `iPhone-Guide`, and add a UI test citing `guide-on-iphone-ipad-and-mac/filter-channels-by-typing`

## 6. Verify

- [ ] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 6.2 `/opsx:verify` passes
