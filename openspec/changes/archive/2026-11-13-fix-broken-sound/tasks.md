# Tasks

## 1. Formats

- [x] 1.1 `SampleBuilder` builds a new format when an AAC, Dolby or MP3 frame header changes
- [x] 1.2 `SoftwareDecoder` builds a new PCM format when the channel count changes
- [x] 1.3 HE-AAC is declared with explicit SBR; AAC formats carry their layout and 7.1 has eight channels
- [x] 1.4 Dolby formats carry the layout of their audio coding mode
- [x] 1.5 MPEG audio with no frame header yet builds nothing instead of recursing
- [x] 1.6 `DemuxRun` reports a new channel count of the playing sound

## 2. Tracks and status

- [x] 2.1 `TrackChoice.initial` takes the playable audio tracks and chooses among them first
- [x] 2.2 `DemuxRun` passes the tracks it can build buffers for
- [x] 2.3 Undecodable sound reads "(not supported)" in the stream line and the audio list

## 3. Renderer

- [x] 3.1 `DemuxRun.resendSound(from:)` queues the playing sound again from its ring
- [x] 3.2 `DemuxEngine` resends after the renderer's automatic flush
- [x] 3.3 A failed renderer is flushed and fed again, and plays without sound after three failures

## 4. Fixtures and tests

- [x] 4.1 Fixtures: AAC, AC-3 and MP2 format changes, HE-AAC, 7.1 AAC, DTS with AC-3
- [x] 4.2 `SoundDecoding` decodes built buffers with Apple's decoder in tests

## 5. Verify

- [x] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 5.2 `/opsx:verify` passes
