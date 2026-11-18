# Design

## Context

Both bugs come from testing on an Apple TV on 2026-11-18.

### Live behind Movies, Series and Search

The shell keeps one player surface for every tab. Behind Movies, Series and Search it sets the picture's opacity to 0 and starts a 30-second timer; only when the timer fires does it pause the engine. So for the first 30 seconds of every visit the channel's sound plays under the tab, and the picture decodes unseen. `ShellNavigationTests.liveFromBarResumes` passed because it advanced the clock by 30 seconds before it looked. Most visits to Movies are shorter than that, so on the device the channel was nearly always heard.

Other paths into the tabs were checked and are not causes:
- Every way into a tab, Select in the bar, the navigator (Search from the overlay) and a Top Shelf link, goes through `ShellModel.open`, which is the only place `tab` changes.
- `PlaybackLifecycle` resumes only what it paused itself, so coming back from the background does not start a stream the shell paused.
- Multi-view covers Live in a full-screen cover with no tab bar, so a tab cannot open under it.
- Playing a movie stops the live engine through `ShelfPlayback`; Live loads the channel again on return, as before.

There was one race. A channel whose load was still running when the user opened a tab started playing when the load finished, because the shell plays after every load it did not pause.

### The group column

After the user scrolled down a group's channels and moved left, the group column scrolled and settled again. `fix-live-group-switching` made the shown group the column's default focus target with `defaultFocus(priority: .userInitiated)` and kept a redirect in `ShellScreen.focusMoved` as a fallback. When the default target does not apply, the focus engine picks the group level with the focused channel, which after a long scroll sits near the bottom of the column. tvOS scrolls the column to keep that row off the edge, then the redirect moves focus to the shown group and the column scrolls back. The simulator honours the default target and shows no movement, in the old build and the new one (checked by recording row frames after each step), so the device takes the fallback path at least some of the time, likely on swipes from the touch surface.

The overlay keeps board `Main` and the design-system requirements it already follows (`design-system/focus-is-the-lifted-white-card`). Nothing on screen changes, so no board is redrawn.

## Decisions

### Pause at once, stop after 30 seconds

Opening Movies, Series or Search from Live or Guide pauses a channel that is playing, loading, buffering or reconnecting, and starts a 30-second timer. When it fires with a content tab still open, the engine stops. Live or Guide then resumes a paused channel through `TimeshiftModel.interruptionEnded`, as the old pause did, or tunes a stopped one again with `tune`, after resetting the timeshift state, so the spinner shows and the channel starts at live. `ShellModel.heldByShell` (`ShellHold.paused` or `.stopped`) records which.

A load that finishes while a content tab is open counts as paused by the shell and does not play.

A movie played from Movies stops the live engine, paused or not. Live and Guide check for that on return and tune the channel again instead of resuming. Before this change the Guide showed an empty box after a movie.

A channel the user paused, or one that failed or is idle, is left as it is, as before. A user's pause keeps its timeshift buffer, which is the reason for pausing.

Options considered:
- Pause after 30 seconds (the old rule, rejected): the sound plays for the first 30 seconds of every visit.
- Pause at once and never stop (rejected): the paused stream still holds the provider's connection. Many IPTV providers allow one stream per login, so another device in the house cannot play while this Apple TV sits on Movies. On the FFmpeg path a paused live stream without timeshift already lets the connection go, but with a timeshift buffer, and on AVPlayer, it stays open.
- Stop at once (rejected): going back to Live within a few seconds would wait for the channel to load again, and the timeshift buffer would be gone.
- Pause at once, stop after 30 seconds (chosen): a quick look at Movies costs nothing on return, and a long browse frees the connection. Coming back after 30 seconds takes as long as tuning the channel.

Mute instead of pause was not considered further: the stream would go on using the connection and the decoder.

### Only the shown group takes focus from outside the column

While focus is outside the group column, every group row except the shown one, the locked groups and Search are disabled, so they cannot take focus. Left from the channels then has one target in the column, the shown group, with or without the default-focus hint, and nothing to redirect. Once focus is in the column every row is enabled again, so up and down move through the groups as before. The rows draw with their own button style, so being disabled changes nothing on screen.

The column still scrolls the shown group to its middle when the overlay opens and when the shown group changes while focus is elsewhere. Both scrolls now run with animations disabled, so the column opens in place instead of scrolling into view.

Options considered:
- Keep the redirect and remember the column's scroll offset, putting it back after focus lands (rejected): the column would still move and then move back.
- Disable focus-driven scrolling in the column (rejected): up and down through hundreds of groups need it.
- Make other rows unfocusable while focus is elsewhere (chosen).

The redirect in `focusMoved` stays as a fallback.

### Tests

`ShellModelTests` covers the pause on opening a tab, resuming without a reload before 30 seconds, the stop and the new tune after 30 seconds, the timer across Search and Series, a user's pause left alone, a load that lands behind Search, and the foreground behind a tab. They run on `RecordingEngine`. The UI test `testMoviesPausesLiveAndLiveResumesIt` runs the same path on the scripted engine of the UI-test shell. Two Search UI tests and `testAWayIntoSearch` expected the channel to play behind Search and now expect it paused. `movieStoppedPausedChannel` covers a movie stopping the paused channel before the Guide opens.

`testMovingBetweenTheColumnsInALargeCatalogue` records where the shown group and a group four rows above it sit before going right, and checks both are in the same place after coming back from 30 rows down and after a second round trip.

## Platforms

Apple TV only. On iPhone, iPad and Mac the channel goes on playing on another tab, and `live-tv-on-iphone-ipad-mac/sideways-on-iphone-fills-the-screen` relies on that. The report was about Apple TV, where the picture is hidden behind the tab and only the sound is left. Whether the other platforms should pause too is an open question for the owner. The group column with focus exists only on Apple TV; iPhone, iPad and Mac pick a group with a tap or a click.

## Open questions

- Should iPhone, iPad and Mac pause the channel behind Movies and Series as well?
- The simulator does not reproduce the column movement, so the fix is checked against the cause above, not the device. It needs a look on an Apple TV.
