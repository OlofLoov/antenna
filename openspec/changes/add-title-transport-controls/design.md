# Design

## Context

`ShelfPlayerView` plays a movie or episode over the section. On iPhone, iPad and Mac it has a tap-to-pause surface, Close and the track buttons; on Apple TV a focusable picture takes play/pause, Menu and a held select for the tracks panel. There is no time, no bar and no skip anywhere. Both engines already implement `seek(to: Duration)` and report `position()`.

Reading the engines for films turned up three things:

- `DemuxEngine` could not skip in an MPEG-TS film at all. `Demuxer` opens the container without `avformat_find_stream_info`, so FFmpeg never estimates the length of a container whose header has none. MPEG-TS has none, `DemuxStart.canSeek` needs a length (`DemuxRun.swift`, `canSeek: bytes.canSeek && prepared.demuxer.duration != nil`), and every seek threw `SeekRefusal.notSeekable`. The same check skipped the saved start time, so a `.ts` movie also never resumed. Matroska and MP4 carry their length and were fine; the existing film tests use `.mkv`.
- After a film ends, `AVPlayerEngine` drops its item, so a seek throws, and `DemuxEngine` seeks but stays `.ended`, so the next play starts from 0.
- `ShelfPlayback` saves the position the engine last reported. Closing right after a skip, before the engine reports the new point, saved the old one.

## Decisions

### Measuring MPEG-TS films

`Demuxer` takes `measuresLength`. When the header gives no length, the bytes can seek, and the flag is set, it reads the earliest presentation time in the first 64 packets and the latest end time in the last megabyte, sets `startTime` and `duration` from them, and seeks back to byte 0. `DemuxRun` sets the flag when `PlaybackOptions.isLive == false`, which movies, episodes and catch-up pass. Options considered:

- Call `avformat_find_stream_info` (rejected): the reason it is skipped still holds; with no H.264 or AAC decoder in the build it reads until its limit, seconds on a slow server.
- Length from bitrate and file size (rejected): off by minutes on variable-bitrate files, and the scrubber and resume would land in the wrong place.
- Read both ends (chosen): one extra range request of 1 MB per film open, nothing for live TV, whose bytes cannot seek.

Live channels never set the flag, so a live `.ts` served with a length (the `channel.ts` fixture is one) still counts as live.

### Where the transport lives

`TitleTransport` (`Apps/Shared/Views/Shelf/TitleTransport.swift`) is an `@Observable` model per title, made by `ShelfPlayback.start` next to `TitleTracks` and dropped on close. It follows the engine's position and state, holds `pending` (where a skip goes until the engine is there) and `target` (where a drag or slide points), and decides when the controls show. Seeks go through `ShelfPlayback.seek(to:)`, which:

- seeks the engine, or for an ended title loads it again with `startPosition` set and plays, the same on both engines;
- calls `PositionSaving.moved(to:at:)` and saves the result, so the saved place follows the seek at once;
- returns false on `SeekRefusal`, and the transport says "This stream can't skip" for 3 seconds.

Skips in a row count from `pending`, so three taps on forward 10 move 30 seconds even when the engine has not answered the first. Only the last seek clears `pending`.

The math is in AntennaCore as `TitleTimeline`: skip clamped to the start and the end, fraction and time on the bar, the Apple TV slide span, and the elapsed, remaining and spoken text.

### A title that cannot play

`ShelfPlayback.start` dropped a failed `engine.load` (`catch { return }`), so the transport and the state listener never attached and the title sat on a black screen. The series lane found it while fixing episodes. Now a `PlaybackFailure` from the load, or a `.failed` state later, sets `ShelfPlayback.failure` to the same `FailureMessage` Live uses, named after the source. `ShelfPlayerView` shows `PlayerStatus.Failure` on iPhone, iPad and Mac and `PlayerStatus.TelevisionFailure` on Apple TV in place of the transport, with Try again (`player.retry`) and Back (`player.error.back`). Try again calls `start` again from the last position the engine reported, or the saved start. A cancelled load still shows nothing.

Seeking after `RoutedEngine` hands an mkv, ts or avi file listed as mp4 over to the demuxer needs nothing more: `ShelfPlayback` seeks the routed engine, which passes the seek to whichever engine plays.

### Skip length

10 seconds both ways, as Apple's player and the TV app do for films, and as the owner asked. Live TV keeps 15 back and 30 forward; a film has no live edge to catch up to.

### Apple TV remote

A `UIViewRepresentable` (`TitleRemote`) puts two tap recognizers for the left and right arrow presses and one pan recognizer for indirect touches on the window, as `ShellTimeshift` does for its long presses. SwiftUI's `onMoveCommand` fires for a click and for a swipe alike, and here they mean different things. The recognizers stand down while the tracks panel is open.

