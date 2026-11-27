# Design

No screen changes, so no board.

## What grew

`HTTPByteStream` held unread bytes in one `Data` and called `dataTask.suspend()` at 4 MB, `resume()` below 2 MB. Measured on a Mac with a range-capable local server and a reader taking 6 MB/s:

- never resumed: the buffer stays at 3 MB;
- resumed once: URLSession delivers the rest of the body regardless of later `suspend` calls, 1 GB within a second.

`DemuxEngine` playing a 10-minute 2160p HEVC Matroska file (13 Mbit/s, E-AC-3 and TrueHD, SRT) from that server had a physical footprint of 530 to 590 MB from the first ten seconds on; the same film as MPEG-TS, 1,050 MB. Nearly all of it was one `__DataStorage` of 985 MB (`heap`). On the owner's line the download outran playback the same way, at line speed instead of instantly, until tvOS stopped the app at 2.2 GB.

## Decision 1: where the bytes ahead live

Options:

1. **Keep one connection and make `suspend` hold**, by blocking the delegate callback until FFmpeg catches up. Bounded at 4 MB, tried first. A blocked callback holds a thread of the session's queue, many engines in the tests ran out of threads, and a paused film's connection timed out after the 8-second request timeout. It also reads only seconds ahead.
2. **Range requests of a fixed size, one after another** (8 MB each). Bounded by construction, but a 4K film at 80 Mbit/s asks every 0.8 s, and it still reads only seconds ahead.
3. **Read minutes ahead into memory.** Three minutes of an 80 Mbit/s remux is 1.8 GB, close to the tvOS limit by itself.
4. **Read minutes ahead into a file in Caches**, with a small memory window. Chosen.

The owner asked for about three minutes ahead and no buffering. Only option 4 gives both within the memory limit.

## Decision 2: the file

`FilmReadAhead` keeps a ring file of `capacity` bytes in a session folder of `TimeshiftStore.standard`, the folder the live buffers use, so `clearLeftovers()` at launch deletes a file left by a crash. Byte `n` of the film is at `n % capacity`; the bytes from `lower` to `upper` are there.

- `capacity` is the least of 2.5 GB, the film's length and free space less 1 GB (`TimeshiftLimits.keepFree`). Below 64 MB no file is made. The space is reserved with `F_PREALLOCATE`, halving on failure, so writes never fail for space partway through.
- A download thread asks for 8 MB ranges one after another (`bytes=upper-(upper+8 MB-1)`), reads each 1 MB at a time and writes it with `pwrite`. URLSession may deliver a whole answer however slowly it is read, so the range size is what bounds memory; with open-ended requests a refill at full speed held 160 MB in freed-but-dirty large malloc blocks. Ahead means `upper` less the play position: the target is the film's bit rate (length over duration, once the first run knows the duration) times 180 s, 256 MB while it is unknown, and never more than seven eighths of the ring less two chunks. Below 90 s ahead, or half the target, the download starts again. At the target it stops asking, so a paused film holds no connection to time out.
- A dropped connection is asked again after 0.5 to 4 s. While bytes are held ahead it goes on trying; the film's bytes fail only after four drops in a row once the reader has caught up.
- A write never comes within a chunk of the play position from behind, and a read never takes the chunk past `lower` that a write may be replacing.

Memory per film: one range answer (8 MB at most), the 1 MB write chunk, and up to 16 MB of pinned bytes (below).

## Decision 3: skips

Each run reads through its own `FilmReader` over the engine's one `FilmReadAhead`, kept on the engine until `close()`. A skip starts a new run, as before; its FFmpeg reads the header at the start of the film and, for Matroska, the index near the end, then jumps to the keyframe.

- A read within the ring, or up to 8 MB past `upper`, is served from the file and moves the play position.
- A read elsewhere goes over a connection of the reader's own while the download waits, since many providers allow one connection per account. Those bytes, and the first 8 MB read from the ring, are kept in memory up to 16 MB, so the next run's header and index reads need no network.
- Reading on for 8 MB outside the ring moves the ring there (`jump`), and the download starts at the new place.

Measured with a 200 MB ring over the 10-minute 4K file at four times real speed: a skip forward 60 s within the ring and one back 30 s took 0.10 to 0.13 s and asked the server nothing new except the download's own refill; a skip to 8:20, outside it, took 0.11 s and moved the ring.

## Decision 4: when the film plays from its connection

Loads that do not say `isLive: false`, servers without ranges or length, and devices without room keep `SeekableSource` over one `HTTPByteStream`. Two changes bound them:

- At 32 MB unread (`HTTPByteStream.overflowLimit`) a stream that takes ranges cancels its task and ends with `stoppedSendingData`; the bytes held still read.
- `SeekableSource.read` opens a connection that ended with `stoppedSendingData` again at its position, up to three times in a row with no byte between them.

Live streams arrive at their bit rate and never reach 32 MB; a live stream with no length is never closed this way.

## Identifiers

- `FilmReadAhead`, `FilmReadAhead.Limits`, `FilmReader` in AntennaDemux.
- `DemuxEngine.film`, `filmLimits`, `filmStore`, `filmSource(_:url:options:)`.
- `HTTPByteStream.overflowLimit`, `heldBytes`.
- `FixtureServer.Behavior.generated(length:)`, `FixtureServer.generated(from:count:)`.
