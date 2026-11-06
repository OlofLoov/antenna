# Tasks

## 1. Contract and fixtures

- [x] 1.1 Define the engine contract, options, state, presentation, tracks, position and cue streams, keeping `load(_:)` source-compatible, and verify existing screens still build
- [x] 1.2 Add the fixture script with synthetic streams and the in-test server that can stall, cut or refuse, and verify it serves every fixture

## 2. Routing and tuning

- [ ] 2.1 Route by extension with fallback from a raw-looking address to Apple's player, and verify with core and integration tests citing `playback-engine/every-common-stream-type-plays`
- [ ] 2.2 Close the old connection before the new one, cancel reconnects and report clean state transitions, and verify with core and integration tests citing `playback-engine/starting-a-channel-replaces-the-old-one-cleanly`
- [ ] 2.3 Add the tune retry policy on a simulated clock, and verify with a core test citing `playback-engine/a-channel-that-won-t-start-is-retried-briefly`
- [ ] 2.4 Add the drop and stall reconnect policy with numbered attempts and reset, and verify with core and integration tests citing `playback-engine/a-dropped-channel-reconnects`

## 3. Errors and privacy

- [ ] 3.1 Map every cause to one reason on both paths, and verify with core, integration and device tests citing `playback-engine/streams-that-cannot-play-fail-with-a-clear-reason`
- [ ] 3.2 Extend address redaction in `guide-data`, use an ephemeral session with no cache or cookies, and verify with core and integration tests citing `playback-engine/passwords-never-leak`
- [ ] 3.3 Narrow the Apple player check in `scripts/check-rules.sh` and verify it passes

## 4. Pause, seek and lifecycle

- [ ] 4.1 Resume live at the live edge and films in place, and verify with an integration test citing `playback-engine/pause-and-play-again`
- [ ] 4.2 Add start position, seek and end for films, refusing them for live and unseekable streams, and verify with an integration test citing `playback-engine/films-start-where-you-left-off-skip-and-end`
- [ ] 4.3 Handle background, audio interruptions, route changes and Picture in Picture, and verify with integration and device tests citing `playback-engine/leaving-the-app-phone-calls-and-picture-in-picture`

## 5. Format and languages

- [ ] 5.1 Report presentation info and set display criteria on Apple TV, and verify with integration and device tests citing `playback-engine/the-screen-learns-the-picture-and-sound-format`
- [ ] 5.2 Report audio and subtitle tracks, choose by preference, apply picks and emit text cues on both routes, and verify with core and integration tests citing `playback-engine/audio-and-subtitle-languages`

## 6. FFmpeg path

- [ ] 6.1 Once the FFmpeg decision record is accepted, add the FFmpeg build and the demuxer engine with hardware decoding, silence FFmpeg's own logging, and run the contract suite against both engines, including the checks only that path has: the old picture stays while switching, the connection is let go while live TV is paused, and HLS found by the demuxer hands back to Apple's player
- [ ] 6.2 Measure 50 switches per path in Instruments on an Apple TV 4K (3rd generation), and record the result in a test citing `playback-engine/channel-switching-is-fast`

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `playback-engine/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
