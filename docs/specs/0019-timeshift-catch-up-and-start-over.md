# 0019. Timeshift buffer, catch-up and Start over

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- ADR needed: where the timeshift buffer lives and how big it is. This spec assumes an on-disk ring in the app's Caches directory bounded by 60 minutes and a per-platform byte cap (4 GiB on tvOS and macOS, 2 GiB on iOS and iPadOS), because the 150 MB resident budget on tvOS (0014 edge cases) holds about two minutes of HD video in memory, which is the TiviMate behaviour users complain about. AC-8a, AC-8b, AC-29 and AC-30 exist only for the on-disk ring and are revised if the ADR chooses otherwise; the other criteria read their numbers from `TimeshiftLimits`. The ADR also records the flash write volume (about 3 MB/s at 25 Mbit/s while the user only watches) and how tvOS and iOS purge Caches. This spec is not Accepted before that ADR is, nor before the edits listed under "Required of other specs" land in 0007, 0008, 0009, 0010 and 0015.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0001 (M3U `catchup` attributes), 0003 (Xtream client and channel ids), 0004 (sources, Keychain lookup), 0007 (overlay panel, hidden Start over), 0008 (zap bar), 0010 (inline player controls), 0013 (`RowKey`, catalogue lookup), 0014 (`GuideStore.current(for:at:)`), 0015 (shell pause behind content tabs), 0017 (playback engine, in progress) and 0018 (player controls and playback errors, in progress).
- Supersedes on acceptance: 0007/AC-14 (Start over hidden) by AC-19; 0007/AC-9a's `.paused` branch, 0015/AC-5b, 0015/AC-6b test a and 0009/AC-1b for pauses the user made, by AC-27a; 0008/AC-2's "the engine state is unchanged" and the 0008 Scope sentence that the play/pause button never reaches the engine, by AC-10 and AC-16a; 0008/AC-8's hint text while behind live, by AC-16; 0010/AC-10a's single control row on a timeshift-capable engine, by AC-17 (the clock stays); 0010's Scope line "Catch-up and timeshift" moves from Out to this spec. Resolves 0008's open question on swipe left and right: they skip (AC-12).
- Extends 0001: `M3UParser` also reads `catchup-source` and `catchup-correction` and keeps the raw `catchup` mode (AC-1). 0001's Scope gains the two attributes when this spec is accepted.

## Design

Boards: `docs/design/boards/TV-ZapBar-Timeshift.dc.html` (tvOS, the zap bar of 0008 with the timeshift row while paused 12 minutes behind live) and `docs/design/boards/iPhone-Player-Timeshift.dc.html` (iOS, the pinned player of 0010 with the two-row control strip while paused behind live). Start over on tvOS is `overlay.startOver` as drawn on `Main.dc.html` (0007) and made visible by AC-19. Everything else on these screens is 0008's and 0010's boards; 0018's boards own the error and buffering states of the player.
Design rules that apply: DR-1, DR-3, DR-4, DR-5, DR-7, DR-11, DR-12, DR-13. Deviations: DR-3, the scrubber knob is accent-filled because the knob marks the end of the accent progress fill and nothing but focus may be white-filled on tvOS (README section 2); the live dot turns muted (`#A7B0BF`) while the position is behind the live edge, so the dot is red only when the picture is live (README section 1 "Live dot" and section 3 badges gain this LIVE behind state); the buffered fill `rgba(255,255,255,0.35)` is a new token in README section 1; DR-5, the iPhone transport buttons are 32 pt glyph tiles inside 44 pt hit areas, as 0010's pause button already is.
States on the boards:
- `TV-ZapBar-Timeshift.dc.html`: bar 274 pt tall; identity and badges as 0008; the now-playing column shows the programme at the position (AC-18), its progress bar at the position, Next and remaining, then the timeshift row: `timeshift.stateGlyph` (pause glyph, 24 pt, muted), `timeshift.positionTime` "21:22" (22 pt tabular), `timeshift.scrubber` (8 pt track on the 0.16 surface; `timeshift.played` accent fill from the window start to the knob; `timeshift.buffered` in the buffered fill from the knob to the recorded end; `timeshift.knob` 18 pt accent circle with a 2 pt ground ring), `timeshift.behindLive` "12 min behind" (22 pt muted). `zapBar.badge.live` is in its behind state (muted dot, 1.5 pt muted outline, no fill). `zapBar.hint` reads "Hold play/pause for live". No clock (0008/AC-20).
- `iPhone-Player-Timeshift.dc.html`: the 0010 iPhone screen with the player strip grown to two rows: row one `timeshift.positionTime` (12 pt tabular), `timeshift.scrubber` (4 pt track, 14 pt knob), `timeshift.behindLive` (12 pt muted) and `browse.player.clock` (12 pt muted, 0010/AC-10a); row two `timeshift.skipBack`, `browse.player.playPause` (play glyph, since paused), `timeshift.skipForward`, `timeshift.startOver`, the 3 pt programme progress bar, `browse.player.live` in its behind state (a tap target, AC-13), `browse.player.fullscreen`. The now-playing row shows the programme at the position.
Not drawn, with the text style each uses:
- iPad and Mac: the same two-row strip inside the `iPad.dc.html` player, labels 14 pt, knob 14 pt, buttons 32 pt in 44 pt hit areas.
- Full screen on iPhone, iPad and Mac (0010/AC-17): the two-row strip on the bottom edge at the inline sizes.
- `timeshift.notice`: a pill centred above the bar (tvOS) or over the lower third of the player (touch platforms), `rgba(8,10,14,0.82)`, radius 14, text 22 pt on tvOS and 13 pt elsewhere in the primary colour, shown for three seconds (AC-8b, AC-14, AC-22, AC-25a, AC-30).
- Catch-up playback: the timeshift row as drawn with `timeshift.catchupBadge`, an outlined "CATCH-UP" badge in the badge row before the LIVE badge (AC-20).
- Gap after background: the track from the recorded end to the live edge stays at the 0.16 surface with no `timeshift.buffered` fill (AC-25a).
- Engine without timeshift: the 0008 bar unchanged and the 0010 strip unchanged (AC-26).
- Live edge while playing: the timeshift row is present with the knob at the right end, `timeshift.behindLive` empty, the LIVE badge filled with the red dot and `zapBar.hint` reading 0008/AC-8's text; otherwise identical to the board.

## Problem

Live TV on Antenna cannot be paused, rewound or restarted. TiviMate holds about two minutes of pause and cannot rewind or fast-forward inside it, and its users rank a real timeshift buffer second on their wish list ("the one glaring feature missing", `docs/research/tivimate-user-sentiment.md`). Providers often offer catch-up, which 0001 and 0003 already parse into `hasCatchup` and `catchupDays`, and nothing plays it. The hidden Start over button in 0007 and the scrub bar in 0018 wait for this spec.

## Scope

