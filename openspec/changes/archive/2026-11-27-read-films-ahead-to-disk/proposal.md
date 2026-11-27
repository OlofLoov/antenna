# Proposal

## Why

> As a viewer on Apple TV, I want a 4K episode to play to the end without the app closing, and without the picture stopping to buffer when my provider's server has a slow minute.

The owner's Apple TV 4K closed Antuna about ten minutes into an episode of a 4K series. It did not crash: tvOS ended the app for using 2.2 GB of memory, its limit. The episode was a Matroska file over plain HTTP, on the FFmpeg path.

The cause is how the FFmpeg path downloads. It reads a film from one connection and pauses the download with `suspend` once 4 MB wait unread. After the first `resume`, URLSession keeps delivering whatever `suspend` says, so a film from a server faster than its bit rate came into memory whole. On a Mac, playing a 10-minute 4K HEVC file from a local server held the file in one 1 GB buffer within seconds. On the owner's line the download ran ahead of playback at line speed until tvOS stopped the app.

The owner has a 10 Gbit/s line and wants a film read a few minutes ahead, not whole, so a slow or uneven server never stalls the picture.

## What Changes

- A film on the FFmpeg path is read about three minutes ahead of the play position into a file in Caches, and the download starts again when less than a minute and a half is left, in 8 MB range requests one after another. Memory holds at most about 25 MB of it.
- A skip within what is read ahead plays without asking the server. A skip outside it starts the read-ahead again at the new place.
- The file is deleted when the film stops, when another stream loads, and at launch with the live buffers. With too little free space the read-ahead is smaller, and with almost none the film plays from its connection as before.
- When the film plays from its connection, the connection closes once it holds 32 MB unread and opens again with a range where the reader got to. A connection that drops partway is opened again the same way.

Out of scope: films on Apple's player (MP4 and HLS), which buffer in the system's media service, and live channels, which keep reading their connection or the live buffer. A film the app does not mark as a film, such as an M3U entry, plays from its connection with the 32 MB bound.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `playback-engine`: new "Films keep memory steady" and "Films read ahead to disk".

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV, which share the FFmpeg path.
- Code: `HTTPByteStream`, `SeekableSource`, a new `FilmReadAhead` and the engine's film loading in AntennaDemux; a generated-body behavior in the test support's `FixtureServer`.
- Disk: up to 2.5 GB in Caches while a film plays, never past 1 GB short of full.
- Depends on nothing else.
