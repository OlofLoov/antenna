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

- Ships in two steps. Until the FFmpeg engine exists, the router is built with `AVPlayerEngine` for both routes and raw broadcast streams fail as unreadable. The change is complete only after the FFmpeg step.
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

### The FFmpeg path

Options considered for raw broadcast streams, Matroska and AVI:

| Option | Why not, or why |
|---|---|
| FFmpeg decodes everything, our own renderer | Throws away Apple's hardware decoders, HDR handling, Atmos passthrough and PiP, and puts A/V sync on us. |
| VLCKit or mpv | Software renderers with weaker HDR, frame-rate matching and passthrough on Apple TV. Ruled out in the project constraints. |
| KSPlayer or other wrappers | GPL or a commercial licence, and their own playback model to fight. |
| A local server that repackages TS as HLS for Apple's player | No licence questions and AirPlay keeps working, but tuning waits for whole segments (2 to 4 seconds), missing the 1.0 second switching target. No Matroska, no MPEG-2. |
| **FFmpeg unpacks, Apple decodes and renders** | Chosen. FFmpeg only demuxes. Compressed H.264, HEVC, AAC, AC-3 and E-AC-3 go as `CMSampleBuffer`s to `AVSampleBufferVideoRenderer` and `AVSampleBufferAudioRenderer` under one `AVSampleBufferRenderSynchronizer`, which decode in hardware and handle HDR, Atmos passthrough and PiP. |

The pipeline and `DemuxEngine` live in `Packages/AntennaDemux` (`HTTPByteStream`, `Demuxer`, `SampleBuilder`, the engine), which depends on AntennaCore and `Packages/FFmpeg` and runs its tests with `swift test` on macOS, decoding the built sample buffers with VideoToolbox and AVAudioConverter. AntennaCore stays free of FFmpeg and AVFoundation. The pipeline:

```
URLSession (ephemeral) -> AVIO read callback -> libavformat demux
  progressive H.264/HEVC ---------------------------------------> video renderer (decodes)
  interlaced H.264/HEVC -> VTDecompressionSession -> Metal deinterlace -> video renderer (pixel buffers)
  MPEG-2 video -> libavcodec mpeg2video -> Metal deinterlace if interlaced -> video renderer
  AAC / AC-3 / E-AC-3 ------------------------------------------> audio renderer (decodes or passes through)
  MP2 -> libavcodec mp2 -> PCM ----------------------------------> audio renderer
  text subtitles -> cues (as on the system route)
```

- **Build.** `scripts/build-ffmpeg.sh` builds FFmpeg 7.1 (LTS) with `--disable-everything` and then only the demuxers (mpegts, matroska, avi, mov, flv), parsers (h264, hevc, mpegvideo, aac, ac3, mpegaudio), the `mpeg2video` and `mp2` decoders, and no network protocols, since bytes come through our AVIO callback. No `--enable-gpl`, no `--enable-nonfree`. Output is one dynamic `FFmpeg.xcframework` for iOS, tvOS and macOS, device and simulator. A CI workflow builds it on a version tag and attaches it to a GitHub release; `Packages/FFmpeg` is a binary Swift package that points at that release with a checksum. Expected size is 3 to 6 MB per platform.
- **Licence.** LGPL 2.1 is met by dynamic linking, the build script and FFmpeg's source published with the release, and an FFmpeg notice under Settings, About.
- **MPEG-2 and MP2.** No Apple device decodes them in hardware, so they are the one exception to hardware decoding, in software through libavcodec. SD MPEG-2 at 25 or 30 frames a second is well within every supported device.
- **Interlaced video.** The video renderer does not deinterlace. Interlaced streams (the H.264 or HEVC field flags, or MPEG-2's `progressive_sequence` off) are decoded by us and deinterlaced in a Metal compute shader with a motion-adaptive algorithm modelled on bwdif, output at the field rate (1080i50 becomes 1080p50). Progressive streams skip all of this and stay on the cheaper renderer-decodes path. Considered: libavfilter's bwdif on the CPU, too slow for 1080i on Apple TV; bob, which flickers on fine detail.
- **Surround sound.** On tvOS the audio session asks for multichannel output and `AVSampleBufferAudioRenderer` gets compressed AC-3 and E-AC-3 (with Atmos metadata), which the system passes through when the HDMI sink takes it and decodes otherwise. Apple's player does the same on the system route.
- **The old picture stays.** On the FFmpeg path the video renderer keeps its last frame until the first new one is enqueued; flushing waits for that. On the system route `AVPlayerEngine` copies the last frame from an `AVPlayerItemVideoOutput` into a layer over the player before replacing the item and removes it on the new item's first frame.
- **Fast start.** Demuxing starts at the first keyframe, frames before it are dropped, and the first frame is shown as soon as it decodes with read-ahead growing to 8 seconds behind it. When an Xtream account reports more than one allowed connection, the channels above and below the current one are opened ahead and kept at their latest keyframe; with one allowed connection nothing is opened ahead.
- **Zapping.** Several channel changes in one direction within about two seconds mean the user is scanning, not settling. While scanning, the engine opens the next channels in that direction ahead (within the account's connection limit), shows each first picture without waiting for sound, and holds back full read-ahead, TV mode switches and format reports until the user stays on a channel for a moment. That keeps zapping instant without spending connections or flickering the TV between modes.
- **Display mode.** `AVDisplayCriteria` is set from the first frame's format description and kept when the next channel has the same frame rate and dynamic range, so zapping does not re-switch the TV.
- **Languages per channel.** The last audio and subtitle pick per channel is kept in `UserDefaults.standard` under `player.languages`, as a JSON map from channel id to track languages, capped at 500 channels with the oldest dropped. It is per device and holds no address.
- **AirPlay.** The FFmpeg path sends sound over AirPlay, not video; video AirPlay stays with Apple's player (HLS and films).

## Risks / Trade-offs

- The FFmpeg build is ours to keep current. Pinning the LTS release and building it in CI keeps that to a version bump and a rerun.
- The Metal deinterlacer is the part with the least prior art in the codebase. It is checked against fixture streams with moving edges, and a device test on Apple TV confirms it holds 50 frames a second at 1080i.
- Open question: a 403 is "not allowed" and never retried, though some Xtream servers answer 403 for "too many connections" just after a switch. Retrying it once would change the tune retry requirement; decide with the multi-view change, which treats a 403 while another tile plays as "provider refused another stream".
- Open question: reporting Dolby Vision waits for a test stream. Can be decided during implementation.
