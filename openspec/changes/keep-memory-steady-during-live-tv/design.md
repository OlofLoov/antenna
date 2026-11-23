# Design

## Context

See proposal.md for why. What exists on 2026-11-23:

- Live TV in the main player records into the local buffer and every run
  reads it back (`PlaybackOptions.recordingLive()`). The run reads through
  `TimeshiftBytes`, whose reader calls `DiskTimeshiftFiles.read` for each
  part: a new `FileHandle`, a seek and `read(upToCount:)`.
- A run demuxes on a `Thread` of its own (`DemuxRun.start`), and records on
  another (`TimeshiftRecorder.start`). Neither had an autorelease pool
  inside its loop. A `Thread` drains the pool around its block only when
  the block returns, which for live TV is at the next channel change.
- `HTTPByteStream` holds what the connection sends in one `Data`, appends
  each delivery and took each read with `removeFirst`. A `Data` is its own
  slice type, so `removeFirst` moves the slice's start and keeps the
  storage, and the next append grows the storage past it. Every byte the
  connection ever sent stayed allocated. The recorder reads the connection
  when the channel records, the run reads it when it does not, and a
  stream opened ahead of a zap trims it with `removeFirst` too.
- Interlaced H.264 is decoded with VideoToolbox and deinterlaced with Metal
  on the demuxing thread (`FieldPictures`, `Deinterlacer`).

## Measurements

All on a Mac (macOS 27.2, Apple silicon) in debug package tests, with
streams made with ffmpeg: 1080i H.264 at 4 Mbit/s and 720p50 H.264 at
4 Mbit/s, each with AAC sound.

| Path | Stream time | Before | After |
|---|---|---|---|
| Buffer recorded and read back on threads of their own, 32 KB reads | 80 min, 2.4 GB read | 8 MB to 2.36 GB, growing with every byte read | 9.7 MB throughout |
| `DiskTimeshiftFilesTests`, 300 reads of 1 MB | | +300 MB | under the 32 MB limit |
| `HTTPByteStream`, 200 MB delivered and read, or kept as a stream opened ahead | | +212 MB either way | under the 16 MB limit |
| `DemuxEngine` with the buffer, real renderers, 1080i at 4.5 Mbit/s from a local server in real time | 25 min | 478 MB after 1 min, 1,525 MB after 25 | 419 MB after 1 min, 414 MB after 25, between 408 and 426 MB throughout |
| `DemuxRun` on 720p50, no buffer, renderer takes all | 30 min | flat at 104 MB | not run |
| `DemuxRun` on 1080i, no buffer | 30 min | 609 MB to 706 MB; heap showed 141,751 `MTLTextureDescriptorInternal` and 62,326 AGX compute contexts held | 570 MB to 625 MB, up and down with no trend |
| `DemuxMemoryTests`, 3,000 pictures | | +4.3 MB (576i), +2.7 MB (1080i) | +0.44 MB, +0.17 MB |

The two byte leaks are the crash. Every byte the player read back from the
buffer stayed in the demuxing thread's autorelease pool, and every byte
the connection received stayed in its storage, so a channel at 4 Mbit/s
grew by about 30 MB a minute for each, and the whole engine by about
42 MB a minute. Apple does not
publish the memory limit for an app on Apple TV, but growth at that rate
reaches any limit a 2 to 4 GB device can have within tens of minutes,
which fits the owner's 20. The deinterlacer leak is smaller, about 1 KB a
picture, and only on interlaced channels.

The 1080i run holds about 600 MB of pictures in steady state: 120 pictures
queued ahead of the renderer at 3 MB each, plus the decoder's and
deinterlacer's own. That does not grow and is out of scope here.

## Decisions

### 1. Where the pools go

Options:

1. One pool per packet in `DemuxRun.pump`, around `nextPacket()` and the
   handling of the packet. Covers every read FFmpeg makes through the
   avio callback, the decoder and the deinterlacer.
2. One pool per call inside `DiskTimeshiftFiles.read`. Covers the reads
   wherever they are called from.
3. A pool around each `Deinterlacer.pictures` call only.

Chosen: 1 and 2. The demuxing thread is where autoreleased objects pile
up, so the per-packet pool fixes the cause for every framework the run
calls. The pool in `DiskTimeshiftFiles` keeps the AntennaCore type safe on
any thread and is what the AntennaCore test pins. 3 alone would leave the
reads.

The loop body moved into `pumpPacket`, which returns false where the loop
used to break, because `break` and `continue` cannot leave the closure
`autoreleasepool` takes.

### 2. The connection's bytes

Options:

1. Replace `removeFirst` with `removeSubrange(0..<taken)`, which moves the
   bytes left down at every read.
2. Keep a read position into the storage, and clear the bytes before it
   once they are at least half the storage.
3. A ring of fixed size.

Chosen: 2. It keeps the code shape and the 4 MB limit, and each byte is
moved at most once. 1 moves up to 4 MB for every 32 KB read when FFmpeg
falls behind. 3 needs a size for the stream kept open ahead, whose window
the engine sets.

### 3. The recording thread

Writes through `DiskTimeshiftFiles.append` were measured on a thread of
their own: 20,000 appends left malloc within 1 MB. No pool is added there.

### 4. How the tests measure

`DiskTimeshiftFilesTests` reads on a new `Thread` and compares the
process's physical footprint, the figure the system closes apps on, before
and after, inside the thread so its pool has not drained. 300 MB of growth
before the fix against a 32 MB limit leaves room for noise.

`DemuxMemoryTests` hands 200 MB to an `HTTPByteStream` through its
delegate method, without a network, and reads each part back or leaves it
to the window of a stream opened ahead. It compares malloc's bytes in use
before and after against a 16 MB limit.

It also plays a one-second interlaced fixture over and over as
an endless live stream through a run, and compares malloc's bytes in use
after 300 pictures and after 5,300. The limit is 256 bytes a picture; the
old code left about 900 to 1,400.
