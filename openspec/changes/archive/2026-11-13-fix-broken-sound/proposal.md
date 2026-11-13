# Proposal

## Why

> As a viewer on Apple TV or iPhone, when a channel, movie or episode plays, I want its sound to play right the whole way through, and when the device cannot play a sound track, I want the picture with a clear note instead of silence I can't explain.

The owner reported broken sound on some material. Decoding the FFmpeg path's sound with Apple's decoder against new test streams found these faults:

- AAC that changes from stereo to 5.1 partway (a channel going into a film) goes silent: every buffer after the change is refused, because the format from the first frame is kept for the rest of the stream.
- AC-3 and E-AC-3 that change channel count keep describing the first format, so 5.1 after stereo plays as stereo and a receiver is told the wrong layout.
- MP2 that changes from stereo to mono (old SD channels between programmes) is played as stereo with half the samples it needs: noise at the wrong speed.
- HE-AAC in raw broadcast streams plays as plain AAC at half the rate, with the treble above 12 kHz missing.
- 7.1 AAC is described with the wrong channel count (7, or 12 for the newer layout code), so it does not play.
- A film whose default sound is DTS starts silent even when it has a Dolby Digital track.
- When the audio output changes (a receiver switching to Dolby, headphones connecting) the audio renderer drops what it holds, and the sound has a gap of several seconds. A renderer that fails stays silent for the rest of the stream.

## What Changes

- A change of channels or rate partway through a stream gets a new format, for AAC, AC-3, E-AC-3, MP3 and MP2, and the screen learns the new channel count.
- HE-AAC in raw broadcast streams decodes with its upper band.
- AAC formats carry their speaker layout, and 7.1 has eight channels. Dolby formats carry the layout their header gives.
- A stream starts on sound the device can decode when it has any, by the same language rules.
- Sound the device cannot decode reads "(not supported)" after its format in the stream line and the audio list, and the picture plays on.
- After the audio renderer drops its queue, the sound from that moment is queued again from what the run keeps. A failed renderer is flushed and fed again; after three failures on one stream the stream plays without sound and says so.

Out of scope:
- Decoding DTS, TrueHD, Opus, FLAC, PCM or LATM-framed AAC on the FFmpeg path. These need FFmpeg decoders or new Apple decoder wiring and a new FFmpeg build; a stream with only such sound still plays its picture and says the sound is not supported.
- Marking every undecodable track in the audio list. Engines report the format of the playing track only.
- AAC with channel configuration 0 (layout in a program config element), which stays silent.
- Apple's player path (HLS, MP4): AVPlayer decodes AC-3 and E-AC-3 itself and nothing in it was found wrong.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: two new requirements, "Sound keeps playing when its format changes" and "Streams start with sound the device can play".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV, all through the FFmpeg path in AntennaDemux and the track choice in AntennaCore.
- Depends on `playback-engine/surround-sound-reaches-the-speakers` and `playback-engine/audio-and-subtitle-languages`.
- No screen layout changes; the audio list's detail and the stream line get a suffix.
- New stream fixtures, made by `scripts/make-stream-fixtures.sh`. The HE-AAC one needs ffmpeg's AudioToolbox encoder, so it is made on a Mac.
