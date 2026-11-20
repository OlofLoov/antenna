# Tasks

## 1. Sound

- [x] 1.1 `SampleBuilder.soundStart` joins sound within 10 ms of the sound before it; `SampleBuilder` and `SoftwareDecoder` use it
- [x] 1.2 `SoftwareDecoder.pcmFormat` names 5.0, 5.1, 6.1 and 7.1 speakers with Apple's layouts; 7 and 8 channels with no mask take the WAVE layouts
- [x] 1.3 `SoundRing` keeps the last 10 seconds of each sound stream at a constant cost per packet
- [x] 1.4 Tests: buffer joins for TrueHD, DTS and AC-3 in Matroska and AAC and AC-3 in MPEG-TS, speaker labels, TrueHD from between major syncs, the ring

## 2. Pictures

- [ ] 2.1 HEVC samples and formats keep the base layer only: no units of a higher layer, no Dolby Vision metadata units
- [ ] 2.2 After a start, a skip or a resume, pictures before the first keyframe's time are dropped until the next keyframe
- [ ] 2.3 Fixtures and tests: HEVC with open GOPs started at a CRA, Dolby Vision layers in hvcC and Annex B

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