In:
- A local timeshift buffer for the playing live channel, recorded from the moment a channel is tuned, bounded by `TimeshiftLimits.window` (60 minutes) and `TimeshiftLimits.maxBytes` per platform, in a per-session directory under Caches. Pause, resume at the paused position, skip back and forward, scan while a direction is held (tvOS) or drag (touch and pointer), return to the live edge. The 60 minutes hold for streams under about 9 Mbit/s; at 25 Mbit/s the 4 GiB cap holds about 23 minutes (AC-15).
- In the first implementing PR the `AVPlayer` route reports `supportsTimeshift` false (AC-26) unless the storage ADR says otherwise; the demuxer route records.
- `TimeshiftLimits`, `TimeshiftWindow`, `TimeshiftBuffer`, `CatchupMode`, `CatchupURLBuilder`, `StartOverPlanner` and `Platform` in AntennaCore. `Platform` is a plain value the app passes in; the per-target `Platform.swift` files in `Apps/Mobile` and `Apps/TV` each return their case and keep their other extras. The app layer owns the storage location, free-space check, notices and controls.
- `Channel.catchupMode: String?`, `Channel.catchupSource: String?` and `Channel.catchupCorrectionHours: Double?`, filled by `M3UParser` from `catchup`, `catchup-source` and `catchup-correction`. Xtream channels get `catchupMode` "xc" when `tv_archive` is greater than 0.
- Provider catch-up URLs for the M3U modes `default`, `append`, `shift`, `flussonic` and `xc`, and for Xtream sources through `XtreamClient.timeshiftURL(streamID:start:durationMinutes:timeZone:)` with the server time zone from `XtreamAccountInfo.serverInfo.timezone`. `xc` on a channel whose `id` starts with `xtream#` uses the `XtreamCatchupContext`; on any other channel it parses `/live/<user>/<pass>/<id>` from `streamURL`.
- Start over for the programme at the live edge, from `overlay.startOver` on tvOS and `timeshift.startOver` on the other platforms: catch-up first, the local buffer when it holds the programme start, otherwise absent.
- Seeking inside catch-up playback by rebuilding the URL, and returning to live when it ends or the user skips past now.
- What happens when the buffer is exhausted, when the byte cap or free space shortens the window, when catch-up answers 404, when the app goes to background, when the engine cannot record.
- The zap bar timeshift row (tvOS) and the two-row control strip (iOS, iPadOS, macOS).
- Accessibility identifiers with prefix `timeshift.`.

Out (explicitly):
- Watching an earlier programme from the guide grid, the overlay's next list or search results, and the `guide.startOver` button of 0009. A catch-up browsing spec owns them and uses `CatchupURLBuilder` from here.
- Recording to keep (a recording spec, or the decision not to ship one; research note item 4).
- The `vod` catch-up mode and XMLTV `catchup-id`, which need per-programme ids from 0014 (catch-up browsing spec).
- Stalker, Jellyfin and Channels DVR catch-up (their source specs, 0030 to 0032).
- Player controls other than transport: tracks, subtitles, aspect, error display (0018). Buffering and failure rendering (0018).
- Background audio and Picture in Picture themselves (0018); AC-25b says what the buffer does while they run.
- Skip step sizes as a setting (settings spec; needs an ADR if synced).
- Playback-rate scrubbing with sound (2x, 4x).

## User flow

tvOS:
1. A channel plays full screen. The user presses play/pause. The picture freezes, the zap bar appears with the timeshift row, the knob sits at the right end and starts drifting left as live moves on. The bar stays.
2. The user presses play/pause again. Playback continues from the paused point. The bar hides five seconds later. `timeshift.behindLive` reads how far behind live the picture is.
3. Clicking left skips back 15 seconds; clicking right skips forward 30 seconds; each shows the bar. Holding left or right scans at 60 times real time until released. Reaching the live edge returns to live.
4. Holding play/pause returns to live.
5. Select opens the overlay (0007). The panel shows Start over between Watch and the star when the programme can be restarted. Select on it starts the programme from its beginning and closes the overlay.
6. Swiping up or down tunes another channel (0008/AC-9); the buffer starts again from that channel's live edge.

iOS, iPadOS, macOS:
1. A channel plays inline. The user taps pause. The strip shows the scrubber with the knob at the right.
2. Tapping play resumes from the paused point. The skip buttons move 15 seconds back and 30 seconds forward. Dragging the knob seeks; the position time follows the finger and the picture seeks on release.
3. Tapping the LIVE badge while behind live returns to live. Tapping Start over restarts the programme.
4. On macOS and iPadOS with a hardware keyboard, Left and Right arrows skip while the player has focus; Space already toggles pause (0010/AC-14).

## Interface

Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR.

```swift
public enum Platform: Sendable { case iOS, iPadOS, macOS, tvOS }

public enum TimeshiftLimits {
    public static let window: TimeInterval            // 3600
    public static func maxBytes(for platform: Platform) -> Int64   // tvOS, macOS 4 GiB; iOS, iPadOS 2 GiB
    public static let freeSpaceFloor: Int64           // 1 GiB kept free
    public static let minimumUsable: Int64            // 64 MiB; below this timeshift is off
    public static let liveEdgeTolerance: TimeInterval // 10
    public static let skipBack: TimeInterval          // 15
    public static let skipForward: TimeInterval       // 30
    public static let scanRate: Double                // 60
}

public struct TimeshiftWindow: Sendable, Equatable {
    public var start: Date          // oldest recorded instant
    public var recordedEnd: Date    // newest recorded instant
    public var liveEdge: Date       // now, as the engine sees it
    public var position: Date
    public var isAtLiveEdge: Bool   // liveEdge - position < liveEdgeTolerance
    public func clamped(_ date: Date) -> Date       // into start...recordedEnd
    public func skipping(by delta: TimeInterval) -> (position: Date, reachedLive: Bool)
    public static func behindLiveText(_ seconds: TimeInterval) -> String?   // nil under tolerance
}

public actor TimeshiftBuffer {
    public enum Error: Swift.Error, Sendable { case write(code: Int32), read(code: Int32), full, closed }
    public init(directory: URL, maxBytes: Int64, window: TimeInterval)
    public func append(_ data: Data, at instant: Date) async throws(Error)
    public func read(from instant: Date, maxBytes: Int) async throws(Error) -> (Data, instant: Date)?
    public var window: (start: Date, recordedEnd: Date)? { get async }
    public var bytesStored: Int64 { get async }
    public var pinnedAtStart: AsyncStream<Date> { get }   // eviction reached the pinned chunk (AC-14)
    public func discard() async
}

public enum CatchupMode: String, Sendable { case `default`, append, shift, flussonic, fs, xc, vod }

public struct CatchupRequest: Sendable { var start: Date; var duration: TimeInterval; var now: Date }

public struct XtreamCatchupContext: Sendable { var credentials: XtreamCredentials; var timeZone: TimeZone? }

public enum CatchupURLBuilder {
    public static func url(for channel: Channel, request: CatchupRequest,
                           deviceTimeZone: TimeZone, xtream: XtreamCatchupContext?) -> URL?
}

public enum StartOverPlan: Sendable, Equatable {
    case catchup(URL), buffer(Date), unavailable(StartOverUnavailable)
}
public enum StartOverUnavailable: Sendable, Equatable { case noProgramme, noCatchupURL, outsideWindow }
public enum StartOverPlanner {
    public static func plan(programme: Programme?, channel: Channel, window: TimeshiftWindow?,
                            now: Date, catchupURL: URL?) -> StartOverPlan
}
```

