## Why

The owner found on 2026-11-23 that the app closes after about 20 minutes of
live TV on a real device, most likely Apple TV, with no crash log yet. The
system closes an app that uses too much memory, and live TV on the FFmpeg
path used more memory the longer a channel played, never giving it back
until the channel changed. A 4.5 Mbit/s channel reached 1.5 GB after 25
minutes on a Mac.

Afterwards a viewer can leave a live channel on for hours, interlaced or
not, and the app's memory stays where it was a minute in.

## What Changes

- Bytes read back from the local buffer are let go after each read. Before,
  every byte the player read back stayed in memory until the channel
  changed, which is 600 MB in 20 minutes of a 4 Mbit/s channel. Live TV in
  the main player always plays from the buffer, so this hit every channel.
- Bytes taken from the provider's connection are let go once taken.
  Before, the connection's buffer kept every byte it ever received, which
  is another 30 MB a minute at 4 Mbit/s, whether the channel played from
  the local buffer or straight from the connection, and in a stream kept
  open ahead of a zap.
- What the decoder and the GPU deinterlacer leave behind for each packet is
  let go after that packet. Before, an interlaced channel grew by about
  1 KB a picture, 50 pictures a second.
- A new requirement, "Live playback keeps memory steady", in
  `playback-engine`.

Out of scope:
- Apple's player (HLS). Its buffer is Apple's and capped at 8 seconds ahead.
- The memory a channel holds while it plays: up to 120 pictures ahead of the
  screen, about 375 MB for 1080i after deinterlacing. That stays flat; making
  it smaller is a separate change if a device needs it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `playback-engine`: adds "Live playback keeps memory steady".

## Impact

- Packages: `DiskTimeshiftFiles` in AntennaCore, `HTTPByteStream` and
  `DemuxRun` in AntennaDemux, with tests in both packages. Both packages ship on iPhone, iPad, Mac
  and Apple TV, so the fix reaches all four.
- Builds on `add-timeshift-catch-up-and-start-over` and
  `fix-stream-compatibility` (the deinterlacer) as they are. Blocked on
  nothing.
- No new container or dependency, so the C4 diagrams stay as they are.
