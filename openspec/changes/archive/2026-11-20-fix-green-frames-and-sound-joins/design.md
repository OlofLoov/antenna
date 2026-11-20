# Design

## Context

The owner reported green flicker and sound problems on HEVC 2160p films with Dolby TrueHD 7.1, on real devices. Those films are Matroska (UHD Blu-ray style remuxes) on the FFmpeg path: FFmpeg demuxes, `SampleBuilder` packages HEVC for VideoToolbox, and `SoftwareDecoder` decodes TrueHD to float PCM for `AVSampleBufferAudioRenderer`.

No owner stream was available. Each suspect was checked with a generated stream and a test that runs it through `DemuxRun` into recording renderers. `PictureCheck` decodes the queued video with a VideoToolbox session, as the video renderer does, and compares each picture with the same picture from a clean decode. The sound checks read the times and lengths of the queued sound buffers.

| Suspect | Finding | Cause |
|---|---|---|
| TrueHD and DTS timing in Matroska | every buffer join off by 1/3 to 2/3 ms (16 to 32 samples) | each buffer took the first frame's container time, which Matroska rounds to the millisecond |
| AC-3 timing in Matroska | no bug | 1536-sample frames last exactly 32 ms |
| 5.1 TrueHD and DTS speakers | surround pair named "surround direct" | FFmpeg names the side pair, which Core Audio's channel bitmap reads as Lsd and Rsd |
| 7.1 and 6.1 speakers | side and back swapped | the same bitmap reading; with no mask, the MPEG 7.1 and 6.1 layouts list the side pair first, WAVE order the back pair |
| CPU of TrueHD | keeping 30 s of packets cost 4.6 s of CPU in a release build on an M-series Mac, 15% of a core | the 10 s ring copied all 12,000 packets for every new one |
| TrueHD started between major syncs | no bug | FFmpeg's decoder gives nothing until a major sync, and that frame starts at its own time |
| Start or skip at an HEVC CRA | leading pictures fail with a missing reference (-17694) | RASL pictures reference pictures before the keyframe, which were never read |
| Start at an H.264 open-GOP keyframe | leading B-frames queued before the keyframe in time, decoded without damage | the run queued every picture after the first keyframe |
| Dolby Vision layers in hvcC samples | no bug while the record lists the base layer first; no picture at all when it lists the enhancement layer's sets first | VideoToolbox ignores units of layer 1 and types 62 and 63 in a sample, but the format took the first VPS, SPS and PPS of each kind |
| Lost TS packets in the middle of a GOP | the damaged picture and the 12 after it, to the next keyframe, decoded smeared | FFmpeg marks the packet corrupt; the run passed it on |
| Video renderer failed or needs a flush | nothing recovered it; the picture would stay frozen | only the audio renderer's status was checked |
| Dolby Vision layers in Annex B (MPEG-TS) | no picture at all | the format was built from the last VPS, SPS and PPS in the keyframe, which were the enhancement layer's |

## Decisions

### Sound that follows on stays joined

`SampleBuilder.soundStart` times a sound packet or decoded frame at the end of the sound before it when its own time is within `soundJitter` (10 ms) of that end, and at its own time otherwise. `SampleBuilder` uses it for compressed sound and uncompressed PCM, `SoftwareDecoder` for what it decodes. A resend from the ring, a track switch or a real jump in the stream is more than 10 ms away and starts at its own time.

Options considered:
- Round the container time to the sample (rejected): the rounding error is up to half a millisecond, 24 samples, not a fraction of one.
- Retime every buffer from the first one (rejected): a real gap or jump in a channel would push the sound out of step for the rest of the stream.
- Snap within a tolerance (chosen): 10 ms is above Matroska's rounding and the jitter of broadcast muxers and below what anyone hears as out of sync (about 45 ms). Sound that drifts from its times by more than that jumps back once.

### Speakers named as Apple names them

