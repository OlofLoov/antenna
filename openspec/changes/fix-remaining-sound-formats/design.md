# Design

## Context

`fix-broken-sound` made the FFmpeg path's AAC, MP3, AC-3, E-AC-3 and MP2 play right and left the rest of what films and channels carry silent, marked "(not supported)". Its test helper `SoundDecoding` builds a fixture's sound into buffers and decodes them with `AVAudioConverter`, which uses the same decoders as `AVSampleBufferAudioRenderer`. Every decision below was checked with it against a new fixture per format, on a Mac with macOS 26.

What the checks found before this change:

| Stream | Before | Cause |
|---|---|---|
| DTS 5.1 (Blu-ray MPEG-TS), DTS stereo (Matroska) | not supported | no decoder in the build, none on Apple devices |
| TrueHD 5.1 (Matroska) | not supported | same |
| Opus stereo (MPEG-TS), Opus 5.1 (Matroska) | not supported | `SampleBuilder` had no Opus case |
| FLAC stereo (MP4), FLAC 5.1 24-bit (Matroska) | not supported | no FLAC case |
| PCM s16, s24, s32, f32 in Matroska and QuickTime, SMPTE 302M in MPEG-TS | not supported | no PCM case, no 302M decoder |
| AAC with a program config element, ADTS and Matroska | silent | channel configuration 0 threw |
| HE-AAC v2 (ADTS) | mono | declared as HE-AAC v1, so parametric stereo was dropped |
| AAC in LATM | not supported | FFmpeg names it `aac_latm`, which had no case |

## Decisions

### Software decoding for what Apple cannot decode

DTS, TrueHD and MLP go to `SoftwareDecoder` like MP2, through FFmpeg's `dca`, `truehd` and `mlp` decoders. They are LGPL; the build stays `--disable-everything` with an explicit list, so no GPL or nonfree code comes in. The parsers `dca` and `mlp` cut frames out of MPEG-TS packets.

`SoftwareDecoder` finds its decoder by codec name through `avcodec_descriptor_get_by_name`, because FFmpeg names the DTS stream `dts` and its decoder `dca`. It now reads planar and packed 16-bit, 32-bit and float samples, which these decoders give, and takes the container's extradata.

Options considered:
- Pass DTS undecoded to a receiver (rejected): Apple TV has no DTS passthrough; `AVSampleBufferAudioRenderer` takes only Dolby formats undecoded.
- Decode only the DTS core with `core_only` (rejected): on a stream with only a core the full decoder does the same work, and DTS-HD Master Audio then plays its lossless layers.

### Multichannel PCM with the speakers FFmpeg names

The software path hands over 32-bit float PCM with a Core Audio layout made from FFmpeg's channel mask. FFmpeg's channel bits are the WAVE bits, which are also Core Audio's channel bitmap, so the layout is `kAudioChannelLayoutTag_UseChannelBitmap` with the mask and the channels stay in FFmpeg's order. A stream with no mask gets the WAVE layout for its channel count.

`AVSampleBufferAudioRenderer` takes 5.1 and 7.1 float PCM and mixes it down for headphones and stereo speakers itself, so the app never downmixes. Engine tests play each new format through the real renderer and check that it is not refused.

### Short frames joined

A TrueHD frame holds 40 samples and a DTS frame 512. One buffer each would put 1,200 TrueHD buffers a second into the audio feed, whose limit is 240 buffers, so the feed would hold a fifth of a second and the demuxer would stall on it. `SoftwareDecoder` joins frames that follow on into buffers of at least 1,024 samples (`soundSamples`, about 21 ms at 48 kHz). A change of format or a gap in time starts a new buffer. Up to 21 ms at the very end of a stream is not played.

### CPU on Apple TV

Measured on an M1 Mac in a release build, decoding 2 seconds of 5.1 sound took 13 ms for DTS, 14 ms for TrueHD and 14 ms for 5.1 Opus, about 0.7% of one core. The A12 and A15 in Apple TV 4K are slower per core, so expect 1 to 3% of one core, on the demuxing thread, which already copies MPEG-2 pictures. DTS-HD Master Audio and TrueHD at 7.1 and 24 bits decode their lossless layers and cost more; they were not measured, as ffmpeg cannot encode them.

### Apple's decoders where they work

Mono and stereo Opus go to Apple's Opus decoder, with the identification header (`OpusHead`) as the magic cookie and each packet's sample count from its table-of-contents byte, since Opus packets hold 2.5 to 120 ms. Apple's decoder takes a 5.1 Opus stream with that cookie, or with the MP4 `dOps` box, and decodes it to silence, so Opus with a channel mapping family other than 0 goes to FFmpeg's `opus` decoder.

FLAC goes to Apple's FLAC decoder with a cookie made from the STREAMINFO block (the body of an MP4 `dfLa` box) and the block size as frames per packet. Apple's decoder decoded the stereo and 24-bit 5.1 fixtures with any of the cookie forms tried. A stream whose block size varies is timed by the container, frame by frame.