| Input | Playing | Paused | Paused with a target |
|---|---|---|---|
| Click left or right | skip 10 s | skip 10 s | move target 10 s |
| Slide | show the bar | set a target from the time on screen | move the target |
| Select | pause | play | play from the target |
| Play/pause | pause | play | play from the target |
| Menu | close | close | put the target back |
| Hold select | tracks panel | tracks panel | tracks panel |

Select pausing is new; before, a press did nothing. Apple's player plays and pauses on a click of the clickpad center, and the owner asked for it to behave like Apple's. The release of a hold that opened the panel is ignored for 1.5 seconds, so opening the panel does not pause.

One slide across the whole touch surface moves the target an eighth of the title, at least a minute and at most 20 (`TitleTimeline.slideSpan`). A two-hour film moves 15 minutes per full slide; a 22-minute episode moves 2 minutes 45. The share comes from the pan's translation over the window's width. This was tuned on the simulator only and needs a pass on a real remote.

Holding left or right to scan at speed is out of scope. While Live is the open tab, `ShellTimeshift`'s window recognizers also see long presses of left and right; with Live stopped under the title they do nothing.

### Touch, pointer and keys

A tap on the picture shows or hides the controls instead of pausing, as in Apple's player. Pausing moves to the play/pause button in the middle. On iPhone and iPad a double tap on the left or right half skips 10 seconds (SwiftUI's double tap delays the single tap a little, as in Live). On a Mac a double click is left alone; Mac users expect it to mean full screen.

The scrubber is the system `Slider` (`design-system/controls-use-system-styles`), and the three middle buttons use the glass button style in a circle. VoiceOver reads the slider's value from `TitleTimeline.spokenText` and its swipes up and down skip 10 seconds.

The Mac and an iPad keyboard get Left, Right and Space from hidden buttons with keyboard shortcuts, as `LiveSkipKeys` does. Escape moves from the Close button to the same group, so it still closes while the controls are hidden. Left, Right and Space stand down while the track list is open.

### When the controls show and hide

`ControlsTimer`, the Live rule: hidden 3 seconds after the last input while playing (5 on Apple TV), kept while paused. Moving the pointer counts as an input each time it moves, so the controls hide 3 seconds after the pointer stops, and a second after it leaves. They also stay while a drag or slide holds a target, while the track list is open, and while VoiceOver runs. They show when the title starts. UI tests launch with a 60-second hold, as Live does.

### Room for the Siri Remote hints

Another change adds an optional overlay of Siri Remote hints. In `ShelfPlayerView`'s Apple TV layer it goes between the bar and the tracks panel, and it can read `TitleTransport.controlsShown`, `isPaused` and `isScrubbing` to say what each button does at that moment. Nothing is built for it here.

### Platforms

iPhone, iPad, Mac and Apple TV all get the transport. Only the Mac leaves out the double tap, for the reason above.

## Layout

Boards: `TV-Title-Player-Transport` (the bar while playing), `TV-Title-Player-Scrub` (paused with a target), `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`. The Mac follows the iPad board. Design-system requirements followed: `controls-use-system-styles` (system slider, glass buttons; the Close button keeps its drawn circle until refresh-visual-design reaches the player), `type-uses-text-styles` (all text on text styles), `live-video-keeps-playing-under-overlays`.

Screenshot steps: `movie-player-transport` in `AppJourneys` (iPhone and iPad) and `TVJourneys`, and `movie-player-paused` on Apple TV, anchored on `title.transport` and its state glyph.

Not drawn: the Siri Remote hint overlay, and the notice "This stream can't skip", which uses the timeshift notice's look.

## Identifiers

| Identifier | What |
|---|---|
| `movies.player`, `series.player` | the picture, unchanged |
| `movies.player.close`, `series.player.close` | Close, unchanged |
| `player.tracks`, `player.subtitles`, `player.panel.*` | the track buttons and panel, unchanged |
| `title.transport` | the controls (iPhone, iPad, Mac) or the bar (Apple TV) |
| `title.transport.playPause`, `title.transport.skipBack`, `title.transport.skipForward` | the middle buttons |
| `title.transport.scrubber` | the slider |
| `title.transport.elapsed`, `title.transport.remaining` | the times |
| `title.transport.track`, `title.transport.target`, `title.transport.stateGlyph` | the Apple TV bar's line, target time and play or pause glyph |
| `title.transport.notice` | "This stream can't skip" |
| `shelf.debug.position` | UI tests only: `at <seconds>` from the scripted engine |

## Types

- AntennaCore: `TitleTimeline`, `PositionSaving.moved(to:at:)`.
- AntennaDemux: `Demuxer.init(read:seek:measuresLength:)`.
- Apps: `TitleTransport`, `TitleRemote` (tvOS), `Transport.Bar` and `Transport.Track` (tvOS), `Transport.Controls` (iOS, macOS), `Transport.Notice`, `Transport.Times`.