`SoftwareDecoder.pcmFormat` uses Apple's layout tags for the masks the bitmap names wrong: 5.0 and 5.1 with side speakers (`MPEG_5_0_A`, `MPEG_5_1_A`), 6.1 (`WAVE_6_1`) and 7.1 (`WAVE_7_1`). Other masks keep the bitmap. With no mask, 7 and 8 channels in WAVE order take `WAVE_6_1` and `WAVE_7_1`; FLAC uses the same table.

### A ring that does not copy

`SoundRing` holds a stream's packets in an array with a head index and is changed in place in the run's dictionary. Dropping the oldest moves the head; the spent front is cleared once it is half the array. A copy out of the dictionary is what made each append copy the whole ring.

### Base layer only for HEVC

`SampleBuilder.isHEVCBaseLayer` turns down units with a layer id above 0 and units of type 62 and 63 (Dolby Vision RPU and enhancement-layer data). Annex B packets drop them before the parameter sets are picked and before the sample is built. Length-prefixed samples (Matroska, MP4) drop them too, and come back as they are when nothing is dropped, so ordinary films pay one scan of their unit headers. `hevcParameterSets` takes the first base-layer VPS, SPS and PPS of the hvcC record.

Options considered:
- Declare Dolby Vision to the renderer (`dvh1` with the `dvcC` record) (rejected for now): it is the only way to show profile 5 with the right colors, but it needs an Apple TV and a Dolby Vision TV to check, and profile 7 and 8 films already have an HDR10 base.
- Leave the samples alone and fix only the parameter sets (rejected): VideoToolbox ignored the extra units in the tests, but a decoder that reads an SPS of layer 1 with id 0 would replace the base layer's.

### Leading pictures dropped after a start

`DemuxRun` remembers the time of the keyframe a run started at, after a start, a resume or a skip, until the next keyframe. A picture before that time is dropped before it reaches `SampleBuilder`. Those are the RASL pictures of an HEVC CRA and the leading B-frames of an open-GOP H.264 keyframe; both may refer to pictures before the keyframe. RADL pictures, which decode, go too; they come before the first picture shown, so nothing on screen is lost.

Options considered:
- Read the NAL unit types and drop only RASL (rejected): HEVC only, and H.264 open GOPs, MPEG-2 and HEVC in other containers lead their keyframes the same way.
- Mark leading pictures "do not display" and still decode them (rejected): a RASL picture fails with a missing reference whatever it is marked.

### Damaged pictures wait for a keyframe

`DemuxedPacket.isCorrupt` carries FFmpeg's corrupt flag, which its MPEG-TS demuxer sets when a continuity counter shows lost packets. `DemuxRun` drops a corrupt picture and every picture after it until the next keyframe, and the leading pictures of that keyframe as after a start. The last whole picture stays on screen meanwhile. Each time, the engine logs the address (redacted) and the reason.

Options considered:
- Pass corrupt pictures on (rejected): what made the green and smeared blocks.
- Drop only the corrupt picture (rejected): every picture up to the next keyframe may refer to it.
- Drop only when the corrupt H.264 picture is a reference (rejected for now): a lost start of a packet can merge two pictures into one, so the flag says little about which picture lost data.

A stream that loses packets in every GOP will freeze for most of each GOP instead of playing with broken blocks. That is the trade asked for; the log line shows how often it happens.

### A failed video renderer restarts at a keyframe

On each tick `DemuxEngine.checkPicture` looks at the video renderer. When its status is `.failed` or it needs a flush to resume decoding, the engine asks the run to start pictures again at the next keyframe and flushes the renderer, keeping the last picture. It was not possible to make a renderer fail in a test; the run's half is tested, the engine's is read.

## Platforms

All of it runs on iPhone, iPad, Mac and Apple TV; the FFmpeg path is shared.

## Not verified here

No real film from the owner, no Apple TV and no receiver. ffmpeg cannot encode 7.1 TrueHD (its encoder stops at 5.1) or Dolby Vision, so 7.1 is checked through the layout the format carries and Dolby Vision through an enhancement layer made from a second HEVC stream with its layer id set to 1. How `AVSampleBufferAudioRenderer` sounds a join that is off by 30 samples was not measured; the joins are now exact, so it no longer matters.
