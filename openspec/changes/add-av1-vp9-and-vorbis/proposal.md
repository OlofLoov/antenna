# Proposal

## Why

> As a viewer with films from my provider in AV1 or VP9, or with Vorbis sound, I want them to play on the devices that can decode them, and to be told plainly on the ones that cannot.

The red-route stream review (2026-11-21, playback item 8) found AV1 and VP9 failing outright on the FFmpeg path with "can't decode av1" or "can't decode vp9", even on devices whose video decoder handles them: AV1 on A17 Pro, M3 and later, and VP9 on Macs through VideoToolbox. Vorbis sound has no decoder in the FFmpeg build at all, so a Matroska film with Vorbis sound plays silent.

The owner decided on 2026-11-21: AV1 and VP9 decode on the FFmpeg path in hardware only, gated on the device saying it decodes the codec in hardware. Without it, the stream goes to Apple's player when Apple's player can play it, and otherwise fails with the existing "can't decode" reason naming the codec. No software AV1 or VP9 decoder is added. FFmpeg's LGPL Vorbis decoder is added for sound.

## What Changes

- The FFmpeg path builds AV1 pictures from the container's av1C and VP9 pictures with a vpcC made from the stream's profile, level, bit depth and colors, and hands them to VideoToolbox, when the device decodes that codec in hardware. VP9 asks VideoToolbox for its supplemental decoder first.
- On a device without that hardware, an AV1 or VP9 stream in MP4 or QuickTime goes to Apple's player, and any other fails as "can't decode av1" or "can't decode vp9".
- Apple's player, handed a file whose AV1 or VP9 picture it cannot decode, fails with the same reason instead of handing it back.
- FFmpeg's `vorbis` decoder joins the build, and Vorbis sound decodes in software like DTS and TrueHD once the new FFmpeg build is published.

Out of scope: software AV1 or VP9 decoding, AV1 in MPEG-TS, HDR metadata beyond the color tags, DVB teletext.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: new "AV1 and VP9 play where the device decodes them" and "Vorbis sound plays"; "Streams start with sound the device can play" uses Windows Media Audio instead of Vorbis as its undecodable example.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV. AV1 decodes on A17 Pro, M3 and later; VP9 on Macs that offer the supplemental decoder. The tests run on an M1 Mac, so they cover VP9 decoding and the AV1 fallback, not AV1 decoding.
- Code: `SampleBuilder` and `Demuxer` in AntennaDemux, `DemuxRun.prepare`, `AVPlayerEngine+Stream` in Apps/Shared, `scripts/build-ffmpeg.sh`.
- The Vorbis decoder needs a new FFmpeg release (`ffmpeg-*` tag, built by `.github/workflows/ffmpeg.yml`) and the new url and checksum in `Packages/FFmpeg/Package.swift`. The owner or coordinator pushes that tag; until then Vorbis stays undecodable and its test is skipped.
- New fixtures from `scripts/make-stream-fixtures.sh`.
