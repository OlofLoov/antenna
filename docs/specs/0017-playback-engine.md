# 0017. Playback engine: observable state, tuning, errors and live edge

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0004, 0005
- ADR needed: how FFmpeg is built, licensed and vendored for the demuxer engine (the follow-up ADR-0001 names). The criteria assume an LGPL build linked dynamically as a binary SwiftPM target and hold however it is produced.
- Platforms: iOS, iPadOS, macOS, tvOS. Protocol, router, state, error, retry and redaction types live in AntennaCore. The two engine implementations and the lifecycle observer live in `Apps/Shared/Player/` because they import AVFoundation and AVKit (ADR-0005).
- Builds on specs 0001 (M3U stream URLs), 0003 and 0016 (Xtream stream URLs carry the credentials in the path), 0014 (`redacted(_:)`, `URLError` code sets).
- Supersedes 0004/AC-14: the player screen no longer owns an `AVPlayer`; it holds a `RoutedEngine` (AC-45). The specs that say "blocked on the playback engine spec" (0006, 0007, 0008, 0009, 0010, 0011, 0012, 0015) are blocked on this one. What each needs changed is under "Required of other specs".

## Design

Boards: none, no UI. `PlayerSurfaceView` shows video and subtitle cues edge to edge and draws no controls, text or chrome of its own, so it has no board. Screens that render engine state cite this spec: 0007, 0008, 0009, 0010, 0015 (open PRs), 0018 (player controls), 0022 (multi-view).
Design rules that apply: none directly. DR-1 (video never stops on tvOS) is what AC-7 and AC-9 make possible; the screen specs claim it.

## Problem

Every screen spec tunes channels through `PlaybackEngine` and reads its state, and the protocol today has five states, `load`, `play`, `pause`, `stop`, and a `failed(String)` that carries whatever the system put in the string, stream URL and password included. The only implementation is an `AVPlayer` inside `PlayerView`, which cannot play the raw MPEG-TS most providers serve (ADR-0001). Eight draft specs are blocked on an engine that reports state, picture format, tracks and errors the same way whichever path the stream takes.

## Scope