The engine (0017) is expected to expose `supportsTimeshift: Bool`, `canSeek: Bool`, `timeshift: AsyncStream<TimeshiftWindow?>` (nil while no buffer is attached), `playhead: AsyncStream<Date?>` for playback without a buffer (catch-up), `seek(to: Date) async`, `seekToLive() async`, `attach(_ buffer: TimeshiftBuffer) async` and an end-of-stream event. During catch-up the app maps the playhead to `TimeshiftWindow(start: P.start, recordedEnd: position, liveEdge: now, position: P.start + elapsed)` so the same row renders it. A catch-up `load` replaces the live stream; the live buffer is detached but kept on disk until the catch-up engine reports `.playing`, then discarded (AC-20). On a failed catch-up load the app calls `load(streamURL)`, `attach(oldBuffer)` and `seek(to: P.start)` (AC-22). Until 0017 lands these are modelled on the fake engine, as 0007 and 0008 do for `load(_:)`.

The player model holds `userPaused: Bool`. Only play/pause input on the remote, `browse.player.playPause`, Space, and `MPRemoteCommandCenter` pause and toggle commands (headphones, media keys, Control Center, game controller) set it; any `play()` clears it. Pauses from 0015/AC-5a, audio interruptions and backgrounding never set it.

The engine appends to the buffer only at random-access boundaries (a PAT and PMT followed by an IDR frame), so every chunk instant is a point playback can start from.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 M3U catch-up attributes
Given an entry with `catchup="default" catchup-source="http://a/arc?utc={utc}&d={duration}" catchup-correction="-1.5" catchup-days="7"`
When the playlist is parsed
Then the channel has `catchupMode` "default", `catchupSource` "http://a/arc?utc={utc}&d={duration}", `catchupCorrectionHours` -1.5, `hasCatchup` true and `catchupDays` 7; an entry with none of the three new attributes has nil for all three; a `catchup-correction` that is not a number yields nil without failing the entry; 0001/AC-8, AC-15 and AC-16 still hold.

### AC-1a Xtream catch-up mode
Given `get_live_streams` entries with `tv_archive` 1, `tv_archive` 0 and no `tv_archive`
When `XtreamClient` maps them to channels
Then the first has `catchupMode` "xc" and the other two have `catchupMode` nil; `catchupSource` and `catchupCorrectionHours` are nil for all three.

### AC-2 Catch-up URL, default template
Given a channel with `catchupMode` "default", `catchupSource` "http://a/arc?s={utc}&e={utcend}&d={duration}&m={duration:60}&o={offset}&n={lutc}&t={Y}-{m}-{d}_{H}-{M}-{S}" and `catchupCorrectionHours` 1, a request with start 2026-11-04T20:00:00Z, duration 3600 and now 2026-11-04T20:40:00Z, and device time zone UTC
When `CatchupURLBuilder.url` runs
Then the result is `http://a/arc?s=1793822400&e=1793826000&d=3600&m=60&o=2400&n=1793824800&t=2026-11-04_21-00-00`: `{utc}` and `{start}` are the start as Unix seconds, `{utcend}` and `{end}` the stop, `{lutc}`, `{now}` and `{timestamp}` now, `{duration}` seconds and `{duration:60}` minutes rounded up, `{offset}` now minus start in seconds and `{offset:60}` in minutes rounded up, `{Y}` to `{S}` the start in the device time zone shifted by the correction, zero-padded; `${name}` is accepted wherever `{name}` is; the Unix placeholders are not shifted by the correction.

### AC-3 Catch-up URL, append and shift
Given the AC-2 request and a channel whose `streamURL` is `http://a/live/7.ts`
When `catchupMode` is "append" with `catchupSource` "?utc={utc}&lutc={lutc}", and separately "shift" with `catchupSource` nil
Then the results are `http://a/live/7.ts?utc=1793822400&lutc=1793824800` for both; with `streamURL` `http://a/live/7.ts?token=x` the appended query starts with `&` instead of `?`; "append" with `catchupSource` nil yields nil.

### AC-4 Catch-up URL, Flussonic
Given the AC-2 request
When `catchupMode` is "flussonic" or "fs" and `streamURL` is `http://a/ch/index.m3u8`, `http://a/ch/video.m3u8`, `http://a/ch/mono.m3u8` or `http://a/ch/mpegts`
Then the results are `http://a/ch/index-1793822400-3600.m3u8`, `http://a/ch/video-1793822400-3600.m3u8`, `http://a/ch/mono-1793822400-3600.m3u8` and `http://a/ch/archive-1793822400-3600.ts`; any other last path component yields nil; a query on the stream URL is kept.

### AC-5 Catch-up URL, Xtream source
Given a request with start 2026-11-04T20:00:00Z and duration 2700, credentials for `http://panel:8080` user `u` password `p`, and server time zone `Europe/Stockholm`
When `XtreamClient.timeshiftURL(streamID: 42, start:, durationMinutes: 45, timeZone:)` is built, and separately `CatchupURLBuilder.url` runs for a channel with `id` `xtream#panel#42`, `catchupMode` "xc" and an `XtreamCatchupContext` carrying those credentials and zone
Then both are `http://panel:8080/timeshift/u/p/45/2026-11-04:21-00/42.ts`; the stream id is the last `#` component of `Channel.id` (0003/AC-6); user and password are percent-encoded as 0016/AC-1; `XtreamClient.timeshiftURL` with `timeZone` nil formats the start in UTC (`2026-11-04:20-00`), while `CatchupURLBuilder` with a context whose `timeZone` is nil yields nil (AC-6).

### AC-5a Server time zone
Given `player_api.php` without an action answering `{"user_info":{...},"server_info":{"timezone":"Europe/Stockholm"}}`
When `accountInfo()` decodes
Then `serverInfo.timezone` is the `String?` "Europe/Stockholm"; a response without `server_info` decodes with `serverInfo` nil and 0003/AC-9 still holds; `XtreamCatchupContext.timeZone` is `TimeZone(identifier:)` of the string, nil when the identifier is unknown.

### AC-5b Catch-up URL, M3U channel in xc mode
Given an M3U channel (an `id` that does not start with `xtream#`) with `catchupMode` "xc", `streamURL` `http://a/live/u/p/42.ts`, `catchupCorrectionHours` 0, the AC-5 request and device time zone `Europe/Stockholm`
When `CatchupURLBuilder.url` runs with `xtream` nil
Then the result is `http://a/timeshift/u/p/45/2026-11-04:21-00/42.ts`, the user, password and id read from the stream URL path and the start formatted in the device time zone shifted by the correction; a stream URL whose path is not `/live/<user>/<pass>/<id>.<ext>` yields nil.

