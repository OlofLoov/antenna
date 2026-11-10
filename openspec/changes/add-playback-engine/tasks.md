# Tasks

## 1. Contract and fixtures

- [x] 1.1 Define the engine contract, options, state, presentation, tracks, position and cue streams, keeping `load(_:)` source-compatible, and verify existing screens still build
- [x] 1.2 Add the fixture script with synthetic streams and the in-test server that can stall, cut or refuse, and verify it serves every fixture

## 2. Routing and tuning

- [x] 2.1 Route by extension with fallback from a raw-looking address to Apple's player, and verify with core and integration tests citing `playback-engine/every-common-stream-type-plays`
- [x] 2.2 Close the old connection before the new one, cancel reconnects and report clean state transitions, and verify with core and integration tests citing `playback-engine/starting-a-channel-replaces-the-old-one-cleanly`
- [x] 2.3 Add the tune retry policy on a simulated clock, and verify with a core test citing `playback-engine/a-channel-that-won-t-start-is-retried-briefly`
- [x] 2.4 Add the drop and stall reconnect policy with numbered attempts and reset, and verify with core and integration tests citing `playback-engine/a-dropped-channel-reconnects`

## 3. Errors and privacy

- [x] 3.1 Map every cause to one reason on both paths, and verify with core, integration and device tests citing `playback-engine/streams-that-cannot-play-fail-with-a-clear-reason`
- [x] 3.2 Extend address redaction in `guide-data`, use an ephemeral session with no cache or cookies, and verify with core and integration tests citing `playback-engine/passwords-never-leak`
- [x] 3.3 Narrow the Apple player check in `scripts/check-rules.sh` and verify it passes

## 4. Pause, seek and lifecycle

- [x] 4.1 Resume live at the live edge and films in place, and verify with an integration test citing `playback-engine/pause-and-play-again`
- [x] 4.2 Add start position, seek and end for films, refusing them for live and unseekable streams, and verify with an integration test citing `playback-engine/films-start-where-you-left-off-skip-and-end`
- [x] 4.3 Handle background, audio interruptions, route changes and Picture in Picture, and verify with integration and device tests citing `playback-engine/leaving-the-app-phone-calls-and-picture-in-picture`

## 5. Format and languages

- [ ] 5.1 Report presentation info and set display criteria on Apple TV, and verify with integration and device tests citing `playback-engine/the-screen-learns-the-picture-and-sound-format`
- [ ] 5.2 Report audio and subtitle tracks, choose by preference, apply picks and emit text cues on both routes, and verify with core and integration tests citing `playback-engine/audio-and-subtitle-languages`
- [ ] 5.3 Keep the last language pick per channel under `player.languages` and start a returning channel with it, and verify with a core test citing `playback-engine/audio-and-subtitle-languages`
- [ ] 5.4 Keep the last frame over Apple's player while the next item loads, and verify with an integration test citing `playback-engine/starting-a-channel-replaces-the-old-one-cleanly`

## 6. FFmpeg build

- [x] 6.1 Add `scripts/build-ffmpeg.sh` for the LGPL demux build in design.md, a CI workflow that builds `FFmpeg.xcframework` on a tag and publishes it with its source, and the binary package `Packages/FFmpeg`, and verify a test opens the fixture `channel.ts` and lists its streams on iOS and tvOS simulators
- [ ] 6.2 Add the FFmpeg notice under Settings, About, and verify with a UI test

## 7. Demux engine

- [x] 7.1 Add `DemuxEngine` with the AVIO callback on the ephemeral session, demux to `CMSampleBuffer`s for H.264 and AAC into the sample-buffer renderers and synchronizer, silence FFmpeg's logging, and run the contract suite against both engines, verify with integration tests citing `playback-engine/every-common-stream-type-plays`
- [ ] 7.2 Hand HLS found by the demuxer back to Apple's player, keep the old picture while switching, and let the connection go while live TV is paused, and verify with integration tests citing `playback-engine/starting-a-channel-replaces-the-old-one-cleanly` and `playback-engine/pause-and-play-again`
- [ ] 7.3 Start at the first keyframe, open the channels above and below ahead when the account allows more than one connection, and verify with core tests citing `playback-engine/channel-switching-is-fast` and `playback-engine/starting-a-channel-replaces-the-old-one-cleanly`
- [ ] 7.4 Map demuxer failures to the shared reasons and route Matroska and AVI through it, and verify with integration tests citing `playback-engine/streams-that-cannot-play-fail-with-a-clear-reason`

## 8. Picture and sound

- [ ] 8.1 HEVC and HDR10/HLG through the renderer, display criteria kept across channels of the same mode, and verify with integration and device tests citing `playback-engine/the-screen-learns-the-picture-and-sound-format`
- [ ] 8.2 Add AC-3 and E-AC-3 fixtures to `scripts/make-stream-fixtures.sh`, pass AC-3 and E-AC-3 with Atmos passed through on tvOS and decoded elsewhere, on both routes, and verify with integration and device tests citing `playback-engine/surround-sound-reaches-the-speakers`
- [ ] 8.3 Picture in Picture from the sample-buffer renderer, and verify with a device test citing `playback-engine/leaving-the-app-phone-calls-and-picture-in-picture`

## 9. Old SD channels and interlaced video

- [ ] 9.1 Decode MPEG-2 video and MP2 sound in software, and verify with integration tests citing `playback-engine/every-common-stream-type-plays`
- [ ] 9.2 Add 1080i50 and 576i fixtures with moving edges to `scripts/make-stream-fixtures.sh`, detect interlaced streams, decode them through VideoToolbox, deinterlace in Metal at the field rate, and verify with integration tests on interlaced fixtures citing `playback-engine/interlaced-broadcasts-are-deinterlaced`
- [ ] 9.3 Confirm 1080i50 holds 50 frames a second on an Apple TV 4K, and record it in a device test citing `playback-engine/interlaced-broadcasts-are-deinterlaced`

## 10. Measure

- [ ] 10.1 Measure 50 switches per path in Instruments on an Apple TV 4K (3rd generation), and record the result in a test citing `playback-engine/channel-switching-is-fast`

## 11. Verify

- [ ] 11.1 Each requirement has a test citing `playback-engine/<requirement-slug>`
- [ ] 11.2 `/opsx:verify` passes
