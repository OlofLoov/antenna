# Design: hardware playback path for MPEG-TS

## Context

Most IPTV sources deliver raw MPEG-TS over HTTP. `AVPlayer` plays HLS and the
containers the system can demux, but not MPEG-TS. The usual workaround on
Apple TV is a software renderer, and that loses HDR passthrough, Atmos and
display-mode matching.

## Goals / Non-Goals

**Goals:**

- Play MPEG-TS with decoded frames on the system video route, so HDR10,
  Dolby Vision, Atmos and frame-rate matching keep working on Apple TV.
- Keep HLS on `AVPlayer`, which already handles it well.

**Non-Goals:**

- Transcoding streams on device.
- Supporting only HLS sources.

## Decisions

**Two engines behind one protocol.** `PlaybackEngine` is the single playback
interface. `AVPlayer` handles HLS and system-demuxable containers. MPEG-TS
goes through FFmpeg demux, VideoToolbox decode and
`AVSampleBufferVideoRenderer`. `EngineRouter` chooses by URL extension and
defaults to the demuxer. The demuxer hands back to `AVPlayer` when the first
bytes look like HLS.

Options considered:

1. Software renderer (mpv or VLCKit). Rejected because it loses HDR
   passthrough and display-mode matching, which is the product's main
   differentiator.
2. Transcode to HLS on device. Rejected because it adds latency and CPU load
   and still needs a demuxer.
3. Only support HLS. Rejected because it excludes most real-world sources.

## Risks / Trade-offs

- FFmpeg is a large dependency to build for four platforms.
- Licensing must be LGPL-compatible, which means dynamic linking and no GPL
  components.
- HDR behaviour can only be checked on a device, so the HDR smoke checklist
  cannot run in CI.
- Follow-up: a separate decision on how FFmpeg is built and vendored.