### AC-5c Loader fetches the server time zone
Given an Xtream source load (0004/AC-9)
When the loader runs
Then `accountInfo()` is requested exactly once per load (stubbed `URLProtocol` count) and the zone is kept in memory per `sourceID`, readable by the Start over path; it is never written to a SwiftData record (ADR-0002); a failed `accountInfo()` leaves the zone nil and the channel load unaffected; when the zone is nil at the first Start over evaluation for that source in the process (for example after a launch that reused loaded channels), `accountInfo()` is requested once more and AC-19b re-evaluates when it answers.

### AC-6 Catch-up URL unavailable
Given each row below
When `CatchupURLBuilder.url` runs
Then the result is nil and nothing is requested: `hasCatchup` false; `catchupMode` "vod" or an unknown string; "default" with a template containing a placeholder not listed in AC-2; "default" with `catchupSource` nil; "xc" for an Xtream channel with `xtream` nil (credential not yet synced, 0004/AC-10); "xc" for an Xtream channel whose `XtreamCatchupContext.timeZone` is nil (`accountInfo()` failed, has not run since launch, or named an unknown zone), so Start over falls back to the buffer or is absent rather than playing the wrong hour; a start after `now`; a duration of 0 or less; a start earlier than `now` minus `catchupDays` days when `catchupDays` is greater than 0; a template or stream URL that does not parse as an `http` or `https` URL.

### AC-7 Window arithmetic
Given a window with start 20:00:00, recorded end 20:59:55, live edge 21:00:00 and position 20:48:00, and separately the same window with position 20:59:40
When the window functions run
Then for the first: `clamped(19:50)` is 20:00:00 and `clamped(21:10)` is 20:59:55; `skipping(by: -15)` is 20:47:45 with `reachedLive` false; `isAtLiveEdge` is false; for the second: `skipping(by: 30)` is 20:59:55 with `reachedLive` true (within `liveEdgeTolerance` of the live edge) and `isAtLiveEdge` is true at 20:59:52; `behindLiveText(720)` is "12 min behind", `behindLiveText(3720)` is "1 h 02 min behind", `behindLiveText(5)` is nil, and the minutes are rounded up as 0008/AC-5.

### AC-8 Buffer ring
Given a `TimeshiftBuffer` in a temporary directory with `maxBytes` 1 MiB and `window` 60 seconds, and 1 KiB chunks appended once per injected second for 120 seconds
When `window` and `read(from:)` are read after each append
Then after 120 appends the window is the last 60 seconds and `bytesStored` is at most 60 KiB plus one chunk; with 32 KiB chunks the window shrinks until `bytesStored` is at most 1 MiB plus one chunk, whichever bound is hit first; `read(from: t)` returns the chunk whose instant is the latest at or before `t` and that chunk's instant; `read(from:)` before the window start returns the oldest chunk; the chunk returned by the last `read` is pinned and never evicted before the next `read`; when eviction would remove the pinned chunk, the buffer keeps it as the oldest chunk and emits its instant on `pinnedAtStart`; `discard()` empties the directory and the window is nil.

### AC-8a Buffer location and lifetime
Given a tune to channel C
When recording starts
Then the buffer directory is `<Caches>/se.codecrave.antenna.timeshift/<sessionUUID>/`, every file in it has `isExcludedFromBackup` true, and the directory is deleted on `discard()`, on tuning another channel (AC-24) and on the engine's `stop()`; every path component below `se.codecrave.antenna.timeshift/` matches a UUID or `^[0-9]+\.ts$`, so nothing is derived from `Channel.id` or `streamURL` (ADR-0003, 0014/AC-15).

### AC-8b Storage headroom
Given an injected free-space value F at tune time
When the buffer is created
Then its `maxBytes` is the smaller of `TimeshiftLimits.maxBytes(for:)` and F minus `freeSpaceFloor`; when that is under `minimumUsable` no buffer is created, `supportsTimeshift` reads false for the session, the controls are 0008's and 0010's unchanged (AC-26), and `timeshift.notice` reads "Not enough free storage to rewind live TV" for three seconds the first time in the session the user presses play/pause, not at tune; that first press also pauses per AC-26, and later presses show no notice.

### AC-9 Start over plan
Given each row below with now 21:00 and a current programme 20:00 to 22:00
When `StartOverPlanner.plan` runs
Then: with a catch-up URL the plan is `.catchup(url)` even when the buffer holds 20:00; with no catch-up URL and a window starting at or before 20:00 it is `.buffer(20:00)`; with no catch-up URL and a window starting at 20:10 it is `.unavailable(.outsideWindow)`; with no catch-up URL and a nil window it is `.unavailable(.noCatchupURL)`; with a nil programme it is `.unavailable(.noProgramme)` whatever else is given; the buffer branch uses `window.start <= programme.start`, inclusive.

### AC-10 Pause records into the buffer
Given a channel playing at the live edge with `supportsTimeshift` true
When the user presses play/pause (tvOS), `browse.player.playPause` (other platforms) or a remote command sends pause (`MPRemoteCommandCenter`, test once), and 90 seconds pass on the injected clock
Then the engine's `pause()` is called once, `userPaused` is true, `position` stays at the pause instant, `liveEdge` and `recordedEnd` advance 90 seconds, `timeshift.behindLive` reads "2 min behind" (rounded up, AC-7), `timeshift.positionTime` shows the pause instant in the locale short time style, and `timeshift.knob`'s centre lies at `(position - start) / (liveEdge - start)` of the track width within 2 pt, and at the right end when `liveEdge` equals `start` (the instant of the press).

### AC-11 Resume after a user pause
Given AC-10's paused state
When the user presses play/pause again
Then `play()` is called once with no `seek`, `load` or `stop`, the engine state is `.playing`, and five seconds later on the injected clock `position` has advanced five seconds while `timeshift.behindLive` is unchanged within one minute of rounding.

### AC-12 Skip back and forward
Given a channel playing 10 minutes behind live on tvOS, in full-screen playback with no overlay, pill or guide shown
When the user clicks or swipes left on the clickpad, and then right
Then `seek(to:)` is called with `position - 15` and then with the new position + 30, each clamped per AC-7, the bar is shown and 0008/AC-1's five-second timer restarts; a press shorter than 0.3 seconds is a click and skips on release, 0.3 seconds or longer starts AC-12a's scan; a backward skip at the window start calls `seek` with the window start; a forward skip that reaches the live edge applies AC-13 instead, and one made while `isAtLiveEdge` is already true calls nothing; while the overlay, pill or guide is shown the inputs keep their 0007, 0008 and 0009 meaning and no `seek` is called.

### AC-12c Skip buttons (touch and pointer)
Given a channel playing 10 minutes behind live on iOS, iPadOS or macOS with the strip shown
When the user taps or clicks `timeshift.skipBack` and then `timeshift.skipForward`
Then `seek(to:)` is called as AC-12 says with the same clamping and live-edge rules, and 0010/AC-10b's hide timer restarts.

### AC-12d Arrow keys
Given AC-12c's state with a hardware keyboard and the player focused
When the user presses Left and then Right
Then `seek(to:)` is called as AC-12c; with focus elsewhere the keys keep their system meaning and no `seek` is called.

