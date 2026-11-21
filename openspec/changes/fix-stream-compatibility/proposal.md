# Proposal

## Why

> As a viewer of European SD channels, radio and provider films, I want each stream to play the way it plays in VLC or TiviMate: the right shape, with sound, without "can't read this stream" on things my provider sends every day.

The red-route stream review (2026-11-21) ran ffmpeg-made streams through both playback paths and found these, most viewers first:

- Wide SD pictures are squeezed. A 720x576 16:9 channel shows at 5:4 when its video is MPEG-2 or interlaced H.264, which is most DVB-sourced SD. The FFmpeg path's own MPEG-2 decoder and the deinterlacer make new pictures and leave out the pixel shape and the color tags. Untagged SD may also come out in HD colors.
- A film in MP4 that Apple's player cannot decode plays black or silent. HEVC tagged `hev1` (ffmpeg's default), AV1 on older chips, MP2 or DTS sound. The item reaches ready, so nothing hands it to the FFmpeg path, which decodes all but AV1.
- Icecast and Shoutcast radio at an address with no extension fails as unreadable. It goes to the FFmpeg path, whose build has no MP3 or ADTS reader.
- An `.m3u8` address that serves raw MPEG-TS fails on purpose. Restreamers and some panels do this, and the FFmpeg path plays it.
- A channel whose program lists a video track that never sends, as off-air and radio channels do, never starts: sound waits for a picture and the start fails after 15 seconds.
- On a one-connection account, zapping can get a 403, an odd 4xx or a timeout while the panel still holds the old connection. The tune retry tries only busy servers and server errors, so the next channel fails at once.
- On a Mac, the display dims and sleeps during a raw-TS channel. The FFmpeg path's video layer does not keep the display awake on macOS, and every Xtream live channel plays there.

## What Changes

- Pictures on the FFmpeg path carry their pixel shape and color tags to the screen: MPEG-2 pictures from the stream, deinterlaced pictures from the picture they came from. SD with no color tags is shown in SD colors (BT.601).
- Apple's player checks that it can decode a file's picture and sound once it is ready, and hands a file it cannot decode to the FFmpeg path. HLS stays with Apple's player.
- The FFmpeg path hands a stream that turns out to be MP3 or AAC radio to Apple's player, from its first bytes or an `audio/*` content type.
- Apple's player hands raw MPEG-TS at an `.m3u8` address to the FFmpeg path instead of failing.
- The FFmpeg path starts a channel with sound only when no packet of its listed video has arrived after 2 seconds of sound.
- Right after a channel closed on the same server, a refusal or a timeout on the next channel is tried once more after a second. A first start still fails at once.
- On a Mac the display stays awake while the FFmpeg path plays, and may sleep when paused or stopped.

Out of scope, from the same review: request headers and User-Agent (the sources lane), DVB teletext, CEA-608 in raw TS, PGS, AV1 and VP9 on the FFmpeg path, Dolby Vision profile 5, MPEG-2 4:2:2, HLS with MPEG-2 segments, self-signed certificates, AirPlay video on the FFmpeg path, and H.264 PAFF.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `playback-engine`: "Every common stream type plays" gains the handoffs, radio and the channel with no picture; "Streams that cannot play fail with a clear reason" drops raw video at an HLS address as a cause; "A channel that won't start is retried briefly" retries refusals right after a switch; new "Pictures show at their shape and in their colors" and "The display stays on while a stream plays".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV for the picture, handoffs, radio, no-picture start and zapping retry. The display sleep fix is Mac only; iPhone, iPad and Apple TV keep the display on by default.
- Code: `AntennaDemux` (`SoftwareDecoder`, `Deinterlacer`, `DemuxRun`, `DemuxEngine`), `AVPlayerEngine+Stream` in Apps/Shared, `StreamSniff` and `RetryPolicy` in AntennaCore.
- New stream fixtures from `scripts/make-stream-fixtures.sh`.
- The sources lane adds request headers to `HTTPByteStream`, `StreamProbe` and `AVPlayerEngine+Stream` at the same time; the two diffs touch different lines.
