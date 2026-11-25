# Design

## Context

Three places report `PlaybackFailure.cannotDecode`:

1. `PlaybackFailure.fromPlayerError` maps AVFoundation -11833 (decoder not found) with its media subtype. `AVPlayerEngine.open` throws it as soon as the item fails, before its own handoff to the FFmpeg path.
2. `AVPlayerEngine.open` for an AV1 or VP9 track the device has no hardware decoder for.
3. `DemuxRun.prepare`, through `DemuxRun.undecodable`, whenever `SampleBuilder.init` throws for the video stream. That includes `BuildError.malformed`, not only `unsupportedCodec`.

Probes on an Apple silicon Mac with local fixtures (no provider) gave:

| Fixture | Apple's player | FFmpeg path today |
|---|---|---|
| MP4, `hvc1`, 8-bit 4:2:0 | plays | plays |
| MP4, `hev1`, parameter sets in the record | ready, track not decodable, handed over | plays |
| MP4, `hev1`, 10-bit | ready after several seconds, not decodable, handed over | plays |
| MP4, `hev1`, empty record, sets in the samples | ready, not decodable, handed over | fails "can't decode hevc" |
| MP4, `hvc1`, 10-bit 4:2:2, 4:4:4 or 12-bit 4:2:0 | never ready, fails after 15 s as "Stream stopped" | plays (VideoToolbox: 4:2:2 and 4:4:4 in hardware, 12-bit in software) |
| HLS, HEVC in MPEG-TS segments | ready, plays sound, no picture, no error | not reachable |
| HLS, HEVC in fMP4, `hev1` or `hvc1`, 8 or 10-bit | plays | not reachable |

The empty-record `hev1` film is the one fixture that ends in the owner's exact message. The Matroska reader hands the sample builder its record the same way, so Matroska with an empty record takes the same path. -11833 itself did not show on the Mac; it may on iPhone or Apple TV, whose decoders differ.

No screen changes, so no board applies. The error screen keeps its layout and text; only the codec name in it gets longer.

## Decisions

### HEVC parameter sets from the samples

Options: keep requiring them in the record (rejected: `hev1` exists so encoders can leave them out), or read them from the samples. `SampleBuilder` gets a third HEVC mode, `hevcInBand`, chosen when the record parses but lists no VPS, SPS and PPS. It splits each length-prefixed sample into units, makes the format from the first complete set, remakes it when the set changes, and leaves parameter-set and delimiter units out of the sample, as the Annex B mode does. The Annex B and in-band modes share one function over a list of units.

A record that does not parse at all (cut short) also falls back to the in-band mode. If the samples carry no sets either, no picture is ever built and the run fails as "Stream could not be read" through the existing no-picture rule.

### What "cannot decode" means

The device can decode a picture format when `VTDecompressionSessionCreate` succeeds for it with no decoder specification. That is the question the video renderer faces: it decodes through the same VideoToolbox, so a format with no session has no picture. On a Mac it may be Apple's software decoder (12-bit HEVC on M1), which plays and costs nothing to keep. Options considered: `VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)` (rejected: it answers for the codec, not the profile), and requiring a hardware decoder on the Mac too (rejected: it would turn a film that plays today into an error).

`DemuxRun.takeVideo` asks once per new H.264 or HEVC format description, the moment the builder makes it: for MP4 and Matroska at the first keyframe, for MPEG-TS when the first parameter sets arrive. A format with no decoder stops the run with `cannotDecode(codec:)`. Before the stream was announced the load fails with it; after, the engine fails the stream with it as it does for a dropped connection. The other video codecs are unchanged: MPEG-2 and MPEG-4 Part 2 have their own paths, and AV1 and VP9 are gated by `hardwareDecodes`.

`DemuxRun.undecodable` reports `cannotDecode` only for `BuildError.unsupportedCodec`; `malformed` becomes `unreadable`.

### Naming the profile

`HEVCConfiguration` in AntennaCore reads the general profile, chroma format and bit depth from an hvcC record. Its `codecName` is "hevc", followed by the chroma format when it is not 4:2:0 and the bit depth when it is above 8: "hevc 4:2:2 10-bit", "hevc 12-bit", "hevc 10-bit". H.264 gets the same from its avcC profile: High 10 is "h264 10-bit", High 4:2:2 "h264 4:2:2", High 4:4:4 "h264 4:4:4". The FFmpeg path reads the record from the format description's `SampleDescriptionExtensionAtoms`, which CoreMedia fills for formats made from parameter sets too. `CodecName.display` shows the first word as it does today and keeps the rest: "HEVC 4:2:2 10-bit". The message text in the String Catalog does not change, so no translation changes.

### Apple's player hands more files over

Options: keep failing at once (rejected, it is the bug), retry every failed file on the FFmpeg path (rejected: a 404 or a refused login would try twice), or hand over only for decode failures and formats Apple's player is known to stall on. Chosen: the last.

- When the item fails with `cannotDecode` for a file (not HLS), `open` throws `EngineHandoff.toDemuxer`. AV1 and VP9 without the hardware keep failing here, since the FFmpeg path would hand them straight back and `RoutedEngine` does not catch a second handoff.
- While it waits for the item, once the asset's tracks have loaded, `open` reads the video track's format. HEVC marked `hev1`, with no parameter sets in its record, or whose record says other than 4:2:0 at 8 or 10 bits, goes to the FFmpeg path without waiting. This covers the 4:2:2 and 12-bit films that never get ready and the 10-bit `hev1` film that takes several seconds to.

The existing check after ready (`canDecode`) stays for MP2, DTS and the rest.

### HLS stays with Apple's player

The FFmpeg build has `--disable-network` and no `hls` demuxer, and `HTTPByteStream` reads one address. Playing HLS there would mean fetching playlists and segments ourselves, a second HLS client, which is out of scope. An HLS stream that fails with -11833 keeps failing with the codec named; on HLS that is true, since no path here can play it. HEVC in MPEG-TS HLS segments, which plays sound with no picture on the Mac, is left as it is; Apple's HLS authoring rules require fMP4 for HEVC.

## Identifiers

- `SampleBuilder.Codec.hevcInBand`, `SampleBuilder.nalUnits(lengthPrefixed:)`, `SampleBuilder.decoderMissing(for:) -> String?` (the codec name when VideoToolbox has no decoder).
- `PumpState.checkedFormat`, `PumpState.undecodable`.
- `HEVCConfiguration(hvcC:)`, `HEVCConfiguration.codecName`, `HEVCConfiguration.appleReadsInFiles`, `H264Profile.codecName(avcC:)` in AntennaCore.
- `AVPlayerEngine.handsOver(_:)` and `AVPlayerEngine.systemSkips(_:)`.

## Fixtures

`scripts/make-stream-fixtures.sh` gains `hev1-in-band.mp4` (x265 with `repeat-headers=1`, the hvcC array count set to 0) and `hevc-422.mp4` (10-bit 4:2:2, `hvc1`). Each is a 2 second 320 by 180 test pattern, about 50 KB.

## Not verified here

-11833 from Apple's player on an iPhone or Apple TV, and VideoToolbox refusing HEVC 4:2:2 on Apple TV. The tests cover the mapping and the refusal path with a format no decoder takes.
