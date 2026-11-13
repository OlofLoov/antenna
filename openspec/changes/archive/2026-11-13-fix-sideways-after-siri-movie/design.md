# Design

## Context

`CompactTabs` in `RootView.swift` derives sideways full screen with `onChange(of: sidewaysLive, initial: true)`, where `SidewaysLive` holds whether the phone is sideways on Live and the playing channel. A movie starts through `ShelfPlayback`, whose `willPlay` calls `LiveModel.suspend()`. That stops the engine and sets `fullScreen` to false, but keeps `playing`.

The movie player is an overlay at the window root (`ShelfSync`), so Live never leaves the screen. When Siri or a shortcut plays a movie while Live is open, nothing in `SidewaysLive` changes: the tab is still Live, the phone is still sideways and `playing` is the same channel. When the movie ends the `onChange` does not fire, so full screen stays off. `LiveCompactView.onAppear` does not fire either, so `resumeIfSuspended()` never runs and the channel stays stopped. Picking a movie from the Movies tab does not show the bug, because coming back to Live changes the tab.

## Decisions

### Where the movie counts

`SidewaysLive.sideways` is false while a movie or episode plays. Starting one turns full screen off, as `suspend()` already does, and closing it turns `sideways` back to true, which fills the screen again through the existing `onChange`. Options considered:
- Keep `fullScreen` on through `suspend()` (rejected): iPad and Mac read the same flag to hide their columns, and the picture would come back full screen there too.
- Re-derive full screen from `ShelfPlayback` when the movie ends (rejected): a second place that decides full screen, next to the one in `CompactTabs`.
- Fold "no movie playing" into `sideways` (chosen): one place still decides full screen.

### Starting the channel again

`CompactTabs` calls `LiveModel.appeared()` when a movie ends with Live as the open tab, the same call `LiveCompactView` makes when Live appears. It runs `resumeIfSuspended()`, so the channel plays from live again. The requirement `movies-and-series-browsing/resume-where-you-left-off` says the channel starts the next time Live opens; Live being on screen when the movie closes counts as that.

### Testing the Siri path

Siri cannot be driven from a UI test, and `-ui-testing-intent` hands its request over at launch, before a channel can play. A new Debug-only argument, `-ui-testing-intent-on-return <request>`, hands the request over each time the app comes back to the foreground, which is what Siri does to a running app. The test plays a channel, turns the phone sideways, sends the app to the background, brings it back to start the movie, closes it, and checks the picture fills the screen and the channel loads again.

No screen changes, so no board applies.
