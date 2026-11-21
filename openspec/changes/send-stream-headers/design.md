# Design

## Context

Checked against origin/main on 2026-11-21:

- `M3UParser` skipped every `#` line other than `#EXTM3U`, `#EXTINF` and
  `#EXTGRP`. `Channel` had no header field.
- `URL(string:)` turns `http://s/1.ts|User-Agent=VLC` into
  `http://s/1.ts%7CUser-Agent=VLC`, so the request asked for a path that
  does not exist.
- No stream request set a header: `HTTPByteStream.request`,
  `StreamProbe.run` and the `AVURLAsset` in `AVPlayerEngine+Stream` sent the
  CFNetwork and AppleCoreMedia defaults. Stalker sets the MAG User-Agent
  for its portal calls only.

## Decisions

### Where a stream's headers travel

Options:
1. A `headers` field on `PlaybackOptions`, passed by every caller of
   `load` and carried by each engine to every request it makes.
2. A lookup by stream address, `StreamHeaderBook`, filled when a source's
   channels load and read where each request is built.

Chosen: 2. The FFmpeg path builds `HTTPByteStream` in five places (first
open, zapping, seeking, reconnect, timeshift) and Apple's player in one;
option 1 would thread a value through each of them in the playback lane's
files, and through every `load` caller in the app (Live, Multi-View,
movies, catch-up, onboarding). Option 2 changes the three places that
build a request, one line each, and covers every path that reopens the
same address. The cost is shared state: `StreamHeaderBook.shared`, guarded
by a lock, replaced per source on each load and dropped with the source.

Lookups go by the exact address first, then by the source server's
origin (scheme, host, port), so the source's User-Agent also reaches
catch-up and timeshift links on the same server. An address's own headers
win over the server's.

### Precedence inside a playlist entry

Attribute (`user-agent`), then the directive lines between the previous
link and this one (`#EXTVLCOPT`, `#EXTHTTP`, `#KODIPROP`), then the `|`
suffix, each on top of the one before. Directive lines before `#EXTINF`
count for the next link, because playlists write them on both sides. They
end at the next link line, used or not.

Header names `user-agent`, `http-user-agent`, `referer`, `referrer`,
`http-referrer` and `origin` are spelled the standard way. A value or name
holding a line break is dropped, so a playlist cannot add headers by
injection.

### Apple's player

`AVURLAssetHTTPUserAgentKey` is public and carries the User-Agent. Other
headers go through `"AVURLAssetHTTPHeaderFieldsKey"`, which AVFoundation
reads but does not document. It is widely used in shipping players; if
App Review objects, the fallback is the User-Agent alone, which is the
header most panels check.

### Privacy

A Referer or a custom header can carry a token, so `StreamHeaders`
prints and dumps its names only, `Channel` leaves `headers` out of its
coding keys, and nothing logs them. The source's User-Agent is not a
secret: it is a product string the user types, synced with the source
record like its name.

### Per-source User-Agent

`SourceRecord.userAgent: String?`, optional, so CloudKit and the existing
store migrate without a step. `SourceDescriptor.userAgent` carries it.
It is set on the playlist download, on every Xtream call through
`XtreamClient(userAgent:)`, and registered on the book under the source's
server origin. Empty text means the default. It is edited in the source's
details next to the link and login, saved without a server check, and
the source reloads.

Boards: `iPhone-Settings-Detail` (iPhone, iPad and Mac share the form)
and `TV-Settings-Details` gain a "User-Agent" row under the guide link,
with the placeholder "Default". Design-system requirements followed: the
form rows and text fields of the existing details screen; nothing new is
drawn.

## Identifiers

- `StreamHeaders`, `StreamHeaderBook.shared`, `register(_:source:)`,
  `register(_:server:source:)`, `remove(source:)`, `headers(for:)`.
- `Channel.headers: StreamHeaders?`.
- `M3UParser.readHeaders(_:into:)`, `M3UParser.splitLink(_:)`.
- `AVPlayerEngine.headerOptions(_:)`.
- `SourceRecord.userAgent`, `SourceDescriptor.userAgent`.
