# Proposal

## Why

> As a viewer playing a 4K HEVC film with Dolby TrueHD 7.1 sound, I want a clean picture and clean sound, so I am not watching green flashes and hearing crackle on the films that should look and sound best.

The owner saw green flicker and sound problems on real devices, on HEVC 2160p films with TrueHD 7.1. Checking the FFmpeg path against generated streams found these causes:

- Every buffer of TrueHD and DTS sound from Matroska started at the container's time, which Matroska rounds to the millisecond. Each join, about 47 a second, overlapped or left a gap of up to 32 samples.
- 5.1 sound from TrueHD and DTS named its surround pair as "surround direct" speakers, and 7.1 and 6.1 swapped the side and back speakers.
- Every TrueHD packet copied the whole 10 second ring of kept sound, 12,000 packets, on the demuxing thread.
- After a start or a skip at an open-GOP keyframe (an HEVC CRA, usual in UHD encodes), the pictures that lead it referenced pictures that were never read. VideoToolbox fails them as missing references.
- An HEVC stream carrying a Dolby Vision enhancement layer in band, with its own parameter sets, could have the format built from the enhancement layer's parameter sets, and then nothing decoded.

## What Changes

- Sound buffers follow on from each other when their time is within 10 ms of where the sound before ends, and start at their own time after a larger jump.
- 5.1, 6.1 and 7.1 software-decoded and uncompressed sound name their speakers as Apple's own WAVE and MPEG layouts do.
- The ring of kept sound adds and drops packets at a constant cost.
- After a start, a skip or a resume, video pictures that come before the first keyframe's time are dropped until the next keyframe.
- HEVC pictures keep only the base layer: units of a higher layer and Dolby Vision metadata units are dropped, and the format is built from the base layer's parameter sets.

Out of scope:
- Showing Dolby Vision itself (profile 5, 7 or 8 metadata). The base layer plays as HDR10 or SDR, as before. A profile 5 film, which has no HDR10 base, still shows the wrong colors; it needs a Dolby Vision format on Apple TV.
- Passing TrueHD undecoded to a receiver. Apple TV has no TrueHD passthrough.
- Apple's player path (HLS, MP4 by address).

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: two new requirements, "Undecodable pictures are not shown" and "Film sound plays without clicks".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV, all through the FFmpeg path in AntennaDemux.
- Builds on `playback-engine/sound-in-every-common-format-plays` and `playback-engine/surround-sound-reaches-the-speakers`.
- New stream fixtures from `scripts/make-stream-fixtures.sh`.
