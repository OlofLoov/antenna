# Design

## Context

`SampleBuilder` turns FFmpeg packets into `CMSampleBuffer`s for VideoToolbox inside `AVSampleBufferVideoRenderer`. It knows H.264, HEVC, MPEG-4 Part 2 and, through `SoftwareDecoder`, MPEG-2. Any other video codec throws `unsupportedCodec`, and `DemuxRun.prepare` fails the stream with `cannotDecode(codec)`.

On the M1 Mac these tests run on, `VTIsHardwareDecodeSupported` says false for AV1, and true for VP9 once `VTRegisterSupplementalVideoDecoderIfAvailable(kCMVideoCodecType_VP9)` has run. So this machine checks VP9 decoding and the AV1 path for a device without the decoder. AV1 decoding is checked on an A17 Pro or M3 device, which this change does not have.

No screen changes, so no board applies.

## Decisions

### Hardware only, as the owner decided

Options considered: dav1d or libvpx in the FFmpeg build (rejected by the owner on 2026-11-21: it breaks the "no software video decoder" rule beyond the MPEG-2 exception, costs battery, and dav1d's licence would need checking), and leaving both codecs out (rejected: AV1 films are common on providers that re-encode).

`SampleBuilder.hardwareDecodes(_:)` answers for AV1 and VP9, registering the VP9 supplemental decoder once. A builder for either codec throws `unsupportedCodec` without it, as today.

### AV1 format

FFmpeg gives the av1C box contents as extradata for Matroska (CodecPrivate) and MP4. The format description is `kCMVideoCodecType_AV1` with that box under `SampleDescriptionExtensionAtoms` as `av1C`, the container's size, and the stream's color tags. Packets are already in the low-overhead OBU form VideoToolbox takes in MP4, so they go into the sample buffer as they are. AV1 in MPEG-TS (rare, and framed differently) is not handled.

### VP9 format

Matroska and WebM carry no vpcC, and FFmpeg's MP4 reader turns vpcC into codec parameters rather than extradata. The builder writes a version 1 vpcC from those parameters: profile, level, bit depth and chroma subsampling from the pixel format, full range, primaries, transfer and matrix. `DemuxedStream` gains a `VideoParameters` value with FFmpeg's numbers for these.

### When there is no decoder

`DemuxRun.prepare` fails AV1 or VP9 without the hardware as `cannotDecode`, except in MP4 or QuickTime, where it throws `EngineHandoff.toSystemPlayer`. Apple's player then sees the track is not decodable; for an AV1 or VP9 track (subtype `av01` or `vp09`) it fails with `cannotDecode("av1")` or `cannotDecode("vp9")` instead of handing back to the FFmpeg path, so the two engines never pass a stream back and forth.

### Vorbis

FFmpeg's `vorbis` decoder is LGPL and small. `scripts/build-ffmpeg.sh` adds it with `--enable-decoder=vorbis` and keeps `vorbis_parser.h` installed. `SampleBuilder` sends `vorbis` to `SoftwareDecoder` with the container's extradata (the three setup headers). Until a new `ffmpeg-*` release is published and `Packages/FFmpeg/Package.swift` points at it, `SoftwareDecoder` reports the decoder unavailable and Vorbis stays "(not supported)", as before. The tests that used Vorbis as the undecodable example move to Windows Media Audio (`wmav2`), which the build will never decode.

## Not verified here

AV1 decoding on a device that has the decoder. Apple TV 4K (3rd generation) has no AV1 decoder; whether its VP9 decoder is offered through VideoToolbox to apps was not checked.
