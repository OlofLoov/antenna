# Tasks

## 1. FFmpeg build

- [x] 1.1 `scripts/build-ffmpeg.sh` enables the `dca`, `truehd`, `mlp`, `aac_latm`, `opus` and `s302m` decoders and the `aac_latm`, `dca`, `mlp`, `opus` and `flac` parsers
- [x] 1.2 `scripts/ffmpeg-smoke.swift` checks the new decoders are present
- [ ] 1.3 Publish the build as `ffmpeg-7.1.3-3`

## 2. Decoding

- [ ] 2.1 `Packages/FFmpeg/Package.swift` points at `ffmpeg-7.1.3-3`, and `FFmpegBuildTests` expects the new decoders
- [ ] 2.2 `SoftwareDecoder` finds decoders by codec name, takes extradata, reads 16-bit, 32-bit and float samples, names the speakers and joins short frames
- [ ] 2.3 `SampleBuilder` sends DTS, TrueHD, MLP, LATM, SMPTE 302M and multichannel Opus to `SoftwareDecoder`
- [ ] 2.4 `SampleBuilder` builds Opus (mono, stereo), FLAC and uncompressed PCM buffers
- [ ] 2.5 AAC with a program config element gets its speakers from it; HE-AAC v2 in ADTS is declared with parametric stereo
- [ ] 2.6 A run that read to the end of a film serves sound requests until it is cancelled
- [ ] 2.7 Display names for TrueHD, Opus, Vorbis, LATM and PCM

## 3. Fixtures and tests

- [ ] 3.1 Fixtures: DTS 5.1 m2ts, TrueHD 5.1, Opus stereo and 5.1, FLAC stereo and 5.1, PCM in Matroska and QuickTime, SMPTE 302M, AAC with a PCE in ADTS and Matroska, HE-AAC v2, LATM, Vorbis with AC-3, Vorbis only
- [ ] 3.2 Each fixture decodes with `SoundDecoding` and plays through the audio renderer

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.2 `/opsx:verify` passes
