# Design

## Context

See proposal.md for why. The engine has no screen. The video area shows the picture and subtitles edge to edge and nothing else. Screens that show what it reports: the channel overlay, zap bar, guide grid, Live on iPhone, iPad and Mac, the tvOS shell, player controls and multi-view.

No boards. “Live video keeps playing under overlays” relies on the requirement that starting a channel replaces the old one cleanly; the screen changes claim it. “Nothing fake and nothing bundled” governs the test fixtures.

What the user sees through the screens: the old picture stays until the new channel's first frame; resolution, sound format and languages show once it plays; a drop freezes the last frame while the screen shows "reconnecting, attempt 2 of 8"; paused live TV continues from what is on air; leaving the app or taking a call pauses and returning resumes; a film opens where the user left off, skips, and ends.

The "test server" in the tests is a small web server inside the tests that serves made-up streams and can stall, cut or refuse a connection when told to.

## Goals / Non-Goals

**Goals:**
- One engine contract that both routes pass, run as a contract suite against the fixture server.

**Non-Goals:**
- Live pause and rewind; change `add-timeshift-catch-up-and-start-over` supersedes the live pause and seek rules here.
- Any UI.

## Decisions

- Ships in two steps. Until the FFmpeg engine exists (it waits on the FFmpeg decision record), the router is built with `AVPlayerEngine` for both routes. The change is complete only after the FFmpeg step.
- Contract: `PlaybackEngine` with `states()`, `presentation()`, `tracks()`, `position()` and `subtitleCues()` streams; `load(_:)` kept as an extension forwarding `PlaybackOptions()` so the screens' `load(channel.streamURL)` holds; `RoutedEngine` is "the same engine instance" the overlay, guide grid, Live and shell use. Engines and `PlaybackLifecycle` live in `Apps/Shared/Player/`. `PlaybackOptions` has `startPosition`, an `isLive` override (catch-up passes false) and preferred audio and subtitle languages.
- Numbers: tune policy 3 attempts (0.5 s, 1 s); drop policy 8 attempts (0.5, 1, 2, 4, 8, 10, 10, 10 s); reset after 60 s of play; stall budget 10 s; connect timeout 8 s; no-frame timeout 15 s; read-ahead at most 8 s; `position()` 1 to 4 times a second while playing and once on pause. `.offline` is retried during a reconnect, not at tune.
- Redaction: `guide-data` owns `redacted(_:)` and changes it first. Keep scheme, host and port; the path becomes "/…" plus the last component's extension; query values become "…"; drop userinfo and fragment. Errors never hold the failing URL or an underlying error (`NSURLErrorFailingURL*`, `NSUnderlyingErrorKey`).
- Both engines fetch through an ephemeral `URLSession` with no `URLCache` and no cookies. `DemuxEngine` feeds FFmpeg through a custom AVIO context, so ATS and the `URLError` mapping apply to both, and replaces `av_log` without forwarding FFmpeg's messages.
- Text subtitles reach the app as cues on both routes (`AVPlayerItemLegibleOutput`, player rendering suppressed). Track ids are "audio-n" and "subtitle-n" in stream order.
- Lifecycle: `AVAudioSession` `.playback` / `.moviePlayback`; `UIBackgroundModes: audio` added to the tvOS target for PiP; `NSLocalNetworkUsageDescription` on both targets. Display criteria come from `PresentationInfo` on the demuxer route and `AVAsset.preferredDisplayCriteria` on the system route, not cleared between channels.
- `scripts/check-rules.sh` replaces its AVPlayer check: `AVPlayer`, `AVQueuePlayer`, `AVPlayerItem`, `AVPlayerViewController` and `VideoPlayer` only in `AVPlayerEngine.swift`, `AVPlayerLayer` also in `PlayerSurfaceView.swift`. This supersedes the player view's own `AVPlayer`.
- Owed to other changes: the zap bar and guide grid read badges from `PresentationInfo`; Live reads PiP support from `capabilities`; Movies passes the saved time as `startPosition`; the tvOS shell treats `.buffering` like `.playing` for its pause deadline; multi-view needs 503 and 509 not retried while another tile on the same account plays.
- Fixtures come from `scripts/make-stream-fixtures.sh` with synthetic patterns and tones, no third-party content.
- Test layers: path choice, reason mapping, language choice, retry and reconnect timing run as core tests on a simulated clock; both paths run against the test server; HDR10, the TV mode switch, local network refusal, Picture in Picture and the switching budget run on device.

## Risks / Trade-offs

- [FFmpeg licensing and build are undecided] → the change is blocked on that decision record and assumes an LGPL build linked dynamically.
- Open question: iPhone, iPad and Apple TV cannot decode MPEG-2 video in hardware. A decision allowing software decoding for MPEG-2 only, as the one exception to the hardware decode path, is the likely answer. No requirement changes until then; a test before implementation settles whether the Mac can.
- Open question: a 403 is "not allowed" and never retried, though some Xtream servers answer 403 for "too many connections" just after a switch. Retrying it once would change the tune retry requirement; decide with the multi-view change, which treats a 403 while another tile plays as "provider refused another stream".
- Open question: Apple's player shows black between channels, because the old stream is removed to free its connection. Keeping a still of the last frame would hide it. Can be decided during implementation.
- Open question: reporting Dolby Vision waits for a test stream. Can be decided during implementation.
