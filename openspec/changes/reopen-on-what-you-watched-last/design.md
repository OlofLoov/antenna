# Design

## Context

See proposal.md for why. What exists on 2026-11-23:

- `RecentsStore` keeps, per profile and in `UserDefaults`, the last channel
  (`shell.lastChannel`), the recents and the iPhone, iPad and Mac session
  (tab and group). `SessionTracker.remember` writes the last channel once a
  stream loads; its ten-second count adds a channel to Recents.
- iPhone, iPad and Mac: `CompactTabs` and `LiveRegularView` pick the tab or
  section from `LiveModel.restoredTab` at their first appearance, then let
  onboarding's Browse movies and a launch screen other than Live win, and
  call `LiveModel.screenRestored(onLive:)`.
- Apple TV: `ShellView` builds `ShellModel`, holds a Top Shelf link
  (`holdShelfItem`) or applies onboarding's handoff, else calls
  `openOnLaunch`, which opens the launch screen from Preferences. The launch
  tune (`considerTune`) waits while a shelf link is held and gives up on the
  last channel after `launchDeadline`, 10 seconds.
- `ShelfLibrary.openPage` opens a title page over its section; the section
  screens on every platform show `library.top` when its section matches.
  `TitleModel.pickedSeason` picks the season; nil follows Play's target.
- `ShelfPlayback` plays movies and episodes for every platform and saves
  their progress through `ShelfActivity`. It knows no profile.

## Boards

No new screen. The restored page is the title page as drawn in `TV-Title`,
`iPhone-Title` and `iPad-Title`, over the section in `TV-Movies`,
`TV-Series`, `iPhone-Movies`, `iPhone-Series`, `iPad-Movies` and
`iPad-Series`. It follows the design-system requirements those screens
already follow; nothing new is drawn.

## Decisions

### 1. What counts as watched last

Options:
- **The newest of the last channel and the newest saved progress.** No new
  value to store, but progress syncs, so a movie watched on the iPad would
  open on the Apple TV, and the owner asked for per-device.
- **Whatever loaded last**: a channel when its stream loads, a title when
  it starts. Simple, but Apple TV loads the last channel behind the title
  page at launch (decision 4), and iPad tunes it behind Movies once the
  list arrives. Each of those loads would overwrite the title, so the next
  launch would never reopen it.
- **A channel after its ten-second count, a title once it starts playing**
  (chosen). The count already ignores a channel paused behind Movies or a
  title page, so the loads above leave the title in place. A channel the
  user zaps past in under ten seconds does not count, as for Recents. A
  title counts at once: the user pressed Play or Resume on it.

The value is `LastWatched` (AntennaCore, `Recents/LastWatched.swift`): a
`Title?` holding the source id, title id, kind (movie or series) and, for an
episode, the episode id. Nil means a channel. It is stored as JSON under
`shell.lastWatched` per profile, next to `shell.lastChannel`, and added to
`RecentsStore.bases` and `ProfileKeys.bases` so profile pruning covers it.
An id containing `://` is not stored, as for `LastChannelKey`; no current
source puts a link in a title id. A value that cannot be read counts as a
channel.

Writers:
- `SessionTracker` writes `.live` when the count completes, on every
  platform.
- `ShelfPlayback` calls its `watched` closure once a movie or episode has
  loaded and play was asked, including episodes from Up next and titles
  started by a Top Shelf link or Siri. A trailer does not call it. The
  roots (`RootView`, `ShellView`) set the closure to write to the profile's
  `RecentsStore`, since `ShelfPlayback` knows no profile.

`RecentsStore.remove(source:)` deletes the value when its title belongs to
the deleted source, for every profile, in the same place the last channel
is cleared.

### 2. Waiting for the title: `LaunchTitle`

One `@Observable` class, `LaunchTitle` (Apps, `Views/Shelf/LaunchTitle.swift`),
holds the title from launch until it opens or is dropped, on every platform:

- `waiting`: the key while the section has not listed it.
- `holds`: true from launch until the page opened or the title was dropped.
- `resolve(in: ShelfLibrary)`: returns the title once its section lists it;
  drops the key when the section has finished loading its source without it
  (loaded without the title, failed, offline or waiting for its login).
  While the section has not opened or the source row is missing it waits.
- `start(sleep:)`: the 10-second deadline, `ShellModel.launchDeadline`;
  past it the key drops.
- `drop()` and `opened()`; `dropped` runs on a drop so Apple TV can tune.