### AC-12a Scan while held (tvOS)
Given the bar is visible, paused or playing
When the user holds left or right on the clickpad for 2 seconds on the injected clock and releases
Then during the hold `timeshift.positionTime` moves at `scanRate` times real time (120 seconds for a 2 second hold), the picture keeps its state and position, and a single `seek(to:)` is called on release with the shown time clamped per AC-7; when the shown time reaches `liveEdge` during the hold, the hold ends and AC-13 applies at once; when a backward scan reaches `window.start`, the shown time stops there and release seeks to `window.start`; a click in the other direction during a hold is ignored.

### AC-12b Drag (touch and pointer)
Given the strip is visible, paused or playing
When the user drags `timeshift.knob` to 40% of the track and releases
Then during the drag `timeshift.positionTime` follows the finger or pointer and no `seek` is called, the engine state is unchanged, and release calls `seek` once with `start + 0.4 * (liveEdge - start)` clamped; a release at or past the right end applies AC-13 instead.

### AC-13 Return to live
Given a channel playing or paused 10 minutes behind live
When the user holds play/pause for 0.5 seconds (tvOS), taps `browse.player.live` (other platforms), or a skip, scan or drag reaches the live edge
Then on the live stream `seek(to: liveEdge)` is called once and, if paused, `play()` once; during catch-up (AC-20) `load(_:)` is called once with the live `streamURL`, no `seek` is made and a new buffer starts; in both cases, within one second `isAtLiveEdge` is true, the LIVE badge shows the red dot and `timeshift.behindLive` is empty; on tvOS a hold shorter than 0.5 seconds is a plain press (AC-10 or AC-11); on iOS, iPadOS and macOS `browse.player.live` has the `.isButton` trait only while behind live; on tvOS `zapBar.badge.live` never does and is never focusable.

### AC-14 Buffer exhausted
Given a channel paused or playing behind live
When the buffer emits on `pinnedAtStart` (AC-8): a pause longer than the window or than AC-15's byte-capped window, or a position left at the window start while the cap keeps evicting
Then `play()` is called once if paused, `userPaused` becomes false, `seek(to: window.start)` is called once if playing, `timeshift.notice` reads "Buffer full. Playing from the earliest point" for three seconds, and the knob is at the left end of the track.

### AC-15 Byte cap shortens the window
Given `TimeshiftLimits.maxBytes` injected as 4 MiB and a fake engine appending at 25 kbit/s on the injected clock (the same ratio as 4 GiB at 25 Mbit/s)
When 60 minutes pass
Then `window.start` is 23 minutes behind `recordedEnd` within 5%, `timeshift.scrubber`'s accessibility value starts with the locale short time of `window.start`, and while paused `behindLiveText` of `liveEdge - position` never exceeds `behindLiveText(liveEdge - window.start)` sampled at the same instant.

### AC-16 Zap bar timeshift row
Given full-screen playback on tvOS with `supportsTimeshift` true, paused 12 minutes behind live at 21:22 inside a programme 20:00 to 22:00
When the bar is rendered
Then `zapBar.root` is 274 pt tall and contains, after the 0008 now-playing rows, the row `timeshift.stateGlyph` (accessibility value "paused"; "playing" after resume), `timeshift.positionTime` "21:22", `timeshift.scrubber` with `timeshift.played`, `timeshift.buffered` and `timeshift.knob`, and `timeshift.behindLive` "12 min behind"; `zapBar.badge.live` has accessibility value "behind"; `zapBar.hint` reads "Hold play/pause for live" while `isAtLiveEdge` is false and 0008/AC-8's text otherwise; the row is not focusable and focus stays on the player (0008 edge cases).

### AC-16a Bar visibility while paused
Given the bar shown by a pause (AC-10)
When 5, 30 and 300 seconds pass on the injected clock
Then the bar is still visible at each; after `play()` (AC-11) or a skip (AC-12) it hides five seconds later per 0008/AC-1; Menu hides it without changing the engine state (0008/AC-3); while paused with the bar hidden, a skip (AC-12) shows it again without `play()`, and play/pause resumes per AC-11 and shows it for five seconds.

### AC-17 Control strip on touch and pointer platforms
Given inline playback on iOS, iPadOS or macOS with `supportsTimeshift` true
When the controls are shown (0010/AC-10b)
Then the strip has two rows: `timeshift.positionTime`, `timeshift.scrubber`, `timeshift.behindLive` and `browse.player.clock` above; `timeshift.skipBack` (label "Back 15 seconds"), `browse.player.playPause`, `timeshift.skipForward` (label "Forward 30 seconds"), `timeshift.startOver` (label "Start over", present per AC-19's rule), `browse.player.progress`, `browse.player.live` (0010/AC-10a's identifier, kept on every platform), `browse.player.pip` where 0010/AC-13 places it, and `browse.player.fullscreen` below; every button's hit area is at least 44 by 44 pt; with `supportsTimeshift` false the strip is 0010/AC-10a's single row.

### AC-18 Programme at the position
Given a position inside programme P while live is inside the following programme Q
When the bar (tvOS) or the now-playing panel and row (other platforms) are rendered
Then the title, times, summary and `zapBar.next` are P's (from `GuideStore.current(for:at: position)` and `next(for:after: P.stop)`), the programme progress fraction is `(position - P.start) / P.duration` within 0.01, `zapBar.remaining` is `P.stop - position` formatted per 0008/AC-5, and on crossing P's stop while playing behind live the rows switch to Q within five seconds (as 0008 edge cases, with the position in place of now).

### AC-19 Start over is visible when it can work
Given the overlay (0007) open with focus on the playing channel's row, or the touch strip of AC-17, and `StartOverPlanner.plan` for the programme current at the live edge
When the panel or strip is rendered
Then with `.catchup` or `.buffer` the button `overlay.startOver` (tvOS) or `timeshift.startOver` is present and the tvOS focus order is `overlay.watch`, `overlay.startOver`, `overlay.favorite`; with `.unavailable` the button is absent and the order is 0007/AC-14's.

### AC-19a Start over absent for a channel that is not playing
Given the tvOS overlay open with focus on a channel row other than the playing channel, whose programme has catch-up
When the panel is rendered
Then `overlay.startOver` is absent (its buffer does not exist and this spec does not tune and restart in one step).

### AC-19b Start over re-evaluates
Given AC-19's panel or strip with the button absent, and separately present
When `window.start` crosses P's start, a programme boundary passes, the Xtream credential arrives (fake credential store flips), or the server time zone arrives (AC-5c)
Then the button appears or disappears within five seconds on the injected clock, matching a fresh `StartOverPlanner.plan`.

