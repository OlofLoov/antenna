# Design

## Context

On Apple TV, `ShellModel.open` pauses the channel when Movies, Series or Search opens from Live or Guide, and `ShellModel+Hold.swift` stops it 30 seconds later. Live or Guide then resumes a paused channel through `TimeshiftModel.interruptionEnded` or tunes a stopped one again. That code sits behind `#if os(tvOS)` on `ShellModel`, which only Apple TV uses.

iPhone, iPad and Mac run `LiveModel` instead, owned by `RootView`. Both layouts tell it about every tab change through `LiveModel.opened(_:)`: `CompactTabs` (the tab bar on iPhone and in a narrow iPad window) on a change of `selection`, and `LiveRegularView` (the sidebar on a wide iPad window and on Mac) on a change of `section`, which the sidebar and the Go menu both set. Today `opened` only stores the tab for the next launch, so the channel plays on behind every tab.

Other paths checked:
- A movie or episode stops the live engine through `ShelfPlayback` and `LiveModel.suspend()`. Live plays it again on appearance through `resumeIfSuspended()`. That stays as it is.
- `PlaybackLifecycle` on iPhone, iPad and Mac keeps sound in the background (`continuesInBackground` is always true) and resumes only what it paused itself. A channel the hold paused is not playing when the app leaves, so nothing plays in the background and nothing starts on return.
- The Picture in Picture window is watched by `PictureInPictureWatch`, and `PlayerModel.pictureInPictureActive` follows it. AirPlay is followed by `PlayerModel.airPlayActive`.
- Each Mac window has its own `RootView`, `LiveModel` and engine, so each window holds its own channel by its own section.
- Apple TV cannot start Picture in Picture from Live (`startPictureInPicture` does nothing on tvOS) and has no AirPlay out, so the exception never applies there.

Nothing on screen changes, so no board is redrawn. The change follows the boards it touches as they are: `iPhone` (live TV) and `iPhone-Movies` for the tab bar, `iPad` (iPad and Mac browse and play) and `iPad-Movies` for the sidebar, `iPad-Menus-Go` for the Go menu, `iPad-MultiView` for multi-view, and `iPhone-Player` and `iPad-Player` for the Picture in Picture button. On Apple TV, `TV-Shell-Menu` and `TV-Movies` as before. Design-system requirements: `design-system/live-video-keeps-playing-under-overlays` is about Apple TV overlays and is untouched; none of the tabs here is an overlay.

## Decisions

### The Apple TV rule on every platform

Opening Movies, Series or Search pauses a channel that is playing, loading, buffering or reconnecting, and starts a 30-second timer. When it fires with one of those tabs still open and the channel still paused, the engine stops. Live or the Guide then plays a paused channel on, or tunes a stopped one again at live. A load that lands while one of those tabs is open stays paused. A channel the user paused, or one that failed or is idle, is left alone.

Going back to Live resumes the channel, as on Apple TV after #385. The `sideways-on-iphone-fills-the-screen` requirement still holds: the channel plays again when Live opens, and the sideways iPhone fills the screen with it.

The Guide and Settings leave the channel as it is, in both directions. From Live they play on, as before and as the Guide does on Apple TV. Moving from Movies to Settings keeps the channel paused and the timer running; Settings to Live resumes it. So Settings neither starts nor ends a hold.

Options considered:
- Keep playing on iPhone, iPad and Mac (rejected by the owner on 2026-11-19): the sound runs under Movies and the stream holds the provider's connection.
- Stop at once (rejected for the reasons recorded in `fix-tv-live-behind-tabs-and-group-column`: a quick look at Movies would cost a reload and the timeshift buffer).
- Pause at once, stop after 30 seconds (chosen, as on Apple TV).

### One helper for both models

The pause, the timer and the resume move out of `ShellModel+Hold.swift` into `LiveHold` in `Apps/Shared/Player/LiveHold.swift`, built for every platform. It owns the engine pause, the 30-second timer, the record of what it did (`LiveHold.Kind`: `.paused` or `.stopped`) and the timeshift calls. Its owner says when a tab opens (`begin(stillBehind:)`), when a load lands (`loadLanded()`), and when Live or the Guide opens (`end()`, which answers whether the owner must tune the channel again). `ShellModel` keeps `heldByShell` and `pausedByShell` as reads of the helper, so the Apple TV tests and callers stay the same. `ShellHold` goes; `PlaybackState.hasStopped` moves with the helper.

