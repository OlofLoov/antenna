# Read the sources real providers send

## Why

A household setter-upper adds a provider that works in other players, and
Antenna shows nothing, shows broken names, or shows a guide with gaps. The
compatibility review of 2026-11-21 traced these to parsing that is stricter
than the panels and guide generators in the field:

- One Xtream category row with a null or numeric name fails the whole
  source: no channels, no movies, no series.
- A playlist saved in Latin-1 or Windows-1252, common with older European
  and Latin American panels, shows "M�nchen" for "München". A guide
  in Latin-1 with no encoding declaration fails to load at all.
- XMLTV programmes without a `stop`, which the XMLTV format allows, are
  dropped, so those guides show only some programmes.
- A channel whose `tvg-id` differs from the guide's id only by case gets no
  guide. An Xtream guide id sent as a number is lost.
- A bare word such as `catchup` in an `#EXTINF` line hides every attribute
  after it, so the channel loses its guide id and group.

Afterwards the same provider loads in full: the channels, the group names
that decode, names in the right letters, and a guide for every channel the
guide covers.

## What Changes

- Xtream category lists drop rows without a usable id or name and keep the
  rest. A name sent as a number is read as text. When the category call
  fails, live channels, movies and series still load, without group names.
- Playlist text from a file or a link is read as UTF-8, as UTF-16 when it
  starts with a byte-order mark, and byte by byte as Windows-1252 where it
  is not valid UTF-8. One function in AntennaCore does this for every path.
- A guide that declares no encoding, or declares UTF-8, has bytes that are
  not valid UTF-8 read as Windows-1252.
- A programme without a `stop` ends where the next programme on the same
  channel starts. The last one on a channel lasts two hours.
- A channel's guide id that finds no programmes is tried again ignoring
  case. An Xtream `epg_channel_id` sent as a number is read as text.
- A bare word among the `#EXTINF` attributes is skipped, and the attributes
  after it are read.

Out of scope:
- Stream headers and a per-source User-Agent (`#EXTVLCOPT`, `#EXTHTTP`,
  Kodi pipe links). A separate change covers them.
- Lowercase `#extinf:` and bare URL lists with no `#EXTINF`. Both stay as
  the m3u-playlists spec has them.
- Latin-1 inside CDATA sections and comments of an undeclared guide.
- Xtream live in HLS when the panel allows only `m3u8`.

## Capabilities

### Modified Capabilities

- `xtream-vod-client`: Category lists fail whole becomes Broken category
  rows are skipped.
- `xtream-live-source`: Category id as number or string drops bad rows
  instead of failing; new Channels load without categories.
- `local-m3u-file-import`: an old Windows encoding imports with the right
  letters.
- `m3u-playlists`: new Playlist text in older encodings; Standard attributes
  map to the channel skips a bare word.
- `xmltv-guide-parsing`: Invalid intervals are dropped no longer drops a
  programme for a missing stop; new Programmes without a stop and Guide
  text in Latin-1; the entity rule keeps its pass-through wording for
  documents that need neither rewrite.
- `guide-data`: Programmes land on the right channels retries a missed id
  ignoring case.

## Impact

- AntennaCore: `XtreamClient` (category decoding, `vodLoad`, `seriesLoad`),
  a new `TextEncoding` shared by `PlaylistImport`, `XtreamBody` and
  `XMLEntitySanitizer`, `XMLTVParser`, `SourceGuide` and `GuideIndex`
  lookups, `M3UParser.attributes`.
- Apps: `ShelfLoader`, `SourceSetup`, `SourceLoader` and `SourceConnector`
  call the AntennaCore functions above. No screen changes, so no board.
- No data model, sync or dependency change. Stored playlist text is already
  UTF-8 and is not re-read.
