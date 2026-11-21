# Send the headers a stream asks for

## Why

A household setter-upper has a playlist that plays in VLC or TiviMate and
fails in Antenna with "not allowed" or "unreadable". The playlist says how
to ask for the stream: `#EXTVLCOPT:http-user-agent=`, `#EXTHTTP:{...}`,
`#KODIPROP` headers, a `user-agent="..."` attribute, or Kodi's
`link|User-Agent=...&Referer=...`. Antenna dropped all of them, and for the
Kodi form it sent the `|` as part of the path, so the request went to the
wrong address. Some panels also allow only the User-Agent of the player
their customers use, and Antenna always sent the system default.

Afterwards those channels play on both players, and a source whose panel
wants a particular User-Agent can be given one in its settings.

## What Changes

- The playlist parser reads stream headers from `#EXTVLCOPT`
  (`http-user-agent`, `http-referrer`), `#EXTHTTP`, `#KODIPROP`
  (`inputstream.adaptive.stream_headers` and `common_headers`), the
  `user-agent` and `http-user-agent` attributes, and the Kodi `|` suffix,
  which leaves the link. A channel keeps them in memory only.
- Apple's player, the FFmpeg path's HTTP reader and the stream probe send a
  stream's headers on every request, seeks and reconnects included.
- Each source gets an optional User-Agent in its settings on iPhone, iPad,
  Mac and Apple TV. It goes on the source's provider requests (playlist
  download, Xtream calls) and on every stream from the source's server,
  under a channel's own headers.
- Header values are never logged or printed; a Referer can carry a token.

Out of scope:
- DRM keys and license headers in `#KODIPROP`.
- Headers on catch-up links built from a template, beyond the source's
  User-Agent.
- The MAG User-Agent on Stalker stream links. Stalker sends it on portal
  calls already; stream links come from other hosts.
- Guide downloads keep the default User-Agent.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `m3u-playlists`: new Stream headers from the playlist.
- `playback-engine`: new Streams are asked for with their headers.
- `sources-and-settings`: new A User-Agent per source.

## Impact

- AntennaCore: `StreamHeaders` and `StreamHeaderBook`, `M3UParser`,
  `Channel.headers`, `StreamProbe`, `SourceDescriptor.userAgent`,
  `XtreamClient`.
- AntennaDemux: `HTTPByteStream.request`, one line. Coordinated with the
  playback lane's `fix-stream-compatibility`, which touches other lines of
  the same files.
- Apps: `AVPlayerEngine+Stream`, `SourceLoader`, `SourceSetup`,
  `SourceRecord` (one optional synced field), the source details screens,
  and the boards `iPhone-Settings-Detail` and `TV-Settings-Details`.
