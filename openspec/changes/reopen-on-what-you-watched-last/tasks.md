## 1. What was watched last

- [ ] 1.1 Add `LastWatched` to AntennaCore with its JSON form, and `LastWatchedTests`
- [ ] 1.2 Keep it in `RecentsStore` under `shell.lastWatched` per profile, add the key to the profile bases, and forget it on source deletion
- [ ] 1.3 Write `.live` from the ten-second count in `SessionTracker`, and a title from `ShelfPlayback` through its `watched` closure, set by `RootView` and `ShellView`

## 2. Reopen the title

- [ ] 2.1 Add `LaunchTitle`, `LaunchTitleRestore`, `ShelfLibrary.reopen` and `TitleModel.reopen(at:)`
- [ ] 2.2 iPhone, iPad and Mac: `LiveModel` owns the title, `restoredTab` opens its section, `launchWins(_:)`, `screenRestored(_:)` and `opened(_:)` drop it, `RootView` opens the page
- [ ] 2.3 Apple TV: `ShellModel` holds the launch tune while the title waits, `openOnLaunch` starts it, `ShellView` opens the page and tunes behind it
- [ ] 2.4 UI testing: the shelf scenario's live and shell dependencies use `UITestingRecents`
- [ ] 2.5 Unit tests in `LaunchTitleTests`, `ShelfPlaybackWatchedTests` and `ShellLaunchTitleTests`
- [ ] 2.6 UI tests in `ReopenTitleUITests` and `ReopenTitleTVUITests`: an episode, a channel, and a title that is gone

## 3. Verify

- [ ] 3.1 Each added or changed requirement has a test citing `session-restore-and-recently-watched/<slug>` or `tvos-shell/<slug>`
- [ ] 3.2 `/opsx:verify` passes
