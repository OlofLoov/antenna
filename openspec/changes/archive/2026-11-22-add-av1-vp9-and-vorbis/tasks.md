# Tasks

## 1. AV1 and VP9 in hardware

- [x] 1.1 `DemuxedStream.VideoParameters` from FFmpeg's codec parameters
- [x] 1.2 `SampleBuilder` builds AV1 from av1C and VP9 with a written vpcC, gated on `hardwareDecodes`
- [x] 1.3 `DemuxRun.prepare` hands AV1 or VP9 in MP4 or QuickTime without the decoder to Apple's player, and fails the rest as "can't decode"
- [x] 1.4 `AVPlayerEngine` fails an undecodable AV1 or VP9 track as "can't decode" instead of handing it back
- [x] 1.5 Fixtures and tests: VP9 in WebM and MP4 plays on a Mac with the decoder; AV1 in Matroska fails as "can't decode av1" and AV1 in MP4 goes to Apple's player on a device without it

## 2. Vorbis

- [x] 2.1 `scripts/build-ffmpeg.sh` builds the `vorbis` decoder
- [x] 2.2 `SampleBuilder` sends Vorbis to `SoftwareDecoder`
- [x] 2.3 The undecodable-sound fixtures and tests use Windows Media Audio
- [x] 2.4 A test that Vorbis plays, run once the decoder is in the build
- [x] 2.5 Publish the FFmpeg release and point `Packages/FFmpeg/Package.swift` at it (owner or coordinator: needs an `ffmpeg-*` tag)

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
