# Proposal

## Why

> As a viewer watching a film from my own library or a channel from my provider, I want to hear its sound whatever format it is in, so I am not left with a picture and "(not supported)" when the file is a Blu-ray rip with DTS or TrueHD, a FLAC or Opus mkv, or a DVB channel with unusual AAC.

The first sound fix (`fix-broken-sound`, archived 2026-11-13) left these formats silent on the FFmpeg path:

- DTS, including the core of DTS-HD, and Dolby TrueHD, the sound of most Blu-ray rips in Matroska. No Apple device decodes them.
- Opus, FLAC and uncompressed PCM in Matroska, MP4, QuickTime and MPEG-TS. Apple decodes mono and stereo Opus, FLAC and PCM, but the FFmpeg path never handed them over.
- AAC whose speakers are named in a program config element (channel configuration 0). Its format had no channel count, so nothing played.
- HE-AAC v2 in raw broadcast streams played mono: the parametric stereo layer was not declared, so Apple's decoder left it out.
- AAC in LATM framing, which some DVB channels send, was not recognised as AAC.
- When the audio output changed in the last seconds of a film (headphones, a receiver switching mode), the dropped sound was not queued again, and the film ended in silence.

## What Changes

- The FFmpeg build adds the LGPL decoders for DTS, TrueHD, MLP, LATM-framed AAC, Opus and SMPTE 302M PCM, and the parsers that cut DTS, TrueHD, LATM, Opus and FLAC into frames. It is published as `ffmpeg-7.1.3-3`.
- DTS, TrueHD, MLP, LATM-framed AAC, Opus with more than two channels and SMPTE 302M are decoded in software to PCM on the speakers the stream names. The audio renderer mixes them down for the output it has.
- Mono and stereo Opus, FLAC and uncompressed PCM go to Apple's decoders, or straight to the renderer for PCM.
- AAC with a program config element gets its channel count and speakers from that element.
- HE-AAC v2 in raw broadcast streams is declared as such and plays in stereo.
- A run that has read to the end of a film still queues sound again when the renderer drops it, until the film ends.
- "(not supported)" now shows only for sound still undecodable on the FFmpeg path, such as Vorbis.

Out of scope:
- DTS:X and Atmos objects. FFmpeg decodes the DTS-HD and TrueHD beds (up to 7.1), not the objects.
- Passing DTS or TrueHD undecoded to a receiver. Apple TV sends PCM; it has no DTS or TrueHD passthrough.
- Vorbis, AC-4, MPEG-H and WMA. They stay "(not supported)".
- Apple's player path (HLS, MP4 by address). AVPlayer decodes what it supports itself.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: a new requirement, "Sound in every common format plays"; "Streams start with sound the device can play" changes its example of an undecodable default from DTS to Vorbis; "Sound keeps playing when its format changes" gains a scenario for the end of a film.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV, all through the FFmpeg path in AntennaDemux; one display-name change in AntennaCore.
- Depends on `playback-engine/sound-keeps-playing-when-its-format-changes` and `playback-engine/streams-start-with-sound-the-device-can-play` from `fix-broken-sound`.
- A new FFmpeg build: the binary package moves to the `ffmpeg-7.1.3-3` release, which the FFmpeg workflow publishes from a tag. The second pull request waits for it.
- New stream fixtures, made by `scripts/make-stream-fixtures.sh`. The HE-AAC v2 one needs ffmpeg's AudioToolbox encoder, so it is made on a Mac. `undecodable-sound.ts`, Opus in MPEG-TS, is replaced by a Vorbis fixture.