### AC-20 Start over through catch-up
Given AC-19 with a `.catchup(url)` plan for programme P on the playing channel
When the user selects Start over
Then `load(_:)` is called once with exactly `url` (asserted on the fake engine's log, never on an accessibility attribute), the overlay closes on tvOS as 0007/AC-9, the bar or strip shows `timeshift.catchupBadge` "CATCH-UP", `timeshift.positionTime` reads P's start and then follows the engine's `playhead`, the track spans P's start to the live edge, the LIVE badge is in its behind state, and the local buffer of the live stream is discarded after the engine reports `.playing`.

### AC-21 Start over through the buffer
Given AC-19 with a `.buffer(start)` plan
When the user selects Start over
Then `seek(to: start)` is called once and `play()` once if paused, no `load(_:)` is made, and `timeshift.positionTime` reads P's start within one second.

### AC-22 Catch-up answers 404
Given AC-20 where the fake engine fails the catch-up load with an HTTP 404 (and separately any other 4xx or 5xx, a timeout, no network and a TLS failure)
When the failure is reported
Then if the kept live buffer holds P's start, `load(_:)` is called once with the live `streamURL`, `attach` once with the kept buffer and `seek(to: P.start)` once, the row renders as AC-21, and the stretch recorded while the catch-up load ran is a gap that follows AC-25a; otherwise `load(_:)` is called once with the live `streamURL`, `timeshift.notice` reads "Start over isn't available for this programme" for three seconds and the kept buffer is attached again; in both cases no notice, log line or identifier contains the catch-up URL or the stream URL (ADR-0003; the test asserts every recorded log line against both URLs).

### AC-23 Seeking inside catch-up
Given catch-up playback of P started at 20:00, now 21:00, position 20:20
When the user skips back 15 seconds, then skips forward 30 seconds (each more than 400 ms apart), then scans or drags to 20:50, then scans or drags to 21:05
Then `load(_:)` is called with the catch-up URL for start 20:19:45, then 20:20:15, then 20:50:00 (each with duration P.stop minus the new start, rounded up to minutes for `xc`); skips less than 400 ms apart coalesce into one `load(_:)` for the summed delta; a skip back before P's start loads P's start; reaching the live edge during the scan or on release applies AC-12a's or AC-12b's rule and AC-13's catch-up branch, so `load(_:)` is called with the live `streamURL`, after which the badge returns to LIVE with the red dot and a new buffer starts; when the engine reports end of stream during catch-up, `load(_:)` is called with the live `streamURL` without user action and the buffer starts again.

### AC-24 Channel change discards the buffer
Given a channel paused or playing behind live
When another channel is tuned by any means (0008/AC-9, 0007/AC-9, number entry, search, guide)
Then before the new `load(_:)` returns the old session directory is renamed out of the session path (injected file manager log) and no write goes to it after that, it is removed within five seconds on the injected clock without blocking the tune, the new channel plays at its live edge with the LIVE badge red, and `window.start` equals the new tune instant within one second.

### AC-25 Background and return
Given a channel on iOS, iPadOS or tvOS (on tvOS the test sends the scene to background through the Home button in the UI test, and through injected `scenePhase` in integration)
When `scenePhase` becomes `.background` and later `.active`, with the engine running in background neither through PiP nor background audio (0018)
Then if `userPaused` was true, the position is kept and `play()` is not called until the user resumes; if the channel was playing, the system pause leaves `userPaused` false and on `.active` the app seeks to the live edge, discards the buffer, starts a new one and no notice is shown; `.inactive` alone (Control Center, Split View, an alert) changes nothing.

### AC-25c macOS window and sleep
Given a channel on macOS
When the window is hidden, minimised or loses key, and separately when the Mac sleeps and wakes
Then for the window events recording continues and nothing changes; for sleep and wake the recording stops at sleep and AC-25a's gap rule applies on wake, for a paused or a playing position alike.

### AC-25a Gap in the buffer
Given AC-25's first branch: paused at 20:40, backgrounded at 20:45, active again at 20:55
When the user resumes
Then playback runs from 20:40, the track shows `timeshift.buffered` ending at 20:45 and the 0.16 surface from there to the live edge, and when the position reaches 20:45 the app seeks to the live edge, discards the buffer, starts a new one and `timeshift.notice` reads "Skipped ahead to live" for three seconds.

### AC-25b Background with PiP or background audio
Given PiP or background audio active (0018) on iOS or iPadOS
When `scenePhase` becomes `.background` and later `.active`
Then recording continues, `recordedEnd` keeps advancing on the injected clock, AC-14 and AC-15 apply unchanged, and no `seek`, `discard` or notice happens on `.active`.

### AC-26 Engine without timeshift
Given an engine whose `supportsTimeshift` is false (a route that cannot record, or AC-8b)
When the user presses play/pause or `browse.player.playPause`
Then `pause()` is called, the bar is shown without the timeshift row (0008's board) or the strip stays single-row, and the next play/pause calls `play()` then `seekToLive()`, or `load(_:)` of the `streamURL` when `canSeek` is false, so that the picture is live; the position label never appears.

### AC-27 Pauses the user did not ask for
Given a channel playing at the live edge
When 0015/AC-5a pauses the engine behind a content tab, or the audio session is interrupted (a call, Siri), and playback later resumes by 0015/AC-5b or the interruption ending
Then the resume seeks to the live edge first (`seek(to: liveEdge)` then `play()`, or `play()` alone when `isAtLiveEdge` is already true) and the buffer is discarded and restarted; a pause the user made before the tab change keeps its position per AC-27a.

### AC-27b System pause while playing behind live
Given a channel playing 10 minutes behind live with `userPaused` false
When 0015/AC-5a pauses the engine or the audio session is interrupted, and playback later resumes by 0015/AC-5b or the interruption ending
Then `play()` is called once with no `seek`, playback continues from the position it had when paused, and the buffer is kept; the user chose to be behind live, so the app does not jump.

### AC-27a Other screens respect a user pause
Given a pause the user made (AC-10)
When 0015/AC-5b, 0015/AC-6b test a, 0009/AC-1b or 0007/AC-9a would call `play()`
Then the player model calls neither `play()` nor `load(_:)` while `userPaused` is true, and the engine stays `.paused` at its position. How `guide.pip` and the overlay's Watch render this is for 0009 and 0007 (Required of other specs).

### AC-28 Credentials never in the clear
Given an Xtream catch-up URL and an M3U `xc` stream URL that both carry user and password, and a `catchupSource` template carrying them (`...?user=u&pass=p&utc={utc}`)
When any catch-up or live `load(_:)` is made, a notice is shown, an identifier or accessibility value is set, or a log line is written
Then none of them contains the user, the password, the template or either URL; the injected logger receives at most `redacted(url)` (0014/AC-15), the `sourceID` and an error case name; the test asserts every log line, identifier and accessibility value in the hierarchy against the raw credentials.

### AC-29 Stale buffer at launch
Given `<Caches>/se.codecrave.antenna.timeshift/` holding two session directories from a previous process
When the app launches
Then both are deleted before the first `load(_:)` and nothing in them is read; the deletion is recorded by the injected file manager.

### AC-30 Write or read failure
Given a recording buffer whose next `append` throws `.write` (disk full, injected), or whose next `read` throws `.read` (Caches purged by the system)
When the failure happens
Then for a write failure the buffer first discards its oldest 10% of bytes, never the pinned chunk (AC-8), and retries once; if the retry also throws, or on a read failure, recording stops, `supportsTimeshift` reads false for the rest of the session, `seek(to: liveEdge)` is called once if the position was behind live and `play()` once if paused, and playback continues without a `stop()` or `load(_:)`; `timeshift.notice` reads, once for three seconds, "Storage is full. Back to live TV" after a write failure and "Rewind stopped working. Back to live TV" after a read failure, or the same sentences without "Back to live TV" when the position was already live.

### AC-31 Catch-up fields stay in memory
Given an M3U source load whose `catchupSource` carries credentials (`...?user=u&pass=p&utc={utc}`), an Xtream source load, and a channel favorited after both (0005, 0013's `FavoriteSnapshot`)
When every SwiftData record (`SourceRecord`, `FavoriteRecord` and any other model in the container) is fetched and its stored properties are read
Then no stored property contains the template, `u`, `p`, the server time zone or `catchupCorrectionHours`; `Channel.catchupMode`, `catchupSource` and `catchupCorrectionHours` live only on the in-memory `Channel` (ADR-0002, ADR-0003).

### AC-32 Notices are announced
Given VoiceOver running on any platform
When any `timeshift.notice` is shown (AC-8b, AC-14, AC-22, AC-25a, AC-30)
Then an accessibility announcement with the same text is posted once, and the notice text comes from the string catalogue, not a literal in the view.

## Edge cases and failure modes

- Offline or stalled source: `recordedEnd` stops advancing while `liveEdge` continues; the track shows the gap as in AC-25a; a position at `recordedEnd` waits like live buffering (0018 renders it); when bytes return, recording resumes without a new session.
- Slow catch-up load: the bar shows CATCH-UP with the knob at P's start and 0018's buffering rendering until `.playing`; the live buffer is kept until then (AC-22).
- Play/pause during catch-up: `pause()` and `play()` on the catch-up stream; no buffer and no notice; the position label keeps the playhead's time.
- Re-tune of the playing channel after `.failed` (0015/AC-18, 0007/AC-9a): the buffer is kept and `attach`ed to the new load; `recordedEnd` has a gap as AC-25a.
- Huge sources: nothing here scales with channel count; `accountInfo()` is one extra request per Xtream source load (AC-5c).
- Malformed `catchup-source` (unbalanced braces, unknown placeholder, non-URL): AC-6 yields nil, so Start over falls back to the buffer or is absent; nothing is requested.
- Credential not yet synced from iCloud Keychain: AC-6's `xtream` nil row; AC-19 re-evaluates when the credential arrives.
- Guide missing (`loadingState` `.loading`, `.noData`, `.unavailable`, `.failed`): `current(for:at:)` is nil, so Start over is absent (AC-9 `.noProgramme`) and AC-18 falls back to 0008/AC-6a to AC-6c for the position's programme.
- First launch with an empty store: there is no channel, so nothing here is shown; AC-29 still runs.
- tvOS focus: the bar and its timeshift row are never focusable; Start over is reached only through the overlay panel. Swipe and directional click are the same input (README section 4).
- DST: `TimeshiftWindow` works in absolute dates; `{Y}` to `{S}` and the Xtream start use `Calendar` in the named zone, tested with a 2027-03-28 fixture.
- Two programmes overlapping at the position: 0014/AC-6's resolution decides which is "the programme at the position".
- A `catchupDays` of 0 with `hasCatchup` true means unknown depth (0008/AC-8); AC-6 does not reject by age in that case.
- The 0007 overlay opened while paused keeps the paused engine (DR-1 forbids stopping, not an existing pause); Watch on the playing channel follows AC-27a.
- Catch-up `xc` on an Xtream channel with no known server time zone: AC-6 yields nil, so Start over uses the buffer or is absent. M3U channels in `xc` mode use the device time zone shifted by `catchup-correction` (AC-5b), and a playlist without the right correction plays the wrong hour.
- Reduce Motion: the knob jumps instead of animating; notices appear without a slide.
- VoiceOver: on iOS, iPadOS and macOS the scrubber is an adjustable element whose value is `timeshift.positionTime` plus `timeshift.behindLive`, and increment and decrement skip 30 and 15 seconds; on tvOS the bar is announced once as 0008, with the position and behind-live text appended.

## Required of other specs

- ADR (storage): the on-disk ring, its directory and the caps in `TimeshiftLimits`, before this spec is accepted.
- 0017 (playback engine): `supportsTimeshift`, `canSeek`, a `TimeshiftWindow` stream, a `playhead` stream, `seek(to: Date)`, `seekToLive()`, `attach(_ buffer:)`, an end-of-stream event, and the recording hook on both routes (the demuxer writes transport stream bytes; the `AVPlayer` route records through a resource loader or reports `supportsTimeshift` false). `PlaybackState` gains nothing; `.paused` is reused.
- 0018 (player controls): the scrub bar it hides becomes `timeshift.scrubber` and is shown under AC-16 and AC-17; its play/pause handling on tvOS defers to AC-10, AC-11 and AC-13; buffering and error rendering during catch-up loads is its own; PiP and background audio state is read by AC-25 and AC-25b.
- 0007: AC-14 is superseded by AC-19; the panel's focus order gains `overlay.startOver`; AC-9a's `.paused` branch follows AC-27a, and Watch on the playing channel while `userPaused` dismisses the overlay without `load(_:)` or `play()`.
- 0008: AC-2's engine-unchanged clause and the Scope sentence on the play/pause button are superseded by AC-10 and AC-16a; AC-8's hint text changes while behind live (AC-16); `zapBar.badge.live` gains the "behind" state; the open question on swipe left and right is resolved by AC-12.
- 0009: AC-1b does not call `play()` on a user pause (AC-27a); `guide.pip` shows the paused frame with its caption and no live dot while `userPaused`.
- 0013: `FavoriteSnapshot` copies none of the `Channel.catchup*` fields (AC-31).
- 0010: the Out line "Catch-up and timeshift" is removed; AC-10a's single row becomes the `supportsTimeshift` false case and `browse.player.live` is a button while behind live (AC-13).
- 0015: AC-5b and AC-6b test a do not call `play()` on a user pause (AC-27a); the "live-edge position after resume" it leaves to the playback spec is AC-27 here.
- 0001: Scope gains `catchup-source` and `catchup-correction`; `Channel` gains the three fields of AC-1.
- 0003: `XtreamAccountInfo` gains `serverInfo` (AC-5a); `XtreamClient` gains `timeshiftURL`. 0003's Out line "Catch-up (`timeshift`) URLs" is removed.
- 0004: the loader calls `accountInfo()` once per Xtream source load (AC-5c).
- Design README: section 1 gains the buffered fill token and the LIVE behind state of the live dot; section 3 gains the LIVE behind badge state (done in this PR).

## Test plan

Core tests run under `swift test` over fixtures: `M3UParser` (AC-1), `CatchupURLBuilder` and `XtreamClient.timeshiftURL` (AC-2 to AC-6), `TimeshiftWindow` (AC-7), `TimeshiftBuffer` in a temporary directory with an injected clock (AC-8), `StartOverPlanner` (AC-9), decoding (AC-5a). Integration tests drive the player model with a fake engine that records `load`, `play`, `pause`, `seek`, `seekToLive`, `attach`, `stop` to a file in the test's temp directory and publishes injected `TimeshiftWindow` and `playhead` streams, an injected clock, an injected file manager and free-space value, a fake `GuideStore`, a fake credential store and an injected logger. UI tests run on the tvOS and iOS simulators with the same fakes behind launch arguments, with the locale pinned to `en_US_POSIX` and the time zone to UTC, and read frames and accessibility values; text formatting (AC-7, AC-15's value) is asserted in core, UI tests assert frames, identifiers and presence; no accessibility attribute carries anything derived from a URL. Identifiers: `timeshift.scrubber`, `timeshift.track`, `timeshift.played`, `timeshift.buffered`, `timeshift.knob`, `timeshift.positionTime`, `timeshift.behindLive`, `timeshift.stateGlyph`, `timeshift.skipBack`, `timeshift.skipForward`, `timeshift.startOver`, `timeshift.catchupBadge`, `timeshift.notice`, plus 0007's `overlay.startOver`, 0008's `zapBar.*` and 0010's `browse.player.*`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (`M3UParser`) | TBD |
| AC-1a | core (`XtreamClient` mapping) | TBD |
| AC-2 | core (`CatchupURLBuilder`) | TBD |
| AC-3 | core | TBD |
| AC-4 | core (parameterised over four URLs) | TBD |
| AC-5 | core (`XtreamClient`, builder) | TBD |
| AC-5a | core (decoding) | TBD |
| AC-5b | core (builder, M3U `xc`) | TBD |
| AC-5c | integration (`URLProtocol` stub count) | TBD |
| AC-6 | core (parameterised over the rows) | TBD |
| AC-7 | core (`TimeshiftWindow`, two Givens) | TBD |
| AC-8 | core (`TimeshiftBuffer`, temp directory, injected clock) | TBD |
| AC-8a | integration (injected file manager) | TBD |
| AC-8b | integration (injected free space) + ui (notice on play/pause) | TBD |
| AC-9 | core (`StartOverPlanner`) | TBD |
| AC-10 | integration (fake engine, injected clock) + ui (knob frame) | TBD |
| AC-11 | integration | TBD |
| AC-12 | integration (click, swipe, press length; overlay shown case) + ui (timer) | TBD |
| AC-12c | integration + ui (iPhone, macOS) | TBD |
| AC-12d | integration (key events, focus) | TBD |
| AC-12a | ui (tvOS hold) with the fake engine log | TBD |
| AC-12b | ui (iPhone drag, macOS pointer) with the fake engine log | TBD |
| AC-13 | integration + ui (tvOS hold length; iPhone tap; trait per platform) | TBD |
| AC-14 | integration (injected clock, paused and playing) + ui (notice, knob) | TBD |
| AC-15 | integration (injected cap and rate) + ui (scrubber value) | TBD |
| AC-16 | ui (tvOS, behind and at live edge) | TBD |
| AC-16a | ui (tvOS, injected clock) | TBD |
| AC-17 | ui (iPhone, macOS; hit areas) | TBD |
| AC-18 | integration (fake GuideStore) + ui | TBD |
| AC-19 | ui (tvOS overlay focus order; iPhone presence) | TBD |
| AC-19a | ui (tvOS) | TBD |
| AC-19b | integration (four triggers, injected clock) | TBD |
| AC-20 | integration (fake engine log, playhead) + ui (badge, position) | TBD |
| AC-21 | integration | TBD |
| AC-22 | integration (fake engine failing load; attach log; logger) + ui (notice) | TBD |
| AC-23 | integration (fake engine log) | TBD |
| AC-24 | integration (file manager, fake engine log) | TBD |
| AC-25 | integration (scene phase injected; iOS and tvOS; `.inactive`) + ui (tvOS Home) | TBD |
| AC-25a | integration + ui (track, notice) | TBD |
| AC-25b | integration (fake 0018 PiP state) | TBD |
| AC-25c | integration (injected window and sleep notifications) | TBD |
| AC-26 | integration (`canSeek` true and false) + ui | TBD |
| AC-27 | integration (shell model from 0015 with the fake engine) | TBD |
| AC-27b | integration | TBD |
| AC-27a | integration (four callers) | TBD |
| AC-28 | integration (logger, hierarchy scan) | TBD |
| AC-29 | integration (injected file manager) | TBD |
| AC-30 | integration (throwing buffer, write and read; paused and live) + ui (notice) | TBD |
| AC-31 | integration (in-memory SwiftData container, fetch every model) | TBD |
| AC-32 | ui (announcement observer on iOS and tvOS) | TBD |

Device checks, not automated: a 25 Mbit/s 4K stream on an Apple TV 4K filling the 4 GiB cap (AC-15 at real scale) and the real free-space path on an iPhone with under 3 GiB free (AC-8b).

## Open questions

- Storage ADR: on-disk ring in Caches versus memory, and the caps (4 GiB tvOS and macOS, 2 GiB iOS and iPadOS, 60 minutes). The numbers are guesses to be checked against the 150 MB and 400 MB resident budgets and real device storage. The reviewer asked for the ADR in this PR; the brief for this spec says to flag it and leave the record to the owner.
- Catch-up first, buffer second (AC-9) follows the brief and is kept on purpose. The reviewer recommends the buffer first whenever it holds the programme start: it is instant, needs no credentials or time zone and cannot 404, while catch-up discards that buffer and can fail into AC-22. Catch-up first keeps the user on one stream for the rest of the programme and frees the disk. Owner's call; flipping it changes the first row of AC-9 only.
- Skip sizes 15 and 30 seconds and the 60x scan rate are chosen without user data; TiviMate makes them settings.
- Hold play/pause for live on tvOS (AC-13) has no system precedent. Alternatives: a focusable "Go live" item in the bar, which breaks 0008's never-focusable rule, or a double press.
- `{Y}` to `{S}` and the `xc` start for M3U channels use the device time zone shifted by `catchup-correction` (Kodi's behaviour). Providers in another zone need the correction set in the playlist. Should a per-source time zone override exist (settings spec)?
- An Xtream channel without a known server time zone gets no catch-up URL (AC-6), and the app asks `accountInfo()` once more on first need (AC-5c). The alternative was UTC, which plays the wrong hour for most panels.
- A system pause while the user is behind live (AC-27b) resumes where it was. AC-27 returns to live only when the user was already at the live edge.
- On tvOS the hint "Hold play/pause for live" replaces 0008/AC-8's "Press to browse channels" while behind live, so the overlay entry is not advertised then. macOS has no keyboard shortcut for live and no click-to-seek on the track; both wait for a request.
- Resume after background when the user had paused (AC-25a) keeps the position and jumps at the gap. The alternative is to return to live whenever the process was suspended.
- Should the catch-up badge be a filled badge (DR: only NOW and LIVE are filled) when the picture is minutes behind and the user may mistake it for live?
- Does the `AVPlayer` route record (resource loader) in the first implementing PR, or report `supportsTimeshift` false until a later PR?
- AC-27a keeps a user pause through tab changes and the guide. Should a long absence (say ten minutes behind a content tab) still return to live as AC-27 does?
