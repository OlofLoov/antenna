# Design

## Context

`ShelfPlayback` plays one `Target` at a time (`.movie`, `.episode`, `.trailer`) on one engine, with a `TitleTransport` and `TitleTracks` per title. `ShelfPlayerView` draws it over the section: `TitleRemoteLayer` on Apple TV, `TitleTouchLayer` on iPhone, iPad and Mac. `PositionSaving` saves the place every 30 seconds, on pause, on seek and at the end, where it saves the full length.

Reading the code turned up one gap. `title-detail-and-episode-picker/play-an-episode-and-come-back` says the viewer is back on the page when an episode ends, but `ShelfPlayback.follow` only closes a trailer on `.ended`. An episode or movie that ends stays on its last frame with the transport up until the viewer presses Close or Menu. This change closes an episode that ends with nothing to play next. Movies keep today's behavior; changing them is outside this change.

The episode list is already in memory in two places: `ShelfModel.episodes[seriesID]`, filled by the title page's info call and by `loadEpisodes` when a series poster or Continue watching starts an episode, and `TitleModel.groups` for the open page. `ShelfModel.loadEpisodes` returns the stored list or asks the provider once and keeps it.

## Decisions

### When the button and the card show

Two steps, the coordinator's recommendation, which the owner is reviewing. The owner set the values on 2026-11-18: 30 and 15 seconds, after finding 60 seconds too long.

1. From 30 seconds before the end, a small Next episode button sits in the bottom right corner. The picture keeps playing and nothing covers its middle.
2. From 15 seconds before the end, the Up next card replaces it with a 10-second countdown, Play now and Cancel. The next episode starts at zero, 5 seconds before the end, or at once if the episode ends first.

An episode under 5 minutes, or with no length from the stream, shows no button and no card while it plays. When it ends, the card shows over the last frame and counts down from 10. Skipping or scrubbing back to more than 30 seconds before the end hides both and puts the count back to 10.

Options considered:

- One fixed card 30 seconds before the end (rejected): it covers part of the picture for half a minute during the last scene of episodes without long credits, and providers send no credit markers to tell the two apart.
- Only at the end (rejected): the viewer sits through the black after the credits every time, which is what the owner wants gone.
- Two steps (chosen): the button costs nothing on screen, so it can show early, and the card that interrupts shows late and briefly. The 30 and 15 second values are constants in AntennaCore (`UpNext.buttonLead`, `UpNext.cardLead`), so a change after review is one line each.

The countdown counts seconds of wall time while the episode plays or has ended, and stops while it is paused or buffering. Counting the episode's own remaining time was considered and rejected: a stream that stalls near the end would stop the count with no sign why.

### Which episode is next

`UpNext.next(after:in:)` walks `SeasonGroup.group(episodes)`, the same order as the season picker and `SeriesPlayTarget`. The next episode is the following one in the same group. From the last episode of a numbered season it goes to the first episode of the next numbered season. Specials and Other lead only to the next episode in their own group. The last episode has no next, and nothing wraps around.

`SeriesPlayTarget` wraps to the start after the last watched episode, which suits the Play button on a finished series. Autoplay must not start Season 1 again after a finale, or slide from the finale into specials, which on most providers are trailers and extras.

The next episode starts where the viewer stopped in it, by the same `resumePosition` rule as selecting it on the page, or from the start.

### Where the episode list comes from

When an episode starts, `ShelfPlayback` asks `library.series.loadEpisodes(series)` once. That returns the list the page or poster already loaded, or loads and keeps it when the episode came from somewhere that has not loaded it. A failure means no next episode for this run; it is logged with `TitleModel.reason` and nothing is shown. Each next episode reuses the same list, so a binge costs no further calls. Its address comes from the same `Dependencies.address` closure as any episode.

### Still watching

`UpNextRun` counts episodes started by the countdown since the viewer's last input. Once it reaches 3 (`UpNext.askAfter`), the card asks "Still watching?" with Keep watching and Cancel, and does not count down. At the end the engine stays ended on its last frame and the question stays until answered. Keep watching plays the next episode; Cancel goes back to the page.

Input means any press, click, tap, key or pointer move the transport receives, the track panel opening, or a button on the card. `TitleTransport.Dependencies.input` reports it. Netflix asks after about three episodes; the owner's brief recommends 3. Options considered: a time limit such as 90 minutes (rejected: three short episodes and two long ones behave differently for no reason the viewer can see), and never asking (rejected: an Apple TV left on streams all night and uses the provider's connection limit).

The run is counted when the card first shows, so pressing anything during the episode turns a pending question back into a countdown. Playing an episode from the page or a poster starts the run at zero.

### Progress when the next episode starts

Before the next episode loads, `ShelfPlayback` saves the finished one at its full length, or at the last position when the length is unknown. `WatchProgress` counts 95% as watched, and pressing Next episode 30 seconds before the end of a 5-minute episode is only 90%, so the full length is saved explicitly. Then the next episode loads like any other: a new `PositionSaving`, `TitleTransport` and `TitleTracks`. Continue watching, UP NEXT and the Play button follow from the saved progress with no new code.

`TitleScreen` watches `playback.playing` and calls `TitleModel.played(_:)` for each episode of its series, which sets `pickedSeason` and `lastPlayed`. Coming back reveals the episode that played last.

### The setting

"Autoplay next episode", on by default, stored per device in UserDefaults as `AutoplaySetting` JSON under `player.autoplay`. Options considered:

- Synced with the other preferences in `PreferencesRecord` (rejected): it adds a stored property to a CloudKit record, and the choice depends on the device. Someone who falls asleep to an episode on the iPhone in bed may want it off there and on for the living-room Apple TV.
- Per device (chosen): CLAUDE.md puts per-device state that is not a secret in UserDefaults, like `hints.remote`. Nothing about a stream is stored. A value that does not decode reads as on.