`LaunchTitleRestore`, a view modifier, opens both sections' sources
(`library.open()`) while the key waits and calls `resolve` whenever a
section's sources or index change. A found title goes to the caller's
`open` closure, which calls `ShelfLibrary.reopen(_:episode:)`:
`openPage(title, from: .banner, in: kind)` plus `TitleModel.reopen(at:)`.
The banner origin makes Back behave as for More info on the banner: the
section shows its rows and on Apple TV focus goes to the banner.

`TitleModel.reopen(at:)` sets `pickedSeason` to the episode's season once
the episode list is known (at once when the answer was kept, else when the
info call lands). It does not set `lastPlayed`, which scrolls the episode
into view and would move Resume off screen. Options considered for the
season: following Play's target (today's rule when the page opens by hand)
or the episode's season (chosen, as the owner asked). They differ only when
the episode was finished and the next one is in another season; the page
then looks as it does after coming back from playback.

### 3. iPhone, iPad and Mac

`LiveModel` owns a `LaunchTitle` built from the store at init.
`restoredTab` answers Movies or Series while it holds a title, so the
existing first-appearance code opens that tab. Browse movies and a launch
screen other than Live still win, through `launchWins(_:)`, which drops the
title when either picks a screen. `screenRestored(_ tab:)`, which the two
layouts now call with the picked tab, drops the title when the tab is not
its section and otherwise starts the deadline on `launchSleep`, a new
dependency kept apart from `sleep` because the UI tests shorten every
10-second wait on `sleep` as the Recents count. `opened(_:)` drops the
title when the user opens another tab. `RootView` applies
`LaunchTitleRestore` with an `open` that drops the title when a page is
already open.

A section the sources do not offer maps to Live, as today, and drops the
title.

### 4. Apple TV

`ShellModel` owns a `LaunchTitle`, empty until `openOnLaunch`. In
`openOnLaunch`, when no shelf link is held and the launch screen is Live,
it reads the profile's `LastWatched` and, for a title, starts the wait.
While it holds, `considerTune` returns early, as for a shelf link, so the
last channel does not start full screen and then vanish behind a page.

Options for the channel after the page opens:
- **Tune nothing until Live opens.** Nothing loads in the background, but
  Live would need its own path to start the last channel, with the deadline
  restarted and the 10 seconds measured from a different point.
- **Tune it behind the page** (chosen). After the Movies or Series tab has
  opened, `considerTune` runs as at any launch. The load lands behind
  content, so the existing hold pauses it and stops it after 30 seconds,
  as for the Movies launch screen today, and Live resumes it.

On a drop, `dropped` calls `considerTune`, and the last channel or the first
channel plays full screen as today. Choosing a tab in the bar drops the
title. `ShellView` applies `LaunchTitleRestore`; its `open` reopens the
page and calls `launchTitleOpened(in:)`, which awaits `select(.movies)` or
`select(.series)`, then calls `opened()` and `considerTune()`.

Precedence: a shelf link at launch skips the wait. Onboarding's handoff
skips `openOnLaunch` already. A launch screen other than Live keeps its
behaviour.

### 5. UI tests

`UITestingShelf.liveDependencies` and, on Apple TV, the shell's
dependencies under `-ui-testing-shelf` use `UITestingRecents.store` and its
sleep, so `-ui-testing-keep-session` carries what was watched last across a
relaunch and nothing leaks into other tests. The `watching` scenario seeds
Harbor Watch's first episode at 30 % on every launch, so the relaunched
page has a position to resume. Passing `-ui-testing-shelf empty` on the
second launch removes the title for the fallback test.

## Tests

- AntennaCore `LastWatchedTests`: JSON round trip, a damaged value, refused
  ids with a link, the episode kept for a series.
- Apps `LaunchTitleTests`: the found title, a source that loads without it,
  a failed source, the deadline, another tab dropping it, the season of the
  episode, the write from the ten-second count, a damaged value and the
  source deletion that forgets it. `ShelfPlaybackWatchedTests`: a movie and
  an episode write themselves, a trailer writes nothing.
- TV `ShellLaunchTitleTests`: the launch tune waits while the title waits,
  plays the last channel on a drop, at the deadline and after a tab is
  chosen, and loads behind the page once it opens; a shelf link skips the
  wait.
- UI: `ReopenTitleUITests` (iPhone) and `ReopenTitleTVUITests` (Apple TV)
  relaunch after an episode onto the series page with Resume, after a
  channel onto the channel, and with the title gone onto the fallback.

## Risks

- A provider whose title ids change between loads makes the title "gone"
  and the launch falls back. Progress has the same weakness.
- On Apple TV the page can appear up to 10 seconds after launch on a slow
  source, over the Live loading screen. Past that it never appears.
