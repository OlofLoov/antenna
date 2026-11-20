# Design

## Context

The FFmpeg path hands each packet's container time to the renderers as it is. `AVSampleBufferVideoRenderer` and `AVSampleBufferAudioRenderer` play under one `AVSampleBufferRenderSynchronizer`, which the engine sets to the first picture's time at the start and lets run. Any later change in the stream's own clock reaches the renderers unchanged. `fix-green-frames-and-sound-joins` left these as open problems of live MPEG-TS: clock jumps, the 33-bit wrap, sound that appears late and the default choice of an audio description track.

No provider stream was used. Each case is a generated stream in `Packages/AntennaCore/Sources/AntennaTestSupport/Fixtures`, run through `DemuxRun` into recording renderers with `PictureCheck.run`, or through `DemuxEngine` over the fixture server. `scripts/splice-ts.py` joins two MPEG-TS files the way a splicer does: each PID's continuity counter carries on, so FFmpeg sees no lost packets and only the timestamps change. Without that, FFmpeg marks the first packet after the join corrupt and the run drops a second of pictures for an unrelated reason.

| Fixture | Before | After |
|---|---|---|
| `jump-forward.ts`, 2 s at 1.4 s then 2 s at 61.4 s | pictures queued with a 58 s hole; the renderer would hold the second feed until the clock reached it | pictures every 40 ms throughout, sound joined, sound as far from the picture as the feed has it |
| `jump-back.ts`, 2 s at 31.4 s then 2 s at 1.4 s | the second feed queued 32 s behind the first; by the engine's starved check the channel would buffer and then drop | as above |
| `pts-wrap.ts`, 5 s across the 2^33 wrap | already continuous: FFmpeg unwraps it | unchanged; the test pins it |
| `late-audio.ts`, 2 s of picture then picture and sound on a PID the first PMT did not list | no sound at all; the audio list empty | sound from the moment it appears, listed as `audio-0` and selected, its format reported |
| `audio-pid-change.ts`, sound moves from PID 0x101 to 0x102 after 2 s | sound for the first 2 s, then none | sound for all 4 s with no gap at the move |
| `audio-description.ts`, English audio description first, main English second | `audio-0`, the described track, plays | `audio-1` plays |

FFmpeg's own wrap handling: `libavformat` sets a wrap reference 60 s before each stream's first timestamp and adds or subtracts 2^33 for timestamps on the far side of it. That covers the first wrap of a connection whichever side of the wrap the channel starts on. Once the stream's raw clock passes the reference again, about 26.5 hours in, FFmpeg's times jump back by exactly 2^33; the run's wrap check (below) takes that up. It also means a jump back of more than 60 s before the first timestamp comes out of FFmpeg as a jump forward of 26.5 hours less the jump. The re-timing treats it like any other jump.

## Decisions

### Re-time live streams in the run

`LiveTimeline` (AntennaDemux) moves each packet's presentation and decode time by an offset before the run uses it, so `SampleBuilder`, the sound ring, subtitles, the start time and the engine's clock all see one timeline that carries on. A run has one when the demuxer gives no length, which is every live stream and timeshift run; films keep their container times, which skipping and resuming depend on.

Options considered:
- Flush the renderers and set the synchronizer to the new time at a jump (rejected): the pictures and sound queued from the old feed are lost, the engine would need to know where in the queues the jump falls, and timeshift positions, which count from the clock, would jump too.
- Let each stream carry on by itself (rejected): picture and sound of the new feed would lose the distance between them, up to the muxer's limit of about 0.7 s.
- One offset for the run, set by the first stream that jumps and taken by the others (chosen).

### What counts as a jump

Each picture and sound stream is checked on its own. Its decode time is compared with where its last packet ends: the last decode time plus the packet's length, or the step between its last two packets when FFmpeg gives no length. A difference over `LiveTimeline.jumpLimit` (1 s) either way is a jump. A second is above the jitter of broadcast muxers and below any break in a feed. Subtitles are not checked; they are sparse and take the newest offset.