The timer now also checks that the engine is still paused before it stops it. A channel the user started again from the lock screen or Control Center behind Movies plays on instead of being cut off. On Apple TV this changes nothing a user can reach today.

`LiveModel` keeps a `behindContent` flag: set when Movies, Series or Search opens, cleared when Live or the Guide opens. Tab changes arrive from `onChange` handlers, which cannot wait, so `opened(_:)` queues each change behind the previous one (`tabChange`), and `tabOpened(_:)` does the work. Tests call `tabOpened(_:)` and wait for it. A quick Live, Movies, Live never leaves a pause behind on Live.

Options considered:
- A copy of the hold in `LiveModel` (rejected): two timers and two sets of rules to keep in step.
- Move `LiveModel` and `ShellModel` onto one model (rejected): far larger than this fix.
- Put the hold in AntennaCore (rejected): it drives `TimeshiftModel` and the engine, which live in the app; the rules are a handful of lines.

### Picture in Picture and AirPlay keep playing

When Movies, Series or Search opens with the picture in the Picture in Picture window or on AirPlay, nothing pauses and no timer starts. The user moved the picture out of the app's tabs on purpose. If the window ends while one of those tabs is open and the channel still plays, which is what bringing the picture back into the app does, the hold begins then, as if the tab had just opened. Closing the window pauses the channel, as `player-controls-and-playback-errors/picture-in-picture-on-iphone-and-ipad` says; that pause is the window's, so the hold leaves it alone and does not stop it after 30 seconds.

AirPlay was not part of the owner's request. It is included because the picture plays on the TV the user sent it to, the same reason as the Picture in Picture window, and pausing it would stop what the room is watching while someone browses Movies on the phone. `PlayerModel.airPlayActive` is read when the tab opens; AirPlay ending behind Movies does not start the hold.

### Multi-view on iPad and Mac

Opening Movies, Series or Search while multi-view is open ends it through `MultiViewModel.leave()`, which keeps the selected tile's channel on the single engine and stops every other tile, then holds that channel. Going back to Live shows it on its own.

Options considered:
- Pause every tile and stop them after 30 seconds (rejected): up to four streams would hold up to four provider connections while the user browses, and `TileEngines` has no pause or resume for the set.
- Leave multi-view on as it is (rejected): four streams would play unseen.

On iPad the grid takes the picture column and folds the sidebar, but the sidebar button and the Go menu still reach Movies, so the case is real.

### Full screen on iPad and Mac

The Go menu works while the picture fills the window, and the window body shows the full-screen picture whatever section is picked. The hold leaves full screen and hides the controls, as `suspend()` does for a movie, so the section the user picked shows. On iPhone the sideways full screen already ends when the tab changes.

### Tests

`LiveHoldTests` in `Apps/Tests` runs `LiveModel` on `PlayerTestEngine` and `SleepClock`: the pause on Movies and the resume on Live without a reload, the stop at 30 seconds and the new tune, the timer across Series and Settings, the Guide and Settings leaving the channel alone, a user's pause, a load that lands behind Search, Picture in Picture and AirPlay keeping the channel playing, and the window ending behind Movies. Picture in Picture runs through injected `PictureInPictureHooks`, since a UI test cannot open the system window. `ShelfPlayerUITests.testMoviesPausesLiveAndLiveResumesIt` plays a channel on iPhone, opens Movies, reads the paused engine on the probe that now also sits on Movies, and goes back to Live. The Apple TV `ShellModelTests` cover the shared helper on that side and stay as they are.

## Platforms

iPhone, iPad, Mac and Apple TV all pause behind Movies, Series and Search and stop after 30 seconds. On iPhone Series sits inside Movies, so the Movies tab covers both. Picture in Picture and AirPlay exist only on iPhone, iPad and Mac.

## Open questions

- Picture in Picture and AirPlay are checked with injected state, not on a device.
- The Mac is checked through the shared code and the iPad layout's unit tests; no Mac UI test runs in this change.
