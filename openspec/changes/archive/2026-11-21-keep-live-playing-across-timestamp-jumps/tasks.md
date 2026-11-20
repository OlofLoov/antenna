# Tasks

## 1. Timestamp jumps

- [x] 1.1 `LiveTimeline` re-times the packets of a live run: one offset per stream, a jump of over a second sets a new one, streams that jump by about as much take it, a whole 33-bit wrap moves by exactly one wrap
- [x] 1.2 `DemuxRun` re-times streams with no length and waits for a keyframe after a jump in the picture
- [x] 1.3 `scripts/splice-ts.py` and fixtures: a jump forward, a jump back, a stream across the wrap
- [x] 1.4 Tests: pictures and sound carry on in step through each fixture; the timeline's offsets with made-up packets

## 2. Late sound

- [x] 2.1 `Demuxer` takes in streams FFmpeg finds after the start
- [x] 2.2 `DemuxRun` builds the new sound, reports the tracks, starts sound when it has none and moves to another sound when the one that plays stops; the engine publishes the new tracks
- [x] 2.3 `SoundRing` keeps MPEG-TS frames that come with no time; sound switches build from the last timed frame
- [x] 2.4 Fixtures and tests: sound that appears after the picture, sound that moves to another PID, the ring

## 3. Audio description

- [x] 3.1 `MediaTrack.isAudioDescription` from FFmpeg's visual impaired disposition and from the AVFoundation characteristic; `TrackChoice` passes it over
- [x] 3.2 Fixture and tests: the choice in AntennaCore, a broadcast with a described track first

## 4. Verify

- [x] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 `/opsx:verify` passes