The first stream to jump sets its offset so it carries on exactly, and records the size of its jump. A stream whose jump is within `spliceMatch` (2 s) of that size takes the same offset, so the new feed's sound keeps its distance from its picture. In the fixtures the sound meets the old sound 27 ms early, the distance the old feed's sound ran past its last picture. A jump within `jumpLimit` of a whole number of 2^33 wraps of 90 kHz moves by exactly that many wraps and does not count as a jump, so nothing waits.

A network stall of more than a second also looks like a jump forward and is closed up. The packets after a stall arrive late either way; closing the gap does not add to that.

### Pictures wait for a keyframe after a jump

A jump in the picture's times calls `waitForKeyframe` with "timestamps jumped", as lost data does (`playback-engine/undecodable-pictures-are-not-shown`). A new feed that starts on a keyframe loses nothing; one that starts between keyframes keeps the last picture on screen until its first keyframe instead of decoding pictures that refer to the old feed. The engine's log line for dropped pictures names it.

### Streams found after the start

FFmpeg's MPEG-TS demuxer adds a stream when a program table lists a new PID, but the header read stops at the first one. `Demuxer.nextPacket` now describes streams it has not seen and adds them to `streams`. The run compares the count after each packet; `DemuxRun.addStreams` makes builders for new sound streams and decoders for new DVB subtitle streams, and reports the lists through `tracksChanged`, which updates the engine's `DemuxStart` and publishes `tracks()` and `presentation()`. Track ids stay stable because new streams are added at the end.

FFmpeg never removes a stream. A PID that stops is a stream that sends nothing more.

### Moving to another sound

`followSound` notes where each sound stream with a builder has got to. When a sound packet arrives from a stream other than the one that plays, and the run has no sound, or the one that plays is undecodable, or it has sent nothing for `soundGone` (1.5 s) by that packet's time, the run chooses among the streams that sent in that window with `TrackChoice.initial` and moves to it. What is queued of the old sound plays out; the new sound is queued out of its ring from where the old sound's last queued buffer ends. The demuxer reads about 5 s ahead of the clock (the feeds' limits), so the move is made before the clock reaches the end of the old sound.

1.5 s is above the distance between two sound streams of one program in a muxer and below the 5 s the feeds hold, so the move comes before anything is heard missing.

Options considered:
- React to the program table changing (rejected): FFmpeg does not report it, and a table can list a PID that never sends.
- Switch only when the stream that plays is gone for good (rejected): nothing in MPEG-TS says so.

### The ring keeps frames with no time

FFmpeg's MPEG-TS demuxer splits a PES packet of several AAC frames into one packet per frame and gives a time only to the first. `SoundRing` dropped every packet with no time, so a sound switch on a broadcast resent one frame in 17 from the ring (one every 0.36 s in the fixtures) until new packets came. It now keeps a packet with no time after a timed one and lets it go with it. `SoundRing.kept(around:)` starts at the last timed packet at or before a time; `DemuxRun.queueKept` builds from there and leaves out the buffers that end before that time. The user's sound switch, a resend after an output change and the move above all use it.

### Audio description passed over

`DemuxedStream.isAudioDescription` is FFmpeg's visual impaired disposition, which its MPEG-TS demuxer sets from the ISO 639 language descriptor's audio type 3 and from DVB's supplementary audio descriptor. `MediaTrack.isAudioDescription` carries it; `AVPlayerEngine` sets it from the `describesVideoForAccessibility` characteristic of an HLS rendition or file track. `TrackChoice.audio` applies its rules to the tracks that are not audio description, and to all of them when there are no others.

A viewer who picks the described track on a channel gets the main track in that language next time, since the remembered pick holds only the language. Following the system's "Prefer Audio Descriptions" setting would fix that and is left for later.

## Platforms

All of it runs on iPhone, iPad, Mac and Apple TV: the FFmpeg path is shared, and the audio description flag is in AntennaCore and the shared `AVPlayerEngine`.

## Not verified here

No real provider stream and no device. How long a real splice takes to reach its first keyframe, how far a real broadcast's sound streams drift apart, and whether a real provider moves its sound to a new PID were not measured. `AVSampleBufferAudioRenderer` was not heard playing the 27 ms overlap at a splice. The jump of a whole wrap that FFmpeg gives about 26.5 hours into a connection is checked by a unit test with made-up packets, not with a stream that long.
