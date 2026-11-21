# Tasks

## 1. Picture shape and colors

- [x] 1.1 `SoftwareDecoder` sets the pixel aspect and color attachments from the FFmpeg frame
- [x] 1.2 `Deinterlacer` carries the source attachments and marks its output progressive
- [x] 1.3 SD with no color tags is tagged BT.601
- [x] 1.4 Fixtures and tests: 720x576 16:9 MPEG-2 and interlaced H.264 reach the renderer at 64:45 with SD colors

## 2. Handoffs in Apple's player

- [ ] 2.1 A ready file whose picture or sound cannot be decoded hands over to the FFmpeg path; HLS does not
- [ ] 2.2 Raw MPEG-TS at an `.m3u8` address hands over instead of failing
- [ ] 2.3 Fixture and tests: an `hev1` MP4, TS at an `.m3u8` address

## 3. Radio

- [x] 3.1 `StreamSniff.audio` from ID3 or two MPEG audio or ADTS frames
- [x] 3.2 The FFmpeg path hands `.audio` and `audio/*` content to Apple's player
- [x] 3.3 Tests: the sniff, and MP3 and AAC radio at addresses with no extension

## 4. A channel with no picture

- [x] 4.1 `DemuxRun` starts with sound only after 2 s of sound and no video packet
- [x] 4.2 Fixture and test: a broadcast whose video PID sends nothing

## 5. Zapping on one-connection accounts

- [ ] 5.1 `RetryPolicy.tune(afterSwitch:)` and `retriesOnce`
- [ ] 5.2 Both engines note their last close and use the switch policy within 3 s on the same host
- [ ] 5.3 Tests: the policy, a 403 after a switch that then plays, a first start that fails at once

## 6. Mac display

- [ ] 6.1 The FFmpeg path keeps the Mac display awake while playing or buffering
- [ ] 6.2 Test: the layer's setting follows play, pause and stop

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 7.2 `/opsx:verify` passes
