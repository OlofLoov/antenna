# Tasks

## 1. The FFmpeg path

- [x] 1.1 `HEVCConfiguration` and `H264Profile` in AntennaCore, and `CodecName.display` keeping the profile after the codec
- [x] 1.2 `SampleBuilder` reads HEVC parameter sets from the samples when the record has none
- [x] 1.3 `DemuxRun` asks VideoToolbox for a decoder for each new H.264 or HEVC format and fails with the profile named when there is none
- [x] 1.4 `DemuxRun.undecodable` reports a malformed record as unreadable
- [x] 1.5 Fixtures `hev1-in-band.mp4` and `hevc-422.mp4`, and tests for each

## 2. Apple's player

- [x] 2.1 A file that fails with "decoder not found" goes to the FFmpeg path, except AV1 and VP9 without the hardware
- [x] 2.2 HEVC marked `hev1`, or beyond 8 or 10-bit 4:2:0, goes to the FFmpeg path once its tracks load
- [x] 2.3 Tests in `AVPlayerEngineTests` for both

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