The row is a Toggle in its own section after Preferences on every platform, with the footer "Plays the next episode of a series when one ends. Applies to this device only." `ShelfPlayback` reads the value when an episode starts, so a change takes effect from the next episode.

### Apple TV focus and the remote

The picture is a focused button that takes select, Menu and play/pause, and `TitleRemote` puts the click and slide recognizers on the window. Those recognizers keep working whatever has focus, so left and right still skip and a slide still shows the bar with the button or the card up.

- Next episode button: does not take focus when it appears. The picture's `onMoveCommand(.down)` moves focus to it. A click down and a swipe down both arrive there; up, left and right clicks keep their meaning. With focus on the button, select plays the next episode, Menu or up puts focus back on the picture, and play/pause still pauses.
- Up next card: takes focus on Play now when it shows, because the viewer has 10 seconds to act and the couch is far away. Select plays now. Menu cancels and puts focus back on the picture. Play/pause pauses the episode and the count, through `onPlayPauseCommand` on the card. There is no Cancel button on Apple TV; Back is the cancel, as in the TV app.
- Still watching: Keep watching takes focus. Menu cancels.
- While a slide holds a target (`TitleTransport.isScrubbing`), the card hides and focus goes back to the picture, so select still plays from the target. It comes back when the target is committed or cancelled.
- Menu on the picture still closes the episode.

Remote hints: `ControlHintScreen.titlePlayer(scrubbing:nextEpisode:)` lists swipe down for "Next episode" in place of the scrub line while the button shows. `.nextEpisodeButton` lists Click "Play the next episode" and Back "Keep watching". `.upNext(asking: false)` lists Click "Play now", click left or right "Skip 10 seconds", play/pause "Pause or play" and Back "Cancel". `.upNext(asking: true)` lists Click "Keep watching" and Back "Cancel". `RemoteControl` gains `swipeDown`. The button and the card each count as their own place for `ControlHintSchedule`, so the legend shows once on arrival and fades as usual.

### iPhone, iPad and Mac

The button and the card sit bottom right inside the safe area, above the scrubber while the controls show and 24 pt from the bottom while they are hidden. They never hide with the controls. The card's Play now uses the glass prominent button style and Cancel the glass style (`design-system/controls-use-system-styles`). On a Mac and an iPad keyboard, Return presses Play now or Keep watching, and Escape cancels the card while it shows, then closes the player as before.

### Platforms

iPhone, iPad, Mac and Apple TV all get the button, the card, the question and the setting. Picture in Picture keeps playing the episode to its end without autoplay; the card is not visible there.

## Layout

Boards:

- `TV-Title-Player-NextButton`: the button in its last 30 seconds, focused after a swipe down.
- `TV-Title-Player-UpNext`: the card with "Next episode in 7", Play now focused.
- `TV-Title-Player-StillWatching`: the question after three episodes.
- `iPhone-Title-Player-UpNext`: the card over the picture with the controls hidden.
- `iPad-Title-Player-UpNext`: the card with the controls showing, the button's place noted. The Mac follows the iPad board.
- `iPhone-Settings` and `TV-Settings-Hints`: the "Autoplay next episode" row.

Design-system requirements followed: `controls-use-system-styles`, `type-uses-text-styles`, `live-video-keeps-playing-under-overlays` (the picture plays under the button and the card).

Not drawn: the button on iPhone and iPad (the card's corner, as a capsule "Next episode" with a forward glyph), the question on iPhone and iPad (the card with "Still watching?" in place of the countdown and Keep watching in place of Play now), and the card over an ended frame.

## Identifiers

| Identifier | What |
|---|---|
| `upNext.button` | the Next episode button |
| `upNext.card` | the Up next card or the question |
| `upNext.title` | "S2 E5 · The Long Night" |
| `upNext.countdown` | "Next episode in 10", or "Still watching?" |
| `upNext.playNow` | Play now, or Keep watching |
| `upNext.cancel` | Cancel (iPhone, iPad, Mac) |
| `settings.autoplayNext` | the Settings toggle |

UI tests launch with `-ui-testing-near-end`, which makes the scripted engine start each title 25 seconds before the end of its 90 minutes, so the button shows at once and a skip forward 10 seconds brings the card. Both iPhone and Apple TV run them on the `watching` shelf scenario, whose Northern Lights has seasons 1 to 3.

## Types

- AntennaCore (`Player/UpNext.swift`): `UpNext` (the constants `buttonLead`, `cardLead`, `countdown`, `shortEpisode`, `askAfter`, and `next(after:in:)`), `UpNextTimer` (what shows for a position, a tick, the end and Cancel), `UpNextRun` (episodes in a row without input), `UpNextText` (the title line, the countdown line and the spoken line), `AutoplaySetting`. `ControlHintScreen` gains `.titlePlayer(scrubbing:nextEpisode:)`, `.nextEpisodeButton` and `.upNext(asking:)`; `RemoteControl` gains `.swipeDown`.
- Apps: `ShelfPlayback.upNext`, `playNext()`, `cancelUpNext()`; `TitleTransport.Dependencies.input`; `TitleModel.played(_:)`; `NextEpisode.Button` and `NextEpisode.Card` in `Apps/Shared/Components/NextEpisode/`; `AutoplayRow` in `Apps/Shared/Views/Settings/`. `TitleTVPanel` and `TitleTrackButtons` moved unchanged to `TitleTrackControls.swift` to keep `ShelfPlayerView.swift` under the file length limit.