Uncompressed PCM is converted to float in `SampleBuilder` and needs no decoder. SMPTE 302M carries its own header in each packet, so FFmpeg's `s302m` decoder reads it.

Options considered:
- FFmpeg's `flac` decoder (rejected): Apple's decodes it, and every software decoder is CPU on the demuxing thread.
- All Opus in software (rejected): Apple's decoder handles mono and stereo, which is most Opus.

### AAC speakers from the program config element

With channel configuration 0 the speakers are in a program config element (PCE). In Matroska and MP4 it follows the AudioSpecificConfig header; in ADTS it opens the first frame. `SampleBuilder.programConfig` reads it, and in ADTS appends it to the two-byte config, so Apple's decoder gets the full AudioSpecificConfig. The element's comment is byte-aligned from the start of the frame, so the copy is re-aligned. The format's layout names each speaker (`kAudioChannelLayoutTag_UseChannelDescriptions`): front, side and back elements in order, then LFE.

Only configs without explicit SBR are read this way; HE-AAC with a PCE is rare and stays unsupported.

### HE-AAC v2 declared

ADTS signals HE-AAC v2 as mono AAC LC at half the rate. Mono AAC LC at 24 kHz or less in ADTS is now declared as HE-AAC v2: format `kAudioFormatMPEG4AAC_HE_V2`, two channels, and an AudioSpecificConfig with object type 29. A stream that is HE-AAC v1 mono plays the same sound on both channels. Explicit object type 29 from Matroska or MP4 also gets two channels.

Options considered:
- Parse the AAC frame for a parametric stereo extension (rejected): needs much of an AAC decoder's bitstream parsing.

### LATM in software

LATM framing carries its config in band, in a StreamMuxConfig whose AudioSpecificConfig is not byte-aligned and whose payload follows it at any bit. FFmpeg's `aac_latm` decoder reads it, with its parser cutting frames. It pulls in FFmpeg's AAC decoder, so `FFmpegBuildTests` now finds an AAC decoder; the app still sends plain AAC to Apple's decoder.

Options considered:
- Parse the StreamMuxConfig in the app and repackage frames for Apple's decoder (rejected): a bit-level parser of the config and the payload lengths, with HE-AAC and PCE inside, for a format a few DVB channels use. AAC decodes at about 1.4 ms per second of stereo on an M1 in software.

### Sound queued again after the last packet

A run that read to the end of a film reported the end and its thread stopped, so a renderer flush in the last seconds had nobody to refill it. The run now reports the end and then waits on a semaphore for sound requests, serving each from its ring, until the engine cancels it. A run that ended on a failure stops as before. The engine cancels the run when the film is stopped, skipped or replaced, so the thread does not outlive it.

### Display names and "(not supported)"

`CodecName.display` reads `truehd` as "Dolby TrueHD", `opus` as "Opus", `vorbis` as "Vorbis", `aac_latm` as "AAC", and `s302m` and every `pcm_*` as "PCM". "(not supported)" still follows the format of sound the engine reports as not decodable; with the new cases, that is now Vorbis, AC-4, MPEG-H, WMA and other formats with no builder. No layout changes; the boards `TV-Player-Tracks`, `iPhone-Player-Tracks` and `iPad-Player-Tracks` already show a format in the audio detail slot.

### FFmpeg build and its release

`scripts/build-ffmpeg.sh` enables the decoders `dca`, `truehd`, `mlp`, `aac_latm`, `opus` and `s302m` and the parsers `aac_latm`, `dca`, `mlp`, `opus` and `flac`. The macOS framework grows from 2.1 MB to 2.6 MB. The first pull request changes the script and `scripts/ffmpeg-smoke.swift`; the tag `ffmpeg-7.1.3-3` on its merge commit publishes the build through `.github/workflows/ffmpeg.yml`. The second pull request points `Packages/FFmpeg/Package.swift` at that release and adds the decoding.

### Fixtures

`dts-5.1.m2ts` is Blu-ray MPEG-TS: ffmpeg's muxer writes DTS as stream type 0x82, which FFmpeg's demuxer maps to DTS only with the `HDMV` registration that m2ts mode writes. `undecodable-sound.ts` (Opus, now decodable) is replaced by `undecodable-sound.mkv` (Vorbis), and the track-choice test uses `vorbis-and-ac3.mkv`. `dts-and-ac3.mkv` now checks that a DTS default plays.

## Platforms

All of it runs on iPhone, iPad, Mac and Apple TV; the FFmpeg path is shared. The renderer's downmix covers headphones and stereo speakers on every device and a stereo TV on Apple TV.

## Not verified here

No Apple TV, receiver or real provider stream was at hand. The decoding checks ran on a Mac with the same decoders. DTS-HD Master Audio, TrueHD with Atmos and 7.1 DTS were not tested, as ffmpeg cannot encode them; FFmpeg decodes their beds.
