# Design

## Context

The FFmpeg path demuxes with FFmpeg and hands compressed sound to `AVSampleBufferAudioRenderer`, which decodes AAC, MP3, AC-3 and E-AC-3 (or passes Dolby to a receiver on Apple TV). MP2 is decoded by FFmpeg in `SoftwareDecoder` and handed over as PCM. `SampleBuilder` builds each buffer's `CMFormatDescription`.

The report named no channel or symptom, so the sound path was checked by running each fixture through `SampleBuilder` and decoding the buffers with `AVAudioConverter`, which uses the same Apple decoders as the renderer. The test helper `SoundDecoding` does this and measures, per stretch of one format, the channels, the length and the level. What it found:

| Stream | Before | Cause |
|---|---|---|
| AAC stereo then 5.1 (MPEG-TS) | every buffer after the change refused | `SampleBuilder.sampleBuffer` kept the format of the first ADTS frame |
| AC-3 stereo then 5.1 | 5.1 decoded as stereo | same, for the first Dolby header |
| MP2 stereo then mono | buffers with half the bytes the format says | `SoftwareDecoder.sound` made a new format only on a rate change |
| HE-AAC in MPEG-TS | 24 kHz output, a 15 kHz tone at 0.0002 | ADTS signals HE-AAC as LC at half the rate; Apple's decoder does not detect implicit SBR |
| 7.1 AAC in Matroska (configuration 12) | 12 channels in the format | the channel configuration was used as the channel count |
| DTS default, AC-3 second | silent | the default track was chosen whether or not it could be decoded |

Two renderer behaviors were found by reading the code. `AVSampleBufferAudioRenderer` flushes itself when the output configuration changes and posts `AVSampleBufferAudioRendererWasFlushedAutomaticallyNotification`; nothing listened, so what it held was lost and the sound came back only with newly demuxed data, seconds later. A renderer whose status is `.failed` stays silent until flushed; nothing checked it, and the clock watch would then take sound off the clock for the rest of the stream.

MPEG audio of unknown layer that never yields a frame header made `sampleBuffers(for:)` and `sampleBuffer(for:)` call each other without end. It is fixed with the rest.

## Decisions

### A new format whenever the header changes

`SampleBuilder` keeps the newest header it built a format from (`SoundHeader`: the ADTS AudioSpecificConfig, the `DolbyHeader`, or the `MPEGAudioHeader`) and builds a new format when a frame's header differs. The renderer takes a new format description between buffers. `SoftwareDecoder` compares both rate and channel count. The software path's `formatDescription` now follows the newest buffer, so the reported channel count follows too.

Options considered:
- Rebuild the format for every packet (rejected): a format description per packet costs an allocation each time and makes every buffer look like a change.
- Compare headers (chosen): one equality check per packet.

`DemuxRun` reports a new channel count of the playing sound through the existing `soundSwitched` callback when it is demuxed. That is a few seconds before it is heard; the picture changes are queued to the clock, but a badge that changes a little early was judged not worth a second queue.

### HE-AAC signalled explicitly

An AAC LC config at 24 kHz or less is declared as HE-AAC at twice the rate: format `kAudioFormatMPEG4AAC_HE`, 2048 frames per packet, and an AudioSpecificConfig with object type 5 and the doubled rate as its extension. A config with explicit SBR (object type 5 or 29, from Matroska or MP4) uses its own extension rate.

Options considered:
- Parse the AAC bitstream for an SBR extension element (rejected): needs a large part of an AAC parser in the app.
- Always LC (rejected): what broke.
- Assume SBR at 24 kHz and below (chosen): broadcast LC at 24 kHz or less is rare, and if it occurs Apple's decoder still decodes it, upsampled. The timing does not change: 2048 samples at 48 kHz last as long as 1024 at 24 kHz. Parametric stereo (HE-AAC v2) in ADTS still plays as mono.

### Speaker layouts

AAC formats carry the layout of their channel configuration: 1 to 7, 11, 12 and 14, with 7, 12 and 14 as eight channels. Configuration 0 (a program config element) stays unsupported. Dolby formats carry the layout for the header's audio coding mode and LFE bit, using Apple's AC-3 tags in Dolby channel order, where only 1, 2 and 6 channels had a layout before. E-AC-3 dependent substreams (7.1) are still described by the independent substream; Apple's decoder reads them from the frame.

### Choosing playable sound first

`TrackChoice.initial` takes the set of playable audio track ids. When the set has any of the stream's tracks, the usual rules (remembered pick, preferred languages, default, first) choose among those only; otherwise among all. The subtitle rule then sees the language of the sound that plays. `DemuxRun` passes the tracks it has a `SampleBuilder` for. This replaces the radio-only rule that picked the first decodable sound when there was no picture. Apple's player chooses its own tracks, so the parameter stays nil there.

### Undecodable sound says so

`SoundFormat.display(_:)` appends "(not supported)" to the format of sound the engine reports as not decodable. The stream line and the audio list's detail use it. No layout changes; the boards `TV-Player-Tracks`, `iPhone-Player-Tracks` and `iPad-Player-Tracks` already show a format in that detail slot, and the stream line is free text on `TV-Player`. The zap bar's sound badge already hides for undecodable sound.

### Queueing sound again after a flush

`DemuxRun` keeps the last 10 seconds of every sound stream for track switches. `resendSound(from:)` uses the same path as a switch, for the stream that plays: flush the feed, then queue the kept packets from the given time. `DemuxEngine` observes the renderer's automatic flush and asks for a resend from the flush time. Once a run has read to the end of a film it no longer takes requests, so a flush in the last seconds of a film is not refilled.

On each tick, a renderer with status `.failed` is flushed and fed again from the clock's time, and the error code is logged. After `soundFailureLimit` (3) failures on one stream it is taken off the clock with `playWithoutSound()` and the sound is reported as not decodable.

Options considered:
- Leave the gap after an automatic flush (rejected): seconds of silence on every receiver mode switch, which happens at the start of Dolby channels on Apple TV.
- Seek the demuxer back (rejected): live streams cannot seek, and the ring already holds the packets.

## Platforms

All of it runs on iPhone, iPad, Mac and Apple TV; the FFmpeg path and the track choice are shared. Receiver mode switches happen on Apple TV; headphone and AirPlay changes on iPhone, iPad and Mac.

## Not verified here

There was no real Apple TV, receiver or provider stream. The decoding checks run on a Mac with the same decoders; the automatic flush and a failing renderer are driven in tests, not by real hardware.
