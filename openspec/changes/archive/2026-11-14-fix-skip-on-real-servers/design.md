# Design

## Context

PR #364 added the movie transport. `TitleTransport` shows "This stream can't skip" when `ShelfPlayback.seek` gets a `SeekRefusal` from the engine. The owner saw it on ordinary titles.

Causes found:

1. `HTTPByteStream` opened a film from the start with no Range header. On a 200 answer it set `acceptsRanges` only from an `Accept-Ranges: bytes` header, and `expectedLength` only from Content-Length. Many IPTV panels serve films through a script that honors a range with 206 but sends neither header on a plain request. `SeekableSource.canSeek` was then false, so `DemuxStart.canSeek` was false and `DemuxEngine.seek` threw `notSeekable`. Matroska and AVI films always take this path: the router sends them to the demuxer by extension, and Apple's player hands them over (`EngineHandoff.toDemuxer`) when it sniffs them. `DemuxFilmTests` reproduces it with the new `quietRanges` fixture.
2. `DemuxEngine.seek` read `current?.start`, and a skip releases `current` until the reopened film has its first frame. A second skip in that window (two clicks, or a click after a slow first skip) threw `notSeekable`. It also lost the film's origin.
3. `SeekableSource.seek` opened the new range request before closing the old connection. A provider with one connection per account can refuse the second request. The skip then failed instead of showing the notice, but it is the same complaint.
4. `AVPlayerEngine.seek` refused while `seekableTimeRanges` was empty, which a ready item can report for a moment while it buffers after a skip.

Before PR #367 the title details call was never wired, so the container extension from get_vod_info was never applied and every movie went out as `.mp4`. That changed which engine opened a Matroska film first (Apple's player, then a handoff), not whether it could skip: both routes end in the same `HTTPByteStream` request. It was not the cause of the notice.

## Decisions

### Asking for a range from the start

A film opens with `Range: bytes=0-` (`HTTPByteStream(asksForRange:)`, set when `options.isLive == false`). A 206 answer proves the server skips. The length comes from Content-Range, or from Content-Length plus the offset when the total is `*`. Options considered:
- Trust `Accept-Ranges` only (the old way): misses the servers above.
- A separate probe with a small range before opening (rejected): one more round trip on every film, and a second connection on providers that allow one.
- Assume a film with a length can skip and find out on the first skip (rejected): the controls could not say so up front, and a refused skip would come after the press.
- A range from the start (chosen): the same single request, the same answer for servers that already worked, and a definite answer for the rest. Browsers and Apple's player send the same header.

Live TV keeps a plain request: some servers refuse a range on a stream with no end.

### A skip during a skip

`DemuxEngine.lastStart` keeps the start of the address loaded. It is set with `current.start` and cleared on `load`. `seek(to:)` uses `current?.start ?? lastStart` for `canSeek`, the length and the origin.

### Closing the old connection first

`SeekableSource.seek` swaps in the new stream and cancels the old one before `openBlocking()`. If the new request fails the read fails too; with the old connection still open, a one-connection provider would have failed it anyway.

### Saying it up front

`PlaybackPosition` gains `canSkip` (default true). `DemuxEngine` sends `!isLive && start.canSeek`, `AVPlayerEngine` sends `!isLive && stream.canSeek`. `TitleTransport.notice` is now computed: the line said after a refused press, or `cannotSkip` while the controls show and `canSkip` is false. `skip`, `drag` and `beginSlide` then only show the controls and the line. The views did not change: they already show `transport.notice` at the top of the picture on every platform.

## Boards

`iPhone-Title-Player-Transport` describes `title.transport.notice`; its note now says the line shows with the controls from the moment the player knows. It stays undrawn, as before. The iPad, Mac and Apple TV transports place the same line at the top of the picture. Follows `design-system/accessibility-identifiers-follow-the-board`.

## Platforms

All four: the engines and `TitleTransport` are shared.
