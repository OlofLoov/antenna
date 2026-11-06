# Proposal: use a hardware playback path for MPEG-TS (adr-0001)

## Why

Most IPTV streams are raw MPEG-TS over HTTP, which `AVPlayer` cannot play.
Competing Apple TV apps route these through a software renderer, which
tone-maps HDR10 and Dolby Vision, drops Atmos, and stops the Apple TV from
switching display mode to match frame rate. HLS streams play fine in
`AVPlayer`.

Accepted on 2026-11-03.

## What Changes

- Two playback engines sit behind one `PlaybackEngine` protocol.
- HLS and containers the system can demux play through `AVPlayer`.
- MPEG-TS plays through FFmpeg demux, VideoToolbox decode and
  `AVSampleBufferVideoRenderer`, so decoded frames stay on the system route.
- `EngineRouter` picks the engine by URL extension and defaults to the
  demuxer, which hands back to `AVPlayer` if the first bytes look like HLS.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- HDR, Dolby Vision, Atmos and frame-rate matching work on Apple TV.
- FFmpeg becomes a large dependency to build for four platforms. Its
  licensing must stay LGPL-compatible, with dynamic linking and no GPL
  components.
- Follow-ups: a decision on how FFmpeg is built and vendored, and a device
  smoke checklist for HDR, which cannot run in CI.
