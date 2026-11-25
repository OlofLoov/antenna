# Proposal

## Why

> As a viewer on an iPhone or Apple TV 4K, I want an HEVC movie from my provider to play, since my device decodes HEVC. When something really cannot play here, I want to be told what it is.

The owner opened a movie and got "Format not supported: This stream uses HEVC, which this device cannot play." Their devices decode HEVC in hardware, so the message was wrong. Local fixtures reproduce three ways an HEVC film ends in that message, or in a timeout, on a device that can decode it:

1. An MP4 film marked `hev1` whose parameter sets travel in the samples, with none in its configuration record. The `hev1` mark allows that. Apple's player cannot decode the track and hands it to the FFmpeg path, whose sample builder needs the parameter sets in the record, fails, and reports "can't decode hevc". A Matroska film with the same record fails the same way.
2. An MP4 film in HEVC 4:2:2 or 12-bit. Apple's player never gets ready and the film fails after 15 seconds as "Stream stopped", although VideoToolbox decodes 4:2:2 on a Mac. On a device without that decoder, the right answer is "can't play HEVC 4:2:2", not a timeout.
3. Apple's player failing with "decoder not found" (AVFoundation -11833) for a file. Today that error becomes "can't decode" at once, before the FFmpeg path gets a try.

## What Changes

- The FFmpeg path takes HEVC parameter sets from the samples when the configuration record has none, as it already does for raw broadcast streams.
- Apple's player hands a film to the FFmpeg path, with no error shown, when it fails with "decoder not found", and before it waits when the film's HEVC is anything other than 8 or 10-bit 4:2:0 or is marked `hev1`.
- The FFmpeg path asks VideoToolbox for a decoder for each H.264 or HEVC picture format before it shows it. It fails with "can't decode" only when VideoToolbox has none, and names the profile, such as "HEVC 4:2:2 10-bit".
- A broken configuration record fails as "Stream could not be read", not as "can't decode".

Out of scope: HLS. The FFmpeg build has no HLS reader and no network code, so an HLS stream Apple's player cannot decode keeps failing with the codec named (design.md). Also out: a film that fails to decode after it started playing, software decoding of anything VideoToolbox cannot decode, and H.264 `avc3` films.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `playback-engine`: new "HEVC plays wherever the device decodes it".
- `player-controls-and-playback-errors`: new "Format not supported names the profile".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV. The tests run on an Apple silicon Mac, which decodes HEVC 4:2:2 and 4:4:4 in hardware and 12-bit only in software. The "cannot decode" branch is checked with a format VideoToolbox has no decoder for.
- Code: `SampleBuilder` and `DemuxRun` in AntennaDemux, `AVPlayerEngine+Stream` in Apps/Shared, `CodecName` and a new HEVC configuration reader in AntennaCore.
- New fixtures from `scripts/make-stream-fixtures.sh`.
- Depends on nothing else. The owner has not said which device or stream showed the message; the report asks.
