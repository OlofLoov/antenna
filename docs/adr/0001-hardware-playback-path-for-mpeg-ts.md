# 0001. Use a hardware playback path for MPEG-TS

- Status: Accepted
- Date: 2026-11-03

## Context

Most IPTV streams are raw MPEG-TS over HTTP, which `AVPlayer` cannot play.
Competing Apple TV apps route these through a software renderer, which
tone-maps HDR10 and Dolby Vision, drops Atmos, and prevents the Apple TV from
switching display mode to match frame rate. HLS streams play fine in `AVPlayer`.

## Decision

Two engines behind one `PlaybackEngine` protocol. HLS and system-demuxable
containers go through `AVPlayer`. MPEG-TS goes through FFmpeg demux,
VideoToolbox decode, and `AVSampleBufferVideoRenderer` so decoded frames stay
on the system route. `EngineRouter` picks by URL extension and defaults to the
demuxer, which hands back to `AVPlayer` if the first bytes look like HLS.

## Options considered

1. **Software renderer (mpv / VLCKit).** Loses HDR passthrough and display-mode
   matching, which is the product's main differentiator.
2. **Transcode to HLS on device.** Adds latency and CPU load, and still needs a demuxer.
3. **Only support HLS.** Excludes most real-world sources.

## Consequences

- Good: HDR, Dolby Vision, Atmos and frame-rate matching work on Apple TV.
- Bad: FFmpeg is a large dependency to build for four platforms. Licensing
  must be LGPL-compatible (dynamic linking, no GPL components).
- Follow-ups: ADR for how FFmpeg is built and vendored. Device smoke checklist
  for HDR cannot run in CI.