In:
- `PlaybackEngine` revised: seven states (idle, loading, playing, paused, buffering, ended, failed), `load(_:options:)`, `play`, `pause`, `stop`, `seek(to:)`, track selection, and four `AsyncStream`s (`states()`, `presentation()`, `tracks()`, `position()`), with `load(_:)` kept as a protocol extension so the screen specs' `load(channel.streamURL)` still holds.
- `EngineRouter.route(for:)` kept as the pure function it is, table extended (AC-1).
- `RoutedEngine`, an actor in AntennaCore conforming to `PlaybackEngine`. It owns one engine per route, picks by `EngineRouter`, handles the demuxer's hand-back to the system engine, cancels superseded tunes, runs the retry policy on an injected clock, and forwards state. From the moment `load` is entered until the inner engine's first frame the routed state is `.loading`, whatever the inner engine emits in between. Screens hold one `RoutedEngine` per player surface; "the same engine instance" in 0007, 0009, 0010 and 0015 means this object.
- Two implementations behind the router with the same contract: `AVPlayerEngine` (system route, HLS and system-demuxable containers) and `DemuxEngine` (demuxer route, bytes fetched with `URLSession` and fed to FFmpeg through a custom AVIO context so AC-24 and ATS apply to both engines, FFmpeg demux, VideoToolbox decode, rendering through an `AVSampleBufferDisplayLayer` whose `sampleBufferRenderer` is ADR-0001's `AVSampleBufferVideoRenderer`). Until `DemuxEngine` ships, the app constructs `RoutedEngine` with `AVPlayerEngine` for both routes; nothing else changes. `DemuxEngine` throws `.wrongEngine(.system)` when the first bytes are an HLS playlist; `AVPlayerEngine` never throws `.wrongEngine`, so a `.m3u8` URL that serves raw MPEG-TS fails with `.unsupportedFormat`.
- `PresentationInfo` (video size, frame rate, dynamic range, codecs, channel count) emitted once known, nil before, reset on every tune.
- Tune semantics: `load` starts playback and returns on the first frame; a second `load` cancels the first; switch-time median at most 1.0 s on the demuxer route (AC-44).
- Retry on dropped streams: bounded attempts with backoff, two presets (tune, drop), attempt counter reset after a stable minute, reconnect state visible to the UI.
- Error taxonomy `PlaybackError` mapped from `URLError`, HTTP status, container sniffing and decoder failures. No error or state value carries a URL or credential (ADR-0003).
- `redacted(_:)` for log lines, strengthened so Xtream path credentials disappear too.
- Live edge: `play()` after `pause()` on a live stream resumes at the live edge; VOD resumes where it paused.
- Audio and subtitle track lists, language normalisation, preferred-language selection at load, manual selection. Text subtitles reach the app as cues through `subtitleCues()` on both engines (`AVPlayerEngine` reads them with `AVPlayerItemLegibleOutput` and suppresses the player's own rendering); `PlayerSurfaceView` draws them. Cue styling is 0018's.
- `EngineCapabilities` (Picture in Picture, background audio, track selection, display criteria) exposed by the engine; screens decide what to show.
- Each engine renders into a layer `AVPictureInPictureController` accepts and conforms to the app-side `SurfaceProviding`. `RoutedEngine.activeRoute()` says which route is on screen; `PlayerSurfaceView` in `Apps/Shared/Player/` maps the route to the engine the app built for it and hosts that engine's layer.
- `PlaybackLifecycle` in `Apps/Shared/Player/`: activates `AVAudioSession` with category `.playback` and mode `.moviePlayback` before the first `load` on iOS, iPadOS and tvOS; pauses on background without PiP and on audio interruptions; resumes on foreground and after an interruption that allows it. On macOS the lifecycle never pauses on `.background` and handles no interruptions; closing the window is the screen spec's (0010). AC-41, AC-41a, AC-41b and AC-42 run on iOS, iPadOS and tvOS. `UIBackgroundModes: audio` added to the tvOS target in `project.yml` (Mobile has it) because tvOS PiP requires it.
- tvOS display criteria (frame rate and dynamic range) set from `PresentationInfo` for the demuxer route and from `AVAsset.preferredDisplayCriteria` for the system route.
- `NSLocalNetworkUsageDescription` in `project.yml` for both targets, because LAN sources and the fixture server go through both engines.
- `PlaybackLogger`, a one-method protocol in AntennaCore injected into `RoutedEngine` and both engines; the app passes an `os.Logger` adapter, tests pass a recorder. FFmpeg's `av_log` callback is replaced and never forwards FFmpeg's own messages, which contain the opened URL. Both engines fetch through a `URLSession` with an ephemeral configuration, no `URLCache` and no cookie storage, so no credential-bearing URL reaches disk (ADR-0003).
- A shared `PlaybackEngineContractTests` suite run against every engine with a local fixture server.
- Removal of the `AVPlayer` stopgap from `PlayerView`.

Ships in two steps. Until `DemuxEngine` exists (it waits on the FFmpeg ADR), the app builds `RoutedEngine` with `AVPlayerEngine` for both routes and the PR may mark Implemented only after the demuxer step. The criteria that need `DemuxEngine` are AC-3a, AC-7a, AC-10b, AC-14a, AC-14c, AC-14d, AC-16 (b) and (c), AC-17, AC-18, AC-19 (MKV), AC-26 (c), AC-26a, the demuxer runs of AC-37a, AC-37b, AC-38 and AC-38a, AC-38b, AC-43's demuxer part, AC-46, AC-43a and AC-44's demuxer target; every other criterion holds with `AVPlayerEngine` alone.

Out (explicitly):
- Timeshift buffer, pause-and-rewind of live TV, seeking within live: spec 0019. AC-10a, AC-10b and AC-14 are the behaviour until 0019 supersedes them.
- Player controls UI, user-facing error text and Retry button, the remote's play/pause button (0008's consumption rule stays in force), audio and subtitle pickers, preferred-language settings, subtitle cue styling, Now Playing info and remote commands on the lock screen and Control Center: spec 0018.
- Several engines at once, audio-follows-focus: spec 0022.
- Catch-up and start-over URL construction: the catch-up spec 0007/AC-14 waits for.
- `#EXTVLCOPT` user agent, referrer and other per-stream headers (0001 open question): a source-options spec, which adds a field to `PlaybackOptions`.
- `rtsp`, `rtmp`, `udp` multicast and `mms` streams: a later transport spec. They fail per AC-2 today.
- FairPlay and other DRM. Such streams fail with `.unsupportedFormat`.
- AirPlay and external display of the demuxer route: a later spec.
- Recording.
- Software video decode (MPEG-2 video has no decoder on iOS, iPadOS and tvOS): an ADR-0001 amendment, see Open questions. Known gap: until that amendment, MPEG-2 channels fail on those platforms with `.decodeFailed(.mpeg2)`.
- Bitmap subtitles (DVB, PGS, VobSub) and closed captions in the video stream (CEA-608/708): a later subtitles spec. Such tracks are not listed.
- Watch-progress persistence: spec 0011 consumes `position()`.
- Stalker stream URLs: the Stalker spec.
- The paywall and entitlement check before any playback: the ADR-0006 follow-up spec.

## Types

Names the criteria use. Field lists are the contract; the implementing PR may add private members.

```swift
// Stream factories and capabilities are nonisolated and synchronous: each conformer keeps a
// lock-protected broadcaster, so a subscriber is registered and handed the current value before
// the factory returns. states(), presentation(), tracks() and subtitleCues() buffer .unbounded;
// position() buffers .bufferingNewest(1). A cancelled subscriber's continuation is removed.
// RoutedEngine is an actor and implements these members as nonisolated over that broadcaster.
// AVPlayerEngine and DemuxEngine are @MainActor final classes, which makes them Sendable.
public protocol PlaybackEngine: AnyObject, Sendable {
    var capabilities: EngineCapabilities { get }
    var state: PlaybackState { get async }
    func states() -> AsyncStream<PlaybackState>          // current value first, then changes, no consecutive duplicates
    func presentation() -> AsyncStream<PresentationInfo?> // current value first, no consecutive duplicates
    func tracks() -> AsyncStream<TrackList>              // current value first, no consecutive duplicates
    func position() -> AsyncStream<PlaybackPosition>     // while playing, and on each change to .paused, .buffering, .ended or .failed; never in .idle or .loading
    func subtitleCues() -> AsyncStream<SubtitleCue?>     // cues of the selected subtitle track; nil clears the cue on screen
    func load(_ url: URL, options: PlaybackOptions) async throws  // returns on the first rendered video frame, or on the first decoded audio sample when the stream has no video track; inner engines and RoutedEngine alike
    func play() async
    func pause() async
    func stop() async
    func seek(to position: TimeInterval) async throws
    func select(audio id: Track.ID?) async
    func select(subtitle id: Track.ID?) async
}
extension PlaybackEngine { public func load(_ url: URL) async throws }  // options: PlaybackOptions()

public enum PlaybackState: Sendable, Equatable {
    case idle, loading, playing, paused
    case buffering(ReconnectAttempt?)   // nil: waiting for data; non-nil: reconnecting after a drop
    case ended                          // VOD reached its end; play() restarts at 0
    case failed(PlaybackError)
}
public struct ReconnectAttempt: Sendable, Equatable { public var attempt: Int; public var maxAttempts: Int }
// attempt 1 is the first reconnect after a drop, not the original tune. A reconnect emits no nil
// presentation and no empty track list; after it succeeds presentation() emits only a changed value.

public struct PlaybackOptions: Sendable, Equatable {
    public var startPosition: TimeInterval? = nil          // VOD only
    public var isLive: Bool? = nil                         // overrides detection; catch-up passes false
    public var preferredAudioLanguages: [String] = []      // BCP-47, in order
    public var preferredSubtitleLanguages: [String] = []   // empty means subtitles off
}
public protocol PlaybackLogger: Sendable { func log(_ line: String) }

public struct PresentationInfo: Sendable, Equatable {
    public struct Video: Sendable, Equatable { public var width: Int; public var height: Int; public var frameRate: Double?; public var dynamicRange: DynamicRange; public var codec: VideoCodec }
    public struct Audio: Sendable, Equatable { public var codec: AudioCodec; public var channels: Int?; public var sampleRate: Int?; public var isDecoded: Bool }  // false: the track is present but nothing on the device can decode it
    public var video: Video?   // nil for audio-only streams
    public var audio: Audio?
}
public enum DynamicRange: Sendable, Equatable { case sdr, hdr10, hlg, dolbyVision }
public enum VideoCodec: Sendable, Equatable { case h264, hevc, av1, mpeg2, other(String) }
public enum AudioCodec: Sendable, Equatable { case aac, ac3, eac3, mp2, mp3, dts, opus, flac, pcm, other(String); public var displayName: String }

public struct Track: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable { case audio, subtitle }
    public var id: String; public var kind: Kind; public var language: String?; public var name: String
    public var codec: AudioCodec?; public var channels: Int?; public var isDefault: Bool
}
// Track.id is "<kind>-<n>": n is the track's index among tracks of its kind in stream order ("audio-0", "subtitle-1").
// On the system route codec and channels are nil, because AVMediaSelectionOption does not expose them.
public struct TrackList: Sendable, Equatable {
    public var audio: [Track]; public var subtitles: [Track]
    public var selectedAudio: Track.ID?; public var selectedSubtitle: Track.ID?
    public func selection(for options: PlaybackOptions) -> (audio: Track.ID?, subtitle: Track.ID?)
}
public enum LanguageTag { public static func normalize(_ code: String) -> String? }
public struct SubtitleCue: Sendable, Equatable { public var text: String; public var start: TimeInterval; public var end: TimeInterval }

public struct PlaybackPosition: Sendable, Equatable {
    public var current: TimeInterval
    public var duration: TimeInterval?                // nil for live
    public var seekableRange: ClosedRange<TimeInterval>?   // nil when seeking is impossible
    public var liveEdge: TimeInterval?                // live only, same timeline as current; nil on the demuxer route
    public var isLive: Bool
}
// isLive: PlaybackOptions.isLive when set; else, on the demuxer route, true when the container reports no
// duration and the response has no Content-Length; on the system route, true when AVPlayerItem.duration is indefinite.
// Live on both routes: seekableRange is nil until 0019 adds a buffer.
// Demuxer route on live: current is media seconds presented since the connection opened, liveEdge is nil.
// System route on HLS live: current and liveEdge are on AVPlayerItem's timeline and liveEdge is the end
// of its seekable ranges. A VOD whose server ignores Range requests has seekableRange nil and isLive false.

public enum PlaybackError: Error, Sendable, Equatable {
    case offline, connectionLost, timeout, hostUnreachable, tlsFailed, network(URLError.Code)
    case unauthorized, notFound, serverBusy, serverError(Int), httpStatus(Int)
    case unsupportedScheme(String), invalidURL, unsupportedFormat, decodeFailed(VideoCodec)
    case streamEnded                                 // the server closed a live stream or a VOD before its end
    case stalled, notSeekable
    case wrongEngine(EngineRouter.Route)             // internal hand-back; never reaches a UI
    public init?(urlError: URLError)                 // nil for .cancelled
    public init?(httpStatus: Int)                    // nil for 2xx
}

public struct RetryPolicy: Sendable, Equatable {
    public static let tune: RetryPolicy   // maxAttempts 3; attempt 1 is the first try, delays 0.5 s and 1 s before attempts 2 and 3
    public static let drop: RetryPolicy   // maxAttempts 8; attempt 1 is the first reconnect, delays 0.5, 1, 2, 4, 8, 10, 10, 10 s before attempts 1 to 8
    // A reconnect load is one attempt; the tune policy applies only to loads the caller starts.
    public var maxAttempts: Int
    public func delay(beforeAttempt n: Int) -> Duration?   // nil when n > maxAttempts
    public func retries(_ error: PlaybackError) -> Bool
}

public struct EngineCapabilities: Sendable, Equatable {
    public var pictureInPicture: Bool, backgroundAudio: Bool, trackSelection: Bool, displayCriteria: Bool
}

public enum EngineRouter { public enum Route { case system, demuxer }; public static func route(for url: URL) -> Route }
public actor RoutedEngine: PlaybackEngine {
    public init(engines: @Sendable (EngineRouter.Route) -> any PlaybackEngine, clock: any Clock<Duration>, policies: (tune: RetryPolicy, drop: RetryPolicy), logger: any PlaybackLogger)
    public func activeRoute() -> AsyncStream<EngineRouter.Route?>  // current value first; changes at the new route's first frame; nil after stop()
    // capabilities: the active route's engine, or the system engine's while idle
}

// Apps/Shared/Player, imports AVKit. Both engines conform.
@MainActor public protocol SurfaceProviding {
    var surfaceLayer: CALayer { get }
    var pictureInPictureSource: AVPictureInPictureController.ContentSource { get }
}
public func redacted(_ url: URL) -> String
```

## User flow

The engine has no screen. What a screen sees:

1. The screen holds one `RoutedEngine` and subscribes to `states()`, `presentation()`, `tracks()` and `position()`.
2. The user picks a channel. The screen calls `load(channel.streamURL)`. State goes `.loading`. The previous channel's last frame stays on the surface until the new channel's first frame.
3. First frame: `.playing`, and `load` returns. `PresentationInfo` arrives and 0008 draws its badges. `TrackList` arrives and 0018 fills its pickers.
4. The stream drops. State goes `.buffering(ReconnectAttempt(attempt: 1, maxAttempts: 8))`, the picture stays on the last frame, and the engine reconnects on the schedule. Success returns to `.playing`. Exhaustion ends in `.failed(error)`, which 0018 renders.
5. The user pauses live TV. The picture freezes. `play()` returns to the live edge.
6. The app goes to the background without PiP, or a phone call comes in. The engine pauses. On return it plays again, at the live edge for live, where it stopped for VOD.
7. The user plays a movie at a saved position: `load(url, options: PlaybackOptions(startPosition: p))`. `seek(to:)` scrubs. `position()` feeds 0011/AC-16. At the end of the movie the state is `.ended`; 0018 decides what to show.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber. "Fake" means a `PlaybackEngine` conformance in the core test target that records calls and emits what the test tells it to. "Fixture server" means the local HTTP server in the Xcode test target that serves the files in `Tests/Fixtures/Streams` and can stall, close or refuse a connection on command.

### AC-1 Route table
Given the URLs `http://h/a.m3u8`, `http://h/a.M3U8?token=x`, `http://h/a.mp4`, `http://h/a.mov`, `http://h/a.m4v`, `http://h/a.mp3`, `http://h/a.aac`, `http://h/a.m4a` and `file:///tmp/a.mp4`, and the URLs `http://h/live/u/p/42.ts`, `http://h/a.TS?x=1`, `http://h/a.mpegts`, `http://h/a.mkv`, `http://h/a.avi`, `http://h/live/u/p/42`, `http://h/` and `http://h`
When `EngineRouter.route(for:)` runs on each
Then the first group returns `.system` and the second `.demuxer`; the extension is read from the path only and compared case-insensitively.

### AC-2 Unsupported URLs fail before any request
Given `rtsp://h/s`, `udp://@239.0.0.1:1234`, `rtmp://h/s`, `mms://h/s`, `http:///a.ts` and `a.ts` and a `RoutedEngine` over fakes
When `load(_:)` runs on each
Then it throws `.unsupportedScheme("rtsp")`, `.unsupportedScheme("udp")`, `.unsupportedScheme("rtmp")`, `.unsupportedScheme("mms")`, `.invalidURL`, `.invalidURL`; `state` is `.failed` with the same error; no fake received `load`; the injected clock has no pending sleep.

### AC-3 Hand-back from the demuxer
Given a demuxer fake whose `load` throws `.wrongEngine(.system)` and a system fake that reaches `.playing`
When `load(url)` runs for a URL routed to `.demuxer`
Then the system fake receives `load` once with the same URL and options, the demuxer fake received `stop()` before the system fake's `load` was entered, and `states()` emitted `.loading` then `.playing` with no `.failed` between.

### AC-3a Hand-back with real bytes
Given `http://127.0.0.1:<port>/live/u/p/42` on the fixture server whose body is an HLS playlist, and a `RoutedEngine` over the real engines
When `load` runs
Then the state reaches `.playing`, `states()` emitted no `.failed`, and the server saw the demuxer's connection close before the system engine's first request.

### AC-4 Hand-back happens once
Given both fakes throw `.wrongEngine` pointing at each other
When `load(url)` runs
Then each fake received `load` once, `load` throws `.unsupportedFormat` and `state` is `.failed(.unsupportedFormat)`.

### AC-5 State stream replays and deduplicates
Given a `RoutedEngine` whose state is `.paused`
When a new subscriber iterates `states()` and the active fake then reports `.paused`, `.playing`, `.playing`, `.buffering(nil)`
Then the subscriber receives `.paused`, `.playing`, `.buffering(nil)` in that order and nothing else.

### AC-6 A tune loads, plays and returns on the first frame
Given state `.idle` and a system fake that reports `.playing` 300 ms on the injected clock after its `load` is entered
When `load(url)` is awaited
Then a `states()` subscriber saw `.loading` before the fake's `load` was entered and `.playing` before `load` returned, the fake received `load` once and no `play()`, and `presentation()` and `tracks()` subscribers received nil and an empty list before the fake's `load` was entered.

### AC-7 A second tune cancels the first
Given `load(A)` in flight on a fake that completes only when told, or A `.playing` or `.paused`, with B on the same route as A or on the other route
When `load(B)` is called
Then an in-flight `load(A)` call throws `CancellationError`, the fake that held A recorded `stop()` before `load(B)` was entered on B's fake, `states()` shows `.loading` with no `.idle`, `.failed` or `.paused` in between, and `.playing` once B's fake completes.

### AC-7a The surface keeps the last frame across a tune on the demuxer route
Given A `.playing` on `PlayerSurfaceView` through `DemuxEngine`, and B on the demuxer route too
When `load(B)` is called, or A's stream drops
Then `DemuxEngine.stop()` closes A's connection and keeps the image: until B's first frame, or until the drop's reconnect succeeds, the surface hosts the same layer instance and its renderer receives no `flush(removingDisplayedImage: true)` and the layer no `flushAndRemoveImage()`; when the routed state becomes `.failed`, or the caller calls `stop()` on the `RoutedEngine`, the surface removes the image. The system route makes no last-frame promise (Open questions).

### AC-7b A tune across routes swaps the layer at the first frame
Given A `.playing` on one route and B on the other
When `load(B)` is called
Then `activeRoute()` emits B's route only when B's fake reports its first frame, and `PlayerSurfaceView` hosts A's layer until then and B's layer after; whether A's layer still shows an image in between depends on A's engine (see Open questions).

### AC-8 Stop
Given `load(A)` in flight, or state `.playing`
When `stop()` is called
Then an in-flight `load` throws `CancellationError`, `state` is `.idle`, `presentation()` emits nil, `tracks()` emits an empty list, `position()` emits nothing further, and the fake received `stop()`.

### AC-8a Stop from any state
Given a `RoutedEngine` over fakes in `.paused`, `.ended`, `.failed(.notFound)`, `.buffering(nil)` and `.idle`
When `stop()` is called
Then the state is `.idle`, `position()` emits nothing afterwards, and in every case but `.idle` the active fake received `stop()`; from `.idle`, `states()` emits nothing.

### AC-8b A new engine is quiet
Given a newly constructed `RoutedEngine` over fakes
When subscribers iterate all five streams for 5 seconds and nothing calls `load`
Then they receive `.idle`, nil, an empty `TrackList`, nil from `subtitleCues()` and nothing from `position()`, and no fake received any call.

### AC-9 Play and pause do nothing where there is nothing to do
Given states `.idle`, `.loading`, `.failed(.notFound)`, `.ended` and `.paused` for `pause()`, and `.idle`, `.loading`, `.playing`, `.buffering(nil)`, `.buffering(ReconnectAttempt(attempt: 1, maxAttempts: 8))` and `.failed(.notFound)` for `play()`
When the call is made
Then the fake received no call and `states()` emitted nothing. `play()` from `.ended` is AC-13a's restart.

### AC-9a Pause while buffering
Given `.buffering(nil)`, or `.buffering(ReconnectAttempt(attempt: 2, maxAttempts: 8))` with a sleep pending on the injected clock
When `pause()` is called
Then the pending sleep is cancelled, the fake receives `stop()`, no `load` happens until `play()`, the state is `.paused`, and `play()` is a fresh tune of the same URL and options, with `startPosition` set to the last `current` for VOD and nil for live, and the attempt counter at 1.

### AC-10a Pause and resume on live returns to the live edge
Given a live stream `.playing` on each engine against the fixture server (`position().isLive` true)
When `pause()` is called, 20 seconds pass and `play()` is called
Then after `pause()` the state is `.paused`; after `play()` the state is `.playing` within 3 seconds and the first `position()` value in `.playing` has `liveEdge - current` at most 10 on the system engine, and on the demuxer engine `current` under 2, because `play()` opens a new connection (AC-10b) and `current` counts from it.

### AC-10b Pause on live frees the demuxer's connection
Given a live stream `.playing` on the demuxer engine against the fixture server
When `pause()` is called, 20 seconds pass and `play()` is called
Then the fixture server saw the connection close within 2 seconds of `pause()` and exactly one new request for the URL after `play()`.

### AC-11 Pause and resume on VOD keeps the position
Given a VOD fixture `.playing` with `current` 120
When `pause()`, 20 seconds and `play()`
Then the state is `.playing` within 2 seconds and the first `position()` value after it has `current` within 1 second of 120.

### AC-12 Start position
Given `PlaybackOptions(startPosition: 300)` on a 600-second VOD fixture
When it is loaded
Then the first `position()` value in `.playing` has `current` within 2 seconds of 300.

### AC-12a Start position beyond the end
Given `PlaybackOptions(startPosition: 900)` on the same 600-second fixture
When it is loaded
Then the first `position()` value in `.playing` has `current` under 2 and the state is not `.ended`.

### AC-12b Start position on live is ignored
Given `PlaybackOptions(startPosition: 300)` on a live fixture
When it is loaded
Then the first `position()` value in `.playing` has `liveEdge - current` at most 10 when `liveEdge` is non-nil, else `current` under 2.

### AC-13 Seek on VOD
Given a VOD fixture `.playing` with `seekableRange` 0...600
When `seek(to: 450)` and then `seek(to: 590)` are called
Then within 2 seconds of each the state is `.playing`, having passed through at most `.buffering(nil)`, and `current` is within 1 second of 450 and then of 590.

### AC-13b Seek beyond the end clamps
Given AC-13's fixture `.playing`
When `seek(to: 900)` is called
Then `seek` does not throw and within 2 seconds `states()` emits `.ended` with the last `position()` value's `current` within 1 second of 600.

### AC-13a End of a VOD item
Given a 600-second VOD fixture `.playing` at 598
When it reaches its end
Then `states()` emits `.ended`, `position()` emits one final value with `current` within 1 second of `duration`, and until `play()` the server receives no new request and no reconnect is attempted.

### AC-13c Play after the end restarts
Given AC-13a's fixture in `.ended`
When `play()` is called
Then the state is `.playing` within 2 seconds and the first `position()` value has `current` under 2.

### AC-14 Seek on live throws
Given a live stream `.playing` on each engine, a TS loop on the demuxer and a rolling HLS playlist on the system engine
When `seek(to: 10)` is called
Then `position().seekableRange` is nil, `seek` throws `.notSeekable` and `states()` emitted nothing.

### AC-14a VOD without Range support
Given a 600-second VOD fixture served with Range requests ignored (200 with the full body for every request)
When it is loaded on the demuxer engine with `startPosition: 300`
Then the first `position()` value in `.playing` has `isLive` false, `seekableRange` nil and `current` under 2.

### AC-14c Seek without Range support throws
Given AC-14a's fixture `.playing` on the demuxer engine
When `seek(to: 100)` is called
Then it throws `.notSeekable` and `states()` emitted nothing.

### AC-14d Resume without Range support starts over
Given AC-14a's fixture `.playing` on the demuxer engine
When `pause()` is called, 20 seconds pass and `play()` is called
Then the server saw a new request after `play()` and the first `position()` value in `.playing` has `current` under 2.

### AC-14e The system engine refuses media without Range support
Given an MP4 copy of AC-14a's fixture served the same way, so the router picks the system engine
When it is loaded
Then the state is `.failed(.unsupportedFormat)` within 5 seconds.

### AC-14b Seek with nothing loaded throws
Given a `RoutedEngine` over fakes in `.idle`, `.loading` and `.failed(.notFound)`
When `seek(to: 10)` is called
Then it throws `.notSeekable`, no fake received `seek` and `states()` emitted nothing.

### AC-15 Position cadence
Given a stream `.playing`
When 5 seconds pass
Then `position()` emitted at least 1 and at most 4 values in each whole second of the first 5, with non-decreasing `current`.

### AC-15b Position on pause
Given AC-15's stream after its first 5 seconds
When `pause()` is called and 5 seconds pass
Then `position()` emits exactly one value on `pause()` and none in the 5 seconds after.

### AC-15c Duration
Given a VOD fixture and a live fixture `.playing`
When the first `position()` value is read
Then `duration` is non-nil for the VOD and nil for the live one.

### AC-15a No position while loading
Given a `RoutedEngine` over a fake that stays in `.loading` for 3 seconds before its first frame
When a subscriber iterates `position()` from the `load` call
Then it receives nothing until `.playing`.

### AC-16 Presentation arrives once known
Given fixtures (a) HLS, 1280 by 720, 25 fps, H.264, AAC 2.0; (b) MPEG-TS, 1920 by 1080, 50 fps, HEVC HLG, E-AC-3 5.1; (c) MPEG-TS audio only, MP2 2.0
When each is loaded on the engine the router picks
Then `presentation()` emitted nil at `load` and, within 2 seconds of `.playing`, (a) `Video(1280, 720, 25 ±0.1, .sdr, .h264)` and `Audio(.aac, 2, 48000)`; (b) `Video(1920, 1080, 50 ±0.1, .hlg, .hevc)` and `Audio(.eac3, 6, 48000)`; (c) `video` nil and `Audio(.mp2, 2, 48000)`; `isDecoded` is true in all three.

### AC-17 HDR10
Given an MPEG-TS fixture with HEVC HDR10 (static metadata from `make-stream-fixtures.sh`) on an Apple TV 4K
When it plays
Then `dynamicRange` is `.hdr10` and the TV reports an HDR10 signal in its info panel. Dolby Vision is an open question until a fixture source exists.

### AC-18 Presentation change mid-stream
Given a demuxer fixture that switches from 720p25 to 1080p50 at 10 seconds
When it plays past the switch
Then `presentation()` emits exactly two non-nil values, the second within 2 seconds of the first `position()` value whose `current` is at least 10.

### AC-19 Track list
Given fixtures with audio `eng` AAC 2.0 (default) and `deu` E-AC-3 5.1 and text subtitles `eng` and `swe`: an MKV for the demuxer and an HLS multivariant playlist with `EXT-X-MEDIA` renditions for the system engine
When each is `.playing`
Then within 2 seconds `tracks()` emits audio `[("audio-0", "en", .aac, 2, isDefault true), ("audio-1", "de", .eac3, 6, false)]` in stream order, subtitles `[("subtitle-0", "en"), ("subtitle-1", "sv")]`, `selectedAudio` "audio-0" and `selectedSubtitle` nil; on the system engine `codec` and `channels` are nil.

### AC-20 Language normalisation
Given the codes `eng`, `deu`, `ger`, `fra`, `fre`, `swe`, `nor`, `zho`, `chi`, `en`, `EN-us`, `xyz`, `und`, `mul`, `qaa` and `""`
When `LanguageTag.normalize` runs
Then the results are "en", "de", "de", "fr", "fr", "sv", "no", "zh", "zh", "en", "en-US", "xyz", nil, nil, nil, nil. The rule: a code in the table maps to its two-letter form; a code not in the table is returned with the language lowercased and the region uppercased; `und`, `mul`, `qaa` to `qtz` and empty give nil. The table covers at least the ISO 639-2/B and 639-2/T codes for eng, deu/ger, fra/fre, spa, ita, por, nld/dut, swe, nor, dan, fin, pol, rus, tur, ara, heb, ell/gre, hun, ces/cze, ron/rum, hrv, srp, bul, ukr, hin, zho/chi, jpn, kor.

### AC-21 Preferred languages
Given AC-19's list and `preferredAudioLanguages` ["sv", "de"] with `preferredSubtitleLanguages` ["sv"]; then ["it"] with []; then [] with ["it"]
When `TrackList.selection(for:)` runs, and when the fixture is loaded with the same options
Then the selection is (de, sv), (default audio, nil), (default audio, nil); a subtitle track that matches no preference is never selected.

### AC-22 Manual track selection
Given AC-19's fixture `.playing`
When `select(audio: deID)` and then `select(audio: "bogus")` are called
Then `tracks()` emits `selectedAudio == deID` within 1 second, `presentation().audio` becomes `Audio(.eac3, 6, 48000, isDecoded: true)` within 2 seconds, the state leaves `.playing` only for `.buffering(nil)` and for at most 2 seconds, and the bogus id produces no emission from `tracks()` or `presentation()`.

### AC-22a Subtitle selection
Given AC-19's fixture `.playing`, whose `sv` track has the cue "Hej" from 12 to 14 seconds and whose `en` track has "Hello" at the same time
When `select(subtitle: svID)` is called before 12 seconds
Then `tracks()` emits `selectedSubtitle == svID` within 1 second and `subtitleCues()` emits a cue with text "Hej" within 1 second of `current` reaching 12, then nil by 14.

### AC-22b Subtitles off
Given AC-22a's fixture `.playing` before 12 seconds
When `select(subtitle: svID)` and then `select(subtitle: nil)` are called
Then `tracks()` ends with `selectedSubtitle == nil` and `subtitleCues()` emits no cue between 12 and 14 seconds.

### AC-23 Tracks reset on tune
Given AC-22's manual selection
When `load(otherURL, options:)` runs with `preferredAudioLanguages` ["en"]
Then `tracks()` emits an empty list and `presentation()` emits nil before the engine's `load` is entered and, after `.playing`, the new stream's list with the selection AC-21 gives for those options, not the previous manual choice.

### AC-24 URLError mapping
Given every `URLError.Code` below
When `PlaybackError(urlError:)` runs
Then `.notConnectedToInternet` and `.dataNotAllowed` give `.offline`; `.networkConnectionLost` gives `.connectionLost`; `.timedOut` gives `.timeout`; `.cannotFindHost`, `.dnsLookupFailed` and `.cannotConnectToHost` give `.hostUnreachable`; `.secureConnectionFailed`, `.serverCertificateUntrusted`, `.serverCertificateHasBadDate`, `.serverCertificateHasUnknownRoot`, `.serverCertificateNotYetValid` and `.clientCertificateRejected` give `.tlsFailed`; any other code c gives `.network(c)`; `.cancelled` gives nil.

### AC-24b Cancelled requests surface as cancellation
Given each real engine with a `load` in flight against the fixture server, which holds the response
When the calling task is cancelled
Then `load` throws `CancellationError`, not a `PlaybackError`, and the state is `.idle`.

### AC-25 HTTP status mapping
Given statuses 200, 206, 401, 403, 404, 410, 429, 503, 500, 502, 504, 509 and 418
When `PlaybackError(httpStatus:)` runs
Then 200 and 206 give nil; 401 and 403 give `.unauthorized`; 404 and 410 give `.notFound`; 429 and 503 give `.serverBusy`; 500, 502, 504 and 509 give `.serverError(n)`; 418, and any other status outside 2xx such as an unfollowed 3xx, 400, 407 or 416, gives `.httpStatus(n)`.

### AC-24a System engine errors map through the same tables
Given `AVPlayerEngine` against the fixture server answering 401, 404 and 503, refusing the connection, and serving (a) of AC-26
When each is loaded
Then the states are `.failed(.unauthorized)`, `.failed(.notFound)`, `.failed(.serverBusy)` after the tune policy, `.failed(.hostUnreachable)` and `.failed(.unsupportedFormat)`: the engine reads the underlying `URLError` code through AC-24 or the HTTP status in the `CoreMediaErrorDomain` error through AC-25, and maps anything it cannot read to `.unsupportedFormat`.

### AC-26 Unplayable bodies and codecs
Given the fixture server answers 200 with (a) an HTML login page, (b) 4 MB of random bytes, (c) an MPEG-TS whose video is MPEG-2, (d) a 302 to a URL with a token in its path that answers (a), and (e) raw MPEG-TS at a `.m3u8` URL
When each is loaded
Then within 5 seconds of the first byte the state is `.failed(.unsupportedFormat)` for (a), (b), (d) and (e), and for (c) `.failed(.decodeFailed(.mpeg2))` on iOS, iPadOS and tvOS and `.playing` on macOS, where VideoToolbox decodes MPEG-2 (a spike confirms this before implementation; if it does not, macOS joins the other three). The server received one request per URL, or two for (d); no reconnect was attempted.

### AC-26a Audio nothing can decode
Given an MPEG-TS fixture with H.264 video and one DTS audio track
When it is loaded on the engine the router picks
Then the state reaches `.playing`, video plays without sound, and `presentation().audio` is `Audio(.dts, 6, 48000, isDecoded: false)`; 0018 decides what to say.

### AC-27 No secrets in error or state values
Given every `PlaybackError` case, including `.unsupportedScheme` built from a provider string, and `PlaybackState.failed` of each, constructed in a core test; and, in the Xcode test target, every state, error, `TrackList` and `PresentationInfo` value that `RoutedEngine` over each real engine emits or throws while it holds `http://alice-7f3e:s3cr3t-9b2a@127.0.0.1:<port>/live/alice-7f3e/s3cr3t-9b2a/7731942.ts?token=t0k3n` when the fixture server answers 403 and when the port refuses the connection
When `String(describing:)` and `String(reflecting:)` of each value and `(error as NSError).userInfo` of each error are read
Then none contains `alice-7f3e`, `s3cr3t-9b2a`, `t0k3n`, `:<port>`, `/live/` or `7731942`, and `userInfo` has no `NSURLErrorFailingURLStringErrorKey`, `NSURLErrorFailingURLErrorKey` or `NSUnderlyingErrorKey`.

### AC-28 Redaction
Given `http://h:8080/live/alice/s3cr3t/42.ts`, `http://h/get.php?username=a&password=b&type=m3u`, `http://u:p@h/x/y.m3u8`, `http://h/stream`, `http://h/`, `http://[2001:db8::1]:8080/a/b/c.ts`
When `redacted(_:)` runs
Then the results are `http://h:8080/….ts`, `http://h/….php?username=…&password=…&type=…`, `http://h/….m3u8`, `http://h/…`, `http://h/`, `http://[2001:db8::1]:8080/….ts`: scheme, host and port kept, a path other than empty or "/" replaced by "/…" followed by the last component's extension if it has one, every query value replaced by "…" keeping the names, userinfo and fragment dropped.

### AC-29 Log lines are redacted
Given a recording `PlaybackLogger` injected into `RoutedEngine` and both engines, and the AC-27 URL failing with 403, then playing and stalling
When the engines log
Then no recorded line contains `alice-7f3e`, `s3cr3t-9b2a`, `t0k3n`, `/live/` or `7731942`, and at least one line contains `redacted(url)` (`http://127.0.0.1:<port>/….ts`) and the `PlaybackError` case name.

### AC-29a Nothing credential-bearing reaches disk
Given AC-29's run on each real engine
When it ends
Then no file under the app container's `Library/Caches`, `Library/Cookies` or `tmp` contains `alice-7f3e`, `s3cr3t-9b2a`, `t0k3n` or `7731942`.

### AC-30 Retry schedule
Given `RetryPolicy.tune` and `RetryPolicy.drop`
When `delay(beforeAttempt:)` runs
Then tune has `maxAttempts` 3, `delay(beforeAttempt: 1)` is `.zero`, 0.5 s before 2, 1 s before 3 and nil before 4; drop has `maxAttempts` 8 with 0.5, 1, 2, 4, 8, 10, 10, 10 s before attempts 1 to 8 (45.5 s in all) and nil before 9.

### AC-30a Retryable errors
Given `RetryPolicy.tune` and `RetryPolicy.drop`
When `retries(_:)` runs on every `PlaybackError` case
Then tune retries `.serverBusy`, `.serverError`, `.connectionLost` and `.streamEnded` and nothing else, so not `.timeout`, `.stalled`, `.hostUnreachable` or `.offline`; drop retries those four plus `.timeout`, `.stalled`, `.hostUnreachable` and `.offline`; neither retries `.network`, `.unauthorized`, `.notFound`, `.httpStatus`, `.tlsFailed`, `.unsupportedScheme`, `.invalidURL`, `.unsupportedFormat`, `.decodeFailed`, `.notSeekable` or `.wrongEngine`.

### AC-31 A dropped stream is reconnected
Given a fake that reached `.playing` for a VOD URL loaded with `preferredAudioLanguages` ["en"], a manual `select(audio: deID)` and `select(subtitle: svID)` applied, whose last `PlaybackPosition` had `current` 95 and `isLive` false, and that then reports `.failed(.streamEnded)`
When the drop is observed
Then `states()` emits `.buffering(ReconnectAttempt(attempt: 1, maxAttempts: 8))`, never `.failed`; the fake receives `load` with the same URL after 0.5 seconds on the injected clock and not before; when the fake reports `.playing` the state is `.playing`.

### AC-31a The reconnect resumes where the drop happened
Given AC-31's drop, and a second run whose last `PlaybackPosition` had `isLive` true
When the reconnect `load` is made
Then its options are the original options with `startPosition` 95 in the first run and nil in the second.

### AC-31b The reconnect keeps manual track choices
Given AC-31's drop, and a new `TrackList` after the reconnect that contains `deID` but not `svID`
When the fake reports `.playing`
Then the `RoutedEngine` calls `select(audio: deID)` on the fake once and makes no `select(subtitle:)` call.

### AC-31c A reconnect keeps presentation and tracks
Given AC-31's drop, and a fake whose new `PresentationInfo` after the reconnect equals the old one
When the reconnect runs and succeeds
Then `presentation()` emits nothing across it and `tracks()` emits no empty list; with a fake whose new `PresentationInfo` differs, `presentation()` emits only the new value.

### AC-32 Reconnect attempts are exhausted
Given a fake that fails every `load` with `.streamEnded` after one successful play
When the clock advances through the schedule
Then the fake received exactly 8 further `load` calls at 0.5, 1.5, 3.5, 7.5, 15.5, 25.5, 35.5 and 45.5 seconds after the drop, the state after the eighth failure is `.failed(.streamEnded)`, no further `load` happens, and a subsequent `load(_:)` from the caller starts at attempt 1. Each reconnect is one `load` call; the tune policy does not run inside it.

### AC-33 The attempt counter resets after a stable minute
Given the fake reconnected on attempt 3 and then reports `.playing`
When it drops again after 60 seconds or more of continuous `.playing`, and in a second run after 20 seconds
Then the next `ReconnectAttempt.attempt` is 1 in the first run and 4 in the second.

### AC-34 Non-retryable failures end at once
Given a fake `.playing` that reports `.failed(e)` for e in `.unauthorized`, `.notFound`, `.unsupportedFormat`, `.decodeFailed(.mpeg2)`, `.tlsFailed`
When the failure is observed
Then the state is `.failed(e)` with no `.buffering` before it, the fake received no further `load`, and the clock has no pending sleep.

### AC-34a Offline during a reconnect is retried
Given a fake `.playing` that reports `.failed(.connectionLost)`, then throws `.offline` from its first two reconnect `load` calls and reaches `.playing` on the third
When the clock advances through the schedule
Then the state goes `.buffering` with attempts 1, 2 and 3 and then `.playing`, and never `.failed`.

### AC-35 Tune failures use the tune policy
Given a fake whose `load` throws `.serverBusy` twice and then reaches `.playing`; and a fake that throws `.serverBusy` three times; and a fake that throws `.timeout` once
When `load(url)` is awaited for each
Then the first received `load` three times at 0, 0.5 and 1.5 seconds and `load` returned with the state `.playing` having stayed `.loading` throughout; the second received `load` three times and `load` threw `.serverBusy` with the state `.failed(.serverBusy)`; the third received `load` once and `load` threw `.timeout`.

### AC-36 Load or stop during backoff cancels the retry
Given a reconnect scheduled for 4 seconds ahead
When `load(B)` or `stop()` is called 1 second in
Then the fake never receives the scheduled `load(A)`, the clock's pending sleep is cancelled, and the state is `.loading` then `.playing` for `load(B)` or `.idle` for `stop()`.

### AC-37a A short stall recovers on the same connection
Given a live stream `.playing` on a `RoutedEngine` over each real engine: the TS loop on the demuxer, the rolling HLS playlist on the system engine
When the fixture server pauses for 5 seconds (the TS body sends no bytes; the HLS playlist and segments are held unanswered)
Then the state is `.buffering(nil)` no later than 2 seconds after `position().current` stops advancing, and `.playing` within 2 seconds of the server resuming, with no new request for the TS URL or the playlist beyond the ones in flight.

### AC-37b A long stall reconnects
Given the same setup
When the fixture server pauses for 15 seconds
Then between 9 and 11 seconds after the state became `.buffering(nil)` the engine fails with `.stalled` (exactly 10 on the injected clock in the `RoutedEngine` core test), the `RoutedEngine` emits `.buffering(ReconnectAttempt(attempt: 1, maxAttempts: 8))`, and the server receives a new request.

### AC-38 Connect timeout
Given the fixture server accepts the connection and sends nothing
When `load(url)` runs on each engine
Then `load` throws `.timeout` between 8 and 9 seconds after the call, the state is `.failed(.timeout)`, and on the demuxer engine the server saw exactly one connection.

### AC-38a Bytes without a frame time out
Given the fixture server sends MPEG-TS whose PMT lists an H.264 video and an AAC audio stream but no packets of either arrive (PAT and PMT only, repeated), and the same for an HLS playlist whose segments carry only those PAT and PMT
When `load(url)` runs on each engine
Then `load` throws `.timeout` between 15 and 16 seconds after the call and the state is `.failed(.timeout)`.

### AC-38b A PMT with nothing decodable
Given MPEG-TS whose PMT lists only private data streams (stream type 0x06 with no known descriptor)
When `load(url)` runs on the demuxer engine
Then the state is `.failed(.unsupportedFormat)` within 5 seconds of the first byte.

### AC-39 Capabilities
Given `AVPlayerEngine` and `DemuxEngine` on iOS, iPadOS, tvOS and macOS
When `capabilities` is read
Then `pictureInPicture`, `backgroundAudio` and `trackSelection` are true on every platform for both engines and `displayCriteria` is true on tvOS only. On macOS `backgroundAudio` is true because nothing pauses playback there (Scope, `PlaybackLifecycle`).

### AC-39a Routed capabilities
Given a `RoutedEngine` over a system fake and a demuxer fake with different `capabilities`
When `capabilities` is read while idle, while the demuxer fake plays, and after a hand-back to the system fake
Then it is the system fake's, the demuxer fake's, and the system fake's.

### AC-40 The surface is a PiP-capable layer
Given each engine `.playing` with its layer hosted by `PlayerSurfaceView` and handed to `AVPictureInPictureController` on iOS, iPadOS, tvOS and macOS
When `isPictureInPicturePossible` is observed
Then it becomes true within 2 seconds of `.playing`.

### AC-40b PiP start and stop leave the state alone
Given AC-40's setup on a device
When PiP is started, then stopped, with no PiP control pressed
Then `states()` emits nothing across start and stop.

### AC-40a PiP controls drive the engine
Given AC-40's PiP window open on a `.playing` stream
When its play/pause control is pressed twice
Then the engine receives `pause()` and then `play()`, and `states()` emits `.paused` then `.playing` (at the live edge for live, per AC-10a). The PiP window shows skip buttons of 15 seconds on VOD, which call `seek(to:)`, and none on live, where `DemuxEngine`'s sample-buffer playback delegate reports an indefinite time range.

### AC-41 Background without PiP pauses
Given `PlaybackLifecycle` on iOS, iPadOS or tvOS observing a fake engine in `.playing` or `.buffering(nil)` and an injected scene-phase stream, with PiP inactive
When the phase becomes `.background`
Then the fake receives `pause()` once within 1 second.

### AC-41c Background while loading
Given the same lifecycle observing a `RoutedEngine` over a fake in `.loading` for URL u with options o
When the phase becomes `.background`, and later `.active`
Then on background the in-flight `load` is cancelled and the fake receives `stop()` within 1 second, so no audio plays in the background; on active the fake receives `load(u, options: o)` once.

### AC-41d Background that keeps playing
Given AC-41's setup with PiP active, and separately with the lifecycle constructed with `continueInBackground` true
When the phase becomes `.background`
Then the fake receives no call.

### AC-41e Headphones unplugged
Given `PlaybackLifecycle` on iOS or iPadOS observing a fake `.playing` and an injected route-change stream
When a route change arrives with reason `.oldDeviceUnavailable`, and later the device returns
Then the fake receives `pause()` once and no `play()`.

### AC-41a Audio interruptions
Given `PlaybackLifecycle` on iOS, iPadOS or tvOS observing a fake engine `.playing` and an injected stream of `AVAudioSession.interruptionNotification` (a call or alarm on iPhone, Siri or another app taking audio on Apple TV)
When an interruption begins, and then ends with `.shouldResume`, or ends without it
Then the fake receives `pause()` once at the start; `play()` once when the end carries `.shouldResume`; nothing when it does not. An engine already `.paused` by the user when the interruption begins receives no call at the start or the end.

### AC-41b Background while reconnecting
Given `PlaybackLifecycle` on iOS, iPadOS or tvOS observing a `RoutedEngine` over a fake in `.buffering(ReconnectAttempt(attempt: 2, maxAttempts: 8))` with a sleep pending, PiP inactive
When the phase becomes `.background`, and later `.active`
Then on background the pending sleep is cancelled, the fake receives `stop()` and no `load`, and the state is `.paused` (AC-9a); on active the fake receives one `load` per AC-9a's fresh tune.

### AC-42 Foreground resumes what the lifecycle paused
Given AC-41 paused the engine, and separately a user-paused engine that was `.paused` before backgrounding
When the phase becomes `.active`
Then the first fake receives `play()` once and the second receives nothing.

### AC-43 Display criteria on tvOS
Given an Apple TV 4K with Match Frame Rate and Match Dynamic Range on, the demuxer engine playing AC-16's fixture (b), and separately the system engine playing an HLS fixture whose `AVAsset.preferredDisplayCriteria` reports 50 Hz HLG
When `PresentationInfo` arrives, and later `stop()` is called
Then within 1 second the window's `AVDisplayManager.preferredDisplayCriteria` has refresh rate 50 and dynamic range HLG and the TV switches mode; after `stop()` it is nil.

### AC-43a Display criteria follow the stream
Given AC-43's setup with the demuxer engine playing AC-18's fixture, and separately a tune from a 25 fps channel to a 50 fps channel
When the presentation changes mid-stream, or the new channel's `PresentationInfo` arrives
Then within 1 second `AVDisplayManager.preferredDisplayCriteria` has the new frame rate, and it was not set to nil between the two channels.

### AC-44 Switch time
Given 50 channel changes between MPEG-TS fixtures with a 1-second keyframe interval over a wired LAN on an Apple TV 4K (3rd generation) with Match Frame Rate and Match Dynamic Range off, and 50 between HLS fixtures with 2-second segments
When the time from `load` to the first rendered frame is measured
Then the demuxer route's median is at most 1.0 second and its 90th percentile at most 1.5 seconds; the system route's median is at most 2.0 seconds. The target binds on Apple TV only; on iPhone, iPad and Mac the same run is recorded for comparison.

### AC-45 One AVPlayer in the app
Given the repository
When `scripts/check-rules.sh` runs
Then the identifiers `AVPlayer`, `AVQueuePlayer`, `AVPlayerItem`, `AVPlayerViewController` and `VideoPlayer`, matched on word boundaries in lines that are not `//` comments (as the script's other checks do), occur in no Swift file under `Apps/` other than `Apps/Shared/Player/Engines/AVPlayerEngine.swift`; `AVPlayerLayer` may additionally occur in `Apps/Shared/Player/PlayerSurfaceView.swift`; `Apps/Shared/Player/PlayerView.swift` contains `RoutedEngine`. The rule replaces the script's existing "Apps do not construct AVPlayer outside the engine" check. A swift-testing test in the Xcode test target runs the script and carries the citation `0017/AC-45`, because `check-specs.sh` accepts only a Swift citation for a non-device criterion.

### AC-46 Read-ahead is bounded
Given a 40 Mbit/s MPEG-TS live fixture that the fixture server sends as fast as the connection allows
When it plays for 30 seconds on the demuxer engine
Then the bytes the server has sent never exceed the bytes for `position().current` plus 8 seconds of stream, plus 10 %.

### AC-47 Local network refused
Given the local network permission denied for the app on iPhone, and a stream on a LAN host
When it is loaded
Then the state is `.failed(.hostUnreachable)` or `.failed(.network(code))` within 10 seconds and no reconnect is attempted.

## Required of other specs

- 0004/AC-14 is superseded by AC-45 and by 0010/AC-6 and 0015/AC-2a on their platforms.
- 0007, 0009, 0010, 0015: fakes conform to the revised protocol; the asserted `load(_:)` call is the extension that forwards `PlaybackOptions()`. "The same engine instance" is the `RoutedEngine`. No criterion text changes.
- 0008/AC-7: name the fields: `presentation.video?.height` for resolution, `presentation.audio?.channels` and `presentation.audio?.codec.displayName` for the audio badge. `.buffering` is not `.playing`, so LIVE and the format badges are absent during a reconnect, as 0008's edge case already says.
- 0008/AC-9 "a swipe while a tune is still loading cancels that load" is AC-7 here; cite it.
- 0009/AC-8a: resolution text comes from `presentation.video?.height` through 0008/AC-7's mapping.
- 0010/AC-13: "the engine reports PiP support" is `capabilities.pictureInPicture`.
- 0011/AC-10a: pass the saved position as `PlaybackOptions(startPosition:)` (AC-12) rather than seeking after load; 0011/AC-16 reads `position()`; `seek(to:)` and `duration` are AC-13 and `PlaybackPosition.duration`.
- 0014/AC-15: 0014 owns `redacted(_:)` and its refinement lands before 0017 is implemented. The function is shared and now replaces the path with "/…" plus the extension (AC-28), so 0014/AC-15's "keeps scheme, host, port and path" becomes "keeps scheme, host and port"; its query and userinfo rules are unchanged. 0014's `.networkConnectionLost` stays in its offline set; playback maps it to `.connectionLost` and retries it (AC-24), because a connection lost mid-stream is the drop case and the guide's is a download that can wait for the next refresh.
- 0015/AC-5a: treat `.buffering` like `.playing` for the 30-second pause deadline, otherwise a reconnecting stream keeps a connection open behind Movies.
- 0015 edge case "return from background: the same engine instance resumes the same channel" is AC-41 and AC-42 here.
- 0006/AC-8 and 0010/AC-20 keep their offline code sets; they classify source loads, not playback.
- 0018 (player controls) owns the user-facing text for every `PlaybackError` case, the Retry action after `.failed`, the remote's play/pause button and the track pickers. 0019 (timeshift) supersedes AC-10a, AC-10b and AC-14 when it lands. 0022 (multi-view) constructs one `RoutedEngine` per tile.
- Each of these edits lands as a refinement PR on the affected spec before that spec is marked Accepted; until then this list is the record of what is owed.

## Edge cases and failure modes

- Offline at tune: the first request fails with `.offline` and the tune policy does not retry it (AC-30); 0018 offers Retry. Offline mid-stream surfaces as `.connectionLost` or `.stalled`, and reconnect attempts that meet `.offline` keep going until the drop policy is exhausted (AC-34a); there is no reachability monitor in the engine.
- Slow source: no first byte for 8 seconds is `.timeout` (AC-38). A source that sends bytes but no frame within 15 seconds is `.timeout` (AC-38a); one that stops sending after the first frame is a stall (AC-37a, AC-37b).
- Huge source: tens of thousands of channels do not touch the engine; flipping through them quickly is AC-7, which closes the previous connection before opening the next so a provider with a one-connection cap sees one connection at a time. A provider that still answers 429 or 503 for a moment after a switch is covered by the tune policy (AC-35). One that answers 403 for an over-limit connection fails at once as `.unauthorized`, because a 403 cannot be told apart from a revoked credential; see Open questions.
- Malformed data: an HTML body, random bytes, a redirect to a login page, raw TS at a `.m3u8` URL (AC-26), a relative or schemeless URL from a bad playlist line (AC-2). A TS whose PMT lists no decodable stream is `.unsupportedFormat`. A stream whose only audio cannot be decoded plays silently with `isDecoded` false (AC-26a).
- Credential not yet synced: a source without its Keychain item contributes no channels (0004/AC-10), so the engine never sees it. A stale or revoked credential arrives as 401 or 403 and is `.unauthorized`, not retried.
- tvOS focus and remote: nothing here is focusable. The remote's play/pause is 0008's and 0018's.
- First launch with an empty store: no `load` is ever called; the engine stays `.idle` and emits only its initial values (AC-8b).
- Pause on live closes the demuxer's connection at once (AC-10b), freeing the provider's connection slot. The system engine lets `AVPlayer` keep its buffer; `play()` seeks to the live edge. Both behaviours end when 0019 adds the buffer.
- Audio-only streams (radio): `presentation.video` is nil; the surface shows nothing and the screen decides what to draw.
- MPEG-2 video, common on SD rebroadcasts, has no decoder on iOS, iPadOS and tvOS; it fails with `.decodeFailed(.mpeg2)` and 0018 says so. Until the ADR-0001 amendment, those channels do not play on those platforms. See Open questions.
- Local network: the first stream from a LAN host triggers the system's local network prompt on iOS, iPadOS, tvOS and macOS; refusing it makes the connection fail, which maps to `.hostUnreachable` or `.network(code)` like any other refusal (AC-47).
- Leaving the app while a reconnect is pending stops the retry rather than opening connections in the background (AC-41b).
- A 302 to a URL carrying a token: the redirected URL is never kept in an error value (AC-27) and is redacted in logs like any other.
- IPv6 literal hosts survive redaction unchanged (AC-28).
- Memory: the demuxer holds at most 8 seconds of compressed data ahead of the decoder and stops reading when full (AC-46); a paused live stream holds nothing because the connection is closed.
- Two `RoutedEngine`s in one process (0022) share nothing; a hand-back in one does not affect the other.
- `PresentationInfo` never carries a URL or title; `Track.name` comes from the stream's own metadata, which providers sometimes fill with their own branding, and is shown as is.
- Reduce Motion and VoiceOver: no UI here.

## Test plan

Pure functions and the `RoutedEngine` are swift-testing tests in AntennaCore with fakes and an injected clock. Engine implementations run under a shared `PlaybackEngineContractTests` suite in the Xcode test target, parameterised over `[AVPlayerEngine, DemuxEngine]`, against a fixture server that serves `Tests/Fixtures/Streams` (HLS, MPEG-TS, MKV, audio-only, HTML, random bytes, resolution switch, DTS audio, PAT/PMT only). It has these modes: endless live TS (a loop with continuous timestamps), a rolling live HLS playlist with 2-second segments, Range honoured or ignored, redirect, pause for n seconds, close, refuse, and accept-and-send-nothing. It records every connection open, request and close with a timestamp in order, which AC-3a, AC-10b, AC-37a and AC-37b read. Timing, HDR, display criteria and PiP on a television are device checks on an Apple TV 4K (3rd generation). The fixtures are generated by `scripts/make-stream-fixtures.sh` with FFmpeg from synthetic test patterns and tones, with a 1-second keyframe interval and the subtitle cues AC-22a names, so no third-party content is checked in (DR-12).

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-3a | integration (real engines, fixture server) | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core | TBD |
| AC-7a | integration (`PlayerSurfaceView`, demuxer) | TBD |
| AC-7b | integration (`PlayerSurfaceView`, fakes) | TBD |
| AC-8 | core | TBD |
| AC-8a | core | TBD |
| AC-8b | core | TBD |
| AC-9 | core (parameterised) | TBD |
| AC-9a | core | TBD |
| AC-10a | integration (both engines, fixture server) | TBD |
| AC-10b | integration (demuxer, fixture server) | TBD |
| AC-11 | integration | TBD |
| AC-12 | integration | TBD |
| AC-12a | integration | TBD |
| AC-12b | integration | TBD |
| AC-13 | integration | TBD |
| AC-13b | integration | TBD |
| AC-13a | integration | TBD |
| AC-13c | integration | TBD |
| AC-14 | integration | TBD |
| AC-14a | integration (fixture server, Range ignored) | TBD |
| AC-14c | integration (demuxer) | TBD |
| AC-14d | integration (demuxer, fixture server) | TBD |
| AC-14e | integration (system engine) | TBD |
| AC-14b | core | TBD |
| AC-15 | integration | TBD |
| AC-15a | core | TBD |
| AC-15b | integration | TBD |
| AC-15c | integration | TBD |
| AC-16 | integration (three fixtures) | TBD |
| AC-17 | device | manual, Apple TV 4K info panel |
| AC-18 | integration (demuxer) | TBD |
| AC-19 | integration (both engines) | TBD |
| AC-20 | core | TBD |
| AC-21 | core (`selection(for:)`) + integration | TBD |
| AC-22 | integration | TBD |
| AC-22a | integration (both engines) | TBD |
| AC-22b | integration (both engines) | TBD |
| AC-23 | integration | TBD |
| AC-24 | core | TBD |
| AC-24b | integration (both engines) | TBD |
| AC-25 | core | TBD |
| AC-24a | integration (system engine, fixture server) | TBD |
| AC-26 | integration | TBD |
| AC-26a | integration | TBD |
| AC-27 | core (constructed values) + integration (system engine errors) | TBD |
| AC-28 | core | TBD |
| AC-29 | integration (injected logger) | TBD |
| AC-29a | integration (app container) | TBD |
| AC-30 | core | TBD |
| AC-30a | core | TBD |
| AC-31 | core | TBD |
| AC-31a | core | TBD |
| AC-31b | core | TBD |
| AC-31c | core | TBD |
| AC-32 | core | TBD |
| AC-33 | core | TBD |
| AC-34 | core (parameterised) | TBD |
| AC-34a | core | TBD |
| AC-35 | core | TBD |
| AC-36 | core | TBD |
| AC-37a | integration | TBD |
| AC-37b | integration | TBD |
| AC-38 | integration | TBD |
| AC-38a | integration | TBD |
| AC-38b | integration (demuxer) | TBD |
| AC-39 | integration (per platform) | TBD |
| AC-39a | core | TBD |
| AC-40 | integration (simulator) | TBD |
| AC-40b | device | manual, PiP start and stop on iPhone, iPad, Mac and Apple TV |
| AC-40a | device | manual, PiP window on iPhone and Apple TV |
| AC-41 | integration (`PlaybackLifecycle`, fake engine) | TBD |
| AC-41a | integration (`PlaybackLifecycle`, fake engine) | TBD |
| AC-41b | integration (`PlaybackLifecycle`, `RoutedEngine` over a fake) | TBD |
| AC-41c | integration (`PlaybackLifecycle`, `RoutedEngine` over a fake) | TBD |
| AC-41d | integration | TBD |
| AC-41e | integration (injected route changes) | TBD |
| AC-42 | integration | TBD |
| AC-43 | device | manual, Apple TV 4K with a mode-reporting display |
| AC-43a | device | manual, Apple TV 4K with a mode-reporting display |
| AC-44 | device | manual, Instruments signposts over 50 switches per route |
| AC-45 | ci script | `scripts/check-rules.sh` |
| AC-46 | integration (demuxer, fixture server) | TBD |
| AC-47 | device | manual, local network permission denied on iPhone |

## Open questions

Decisions made without an interview. Each can be overturned at review.

- Live resume goes to the live edge (AC-10a), not to where the user paused, until 0019 ships a real buffer. The alternative is a few minutes of `AVPlayer` buffer that stops without warning, which is the TiviMate complaint the research names.
- `redacted(_:)` keeps no path segment, only the extension (AC-28). The last component is a token on some providers (Stalker `/play/<token>`, tokenised redirects), so keeping it would leak; logs lose the stream id, and the `sourceID` and channel id the caller logs carry that instead.
- `.offline` is retried during a reconnect and not at tune (AC-30, AC-34a). A Wi-Fi blip mid-stream should not end playback; offline at tune is better answered with 0018's Retry at once.
- 403 is `.unauthorized` and never retried, even though some Xtream panels answer 403 for "too many connections" for a moment after a switch. Retrying it once on the tune policy is the alternative; it delays the revoked-credential case by 0.5 s.
- The last frame stays up across a tune only on the demuxer route (AC-7a, AC-7b). `AVPlayerLayer` goes black once its item is removed to close the connection, which AC-7 requires before the next tune. A snapshot of the last frame in `PlayerSurfaceView` would hide the difference; not required here.
- This spec stays one document although it cannot reach Implemented before `DemuxEngine` ships. The reviewer proposed splitting it into a core-and-`AVPlayerEngine` spec, a `DemuxEngine` spec after the FFmpeg ADR, and a lifecycle, PiP and display-criteria spec, so the eight blocked screen specs unblock on the first. I kept one spec so the contract stays in one place; the split is a cheap follow-up if the owner prefers it.
- `isLive` detection on the demuxer route needs both no duration and no `Content-Length`, and catch-up passes `PlaybackOptions.isLive` false, so a `.ts` recording is not treated as live.
- Text subtitles are drawn by the app from `subtitleCues()` on both routes (AC-22a), so the demuxer and `AVPlayer` look the same. The cost is giving up `AVPlayer`'s own subtitle rendering and its accessibility caption styles until 0018 restyles cues.
- `startPosition` beyond the duration starts at 0 (AC-12a), but `seek` beyond the end clamps and ends (AC-13b). A stale saved position should not open a movie on its last frame; a user dragging past the end means the end.
- Retry numbers: tune 3 attempts (0.5 s, 1 s), drop 8 attempts (0.5 to 10 s, 45.5 s total), counter reset after 60 seconds of play, stall budget 10 seconds, connect timeout 8 seconds. TiviMate's five retries are a user grievance; eight plus a reset is the compromise.
- `load` starts playback and returns on the first frame (AC-6). 0015/AC-2a's `play()` after `load` is then a no-op, which AC-9 allows.
- `.networkConnectionLost` is retried rather than classed as offline (AC-24), unlike 0006, 0010 and 0014. Playback is the one place where the distinction pays.
- Background without PiP pauses (AC-41). Background audio exists as a capability and a `continueInBackground` flag on the lifecycle; which setting drives it, and whether radio channels get it by default, belongs to 0018 or a settings spec.
- One `redacted(_:)` for guide and stream URLs, strengthened to hide path segments (AC-28). 0014 loses nothing it needs.
- Engines live in `Apps/Shared/Player/Engines/` because ADR-0005 says AntennaCore imports Foundation only. Allowing AVFoundation in a second core target would let the contract suite run under `swift test` on macOS; not proposed here.
- Only `http`, `https` and `file` URLs are supported (AC-2). Multicast and RTSP sources exist in the wild and get a later spec.
- MPEG-2 video has no decoder on iOS, iPadOS and tvOS, and macOS needs checking (AC-26 (c)). ADR-0001 says VideoToolbox decode; an amendment allowing FFmpeg software decode for MPEG-2 only, with no HDR implications, is the likely answer. Until it lands this is a known gap: those channels show 0018's "format not supported" text.
- The demuxer reads bytes through `URLSession` into FFmpeg's AVIO (Scope), not FFmpeg's own HTTP client, so ATS, the local network prompt and AC-24's mapping apply the same way on both routes. The FFmpeg ADR may overturn this.
- Display criteria on tvOS are set by the app on both routes (AC-43): from `PresentationInfo` for the demuxer route and from `AVAsset.preferredDisplayCriteria` for the system route. The app does not use `AVPlayerViewController`, which would otherwise do it for the system route.
- `AudioCodec.displayName` uses short tokens ("AAC", "AC3", "EAC3", "DTS") rather than trademarks. The design README's badge example is "AAC 5.1".
- The sub-second target (AC-44) applies to the demuxer route only. HLS start-up through `AVPlayer` is bounded by segment length.
- `Track.name` is shown as the stream provides it, branding included. Stripping it is a UI decision for 0018.

## Dropped

- AC-10 Pause and resume on live: split into AC-10a (resume at the live edge, both engines) and AC-10b (the demuxer closes its connection on pause), because the second holds for one engine only.
- AC-37 Stall detection: split into AC-37a (short stall recovers) and AC-37b (long stall reconnects), so each scenario passes or fails on its own.
