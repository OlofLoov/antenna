## 1. The last channel first

- [ ] 1.1 `SeenChannelsStore.tagging` only tags; `LiveModel` and `ShellModel` tune, then record the seen memory in a following task and rebuild the catalogue when it lands, with a test that the replay runs before the record
- [ ] 1.2 A source whose channels did not change since the last load keeps its list and skips the rebuild; the restored channel is found through a dictionary, with a test

## 2. Large guides

- [ ] 2.1 `GuideLimits` gains the window and the kept caps, and the byte limits rise; `SourceGuide.Builder` drops programmes outside the window and past the caps, other ids first, with core tests
- [ ] 2.2 `GuideEngine` hands the source's named guide ids to the fetch, with a test that a guide past the old limit loads

## 3. Name matching

- [ ] 3.1 `GuideEngine` matches by name only when the channels, the guides or the hand-picked entries change, not on each progress event, with a test

## 4. Clock ticks

- [ ] 4.1 The iPhone and iPad Guide ticks per row and per header, with a test that a tick does not rebuild the row list
- [ ] 4.2 The Apple TV overlay ticks per row; check memory and the opening scroll on a tvOS simulator with 50 000 channels and record it here

## 5. Logos

- [ ] 5.1 `LogoCache` lets a cancelled row return at once and cancels the download when no row waits, without marking the logo failed, with a test

## 6. Recents and the Live list

- [ ] 6.1 A change to Recents or Favorites leaves the open group's rows alone unless the group is Recents or Favorites, with a test

## 7. HLS zaps

- [ ] 7.1 `AVPlayerEngine` opens an `.m3u8` address without the probe and runs the probe only to explain a failure, with a test

## 8. Verify

- [ ] 8.1 Each requirement this change adds or modifies has a test citing `<capability>/<requirement-slug>`
- [ ] 8.2 Before and after figures at 50 000 and 100 000 channels are recorded in design.md
- [ ] 8.3 The touched UI test classes pass on a local simulator
- [ ] 8.4 /opsx:verify passes
