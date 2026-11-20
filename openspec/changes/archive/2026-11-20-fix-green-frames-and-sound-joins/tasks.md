# Tasks

## 1. Sound

- [x] 1.1 `SampleBuilder.soundStart` joins sound within 10 ms of the sound before it; `SampleBuilder` and `SoftwareDecoder` use it
- [x] 1.2 `SoftwareDecoder.pcmFormat` names 5.0, 5.1, 6.1 and 7.1 speakers with Apple's layouts; 7 and 8 channels with no mask take the WAVE layouts
- [x] 1.3 `SoundRing` keeps the last 10 seconds of each sound stream at a constant cost per packet
- [x] 1.4 Tests: buffer joins for TrueHD, DTS and AC-3 in Matroska and AAC and AC-3 in MPEG-TS, speaker labels, TrueHD from between major syncs, the ring

## 2. Pictures

- [x] 2.1 HEVC samples and formats keep the base layer only: no units of a higher layer, no Dolby Vision metadata units
- [x] 2.2 After a start, a skip or a resume, pictures before the first keyframe's time are dropped until the next keyframe
- [x] 2.3 Fixtures and tests: HEVC and H.264 films with open GOPs started between keyframes, Dolby Vision layers in hvcC and Annex B

## 3. Damage and decoder failures

- [x] 3.1 `Demuxer` reports packets FFmpeg marks corrupt; a run drops a corrupt picture and the pictures after it until the next keyframe
- [x] 3.2 The engine flushes a video renderer that failed or needs a flush, and the run queues pictures again from the next keyframe
- [x] 3.3 Fixture and tests: a channel with lost video packets, a restart after a flush

## 4. Verify

- [x] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 `/opsx:verify` passes
