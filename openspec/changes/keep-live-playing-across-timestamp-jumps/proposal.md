# Proposal

## Why

> As a viewer watching a live channel, I want it to keep playing through ad breaks, feed switches and a whole day left on, so I am not staring at a frozen picture or losing the sound until I zap away and back.

Real IPTV live streams change their timestamps while they play. On the FFmpeg path nothing handled it:

- A jump forward (an ad break spliced in, the provider switching feeds, an encoder restart) gave every packet a time far ahead of the clock. The renderers held the pictures and the sound until the clock got there, so the picture froze for as long as the jump.
- A jump back gave every packet a time the clock had passed. By the engine's own check, a clock past the newest queued picture is a starved stream, so the channel went to buffering and, after the stall budget, counted as dropped and reconnected.
- A sound stream that the program table lists after the start, or that replaces the one that played, was never read, because the demuxer skipped packets of streams it did not know at the start. A channel whose sound came late played silent, and a channel whose sound moved went silent.
- A track marked as audio description could be the one a channel started with, because it came first.

The 33-bit MPEG-TS clock wraps every 26.5 hours. FFmpeg already unwraps one wrap per connection, which a new test now pins; a wrap that reaches the run as a jump of one whole wrap is unwrapped exactly.

## What Changes

- Live streams on the FFmpeg path keep their times running on across a jump. Each picture and sound stream is watched; a jump of more than a second moves the stream's times so they carry on, and the other streams take the same move so picture and sound stay in step. After a jump in the picture, pictures wait for the next keyframe.
- Streams FFmpeg finds after the start are taken in: sound gets a builder and the engine reports the new tracks. A run with no sound starts the new sound; a run whose sound stops for 1.5 seconds while another sends moves to that one.
- The ring of kept sound keeps the MPEG-TS frames that come with no time of their own, so a sound switch on a broadcast queues whole sound again instead of one frame in 17.
- Sound marked as audio description is passed over when the starting sound is chosen, on both playback paths.

Out of scope:
- Films. A film's times count from the container, and skipping depends on that, so only streams with no length are re-timed.
- Labeling an audio description track in the audio list. It shows by its language, as before.
- Following the system's "Prefer Audio Descriptions" accessibility setting.
- A video stream that appears after the start (a radio channel that gains a picture).

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: three new requirements, "Live keeps playing across a timestamp jump", "Sound that starts late is played" and "Audio description is not the default sound".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV. The re-timing and late sound are in AntennaDemux; the audio description flag is in AntennaCore's `MediaTrack` and is read on Apple's player path in `AVPlayerEngine` too.
- Builds on `playback-engine/undecodable-pictures-are-not-shown` (pictures wait for a keyframe) and `playback-engine/audio-and-subtitle-languages` (the starting choice).
- New stream fixtures from `scripts/make-stream-fixtures.sh`, joined with the new `scripts/splice-ts.py`.
