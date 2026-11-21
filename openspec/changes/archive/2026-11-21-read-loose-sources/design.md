# Design

## Context

The compatibility review of origin/main f9392ec6 (2026-11-21) found these
parsing gaps. Each was checked against the code before this change:

- `XtreamCategory` decoded `category_name` as a strict string and the
  category calls used `decodeWholeList`, so one bad row threw
  `decoding(path: "[1].category_name")`. `liveLoad()` awaited the categories
  with `try`, so the source loaded nothing. `ShelfLoader` did the same for
  movies and series.
- `PlaylistImport.decode` read UTF-8 and the UTF-16 marks, but invalid
  UTF-8 became U+FFFD. `SourceLoader` and `SourceConnector` called
  `String(decoding:as: UTF8.self)` and skipped the UTF-16 marks too.
  `XtreamBody` already reads invalid bytes as Windows-1252.
- `XMLParser` treats an undeclared document as UTF-8 and stops at the first
  invalid byte, so an undeclared Latin-1 guide failed as malformed. A
  declared `ISO-8859-1` guide parsed.
- `XMLTVParser` required a parseable `stop`.
- `SourceGuide.schedules` is keyed by the trimmed id and every lookup is an
  exact dictionary read.
- `XtreamLiveStream` decoded `epg_channel_id` as an optional string with
  `try?`, so a number became nil.
- `M3UParser.attributes` and `asciiAttributes` ended at the first token
  without `=`. The m3u-playlists spec stated that as behavior.

No board changes. No design-system requirement applies.

## Decisions

### Broken category rows

Options:
1. Repair every row: an empty name for a missing one, a generated id for a
   missing id.
2. Drop a row whose id or name is missing or null, read a number in either
   field as text, keep the rest.

Chosen: 2. A row without an id cannot be linked from a stream, and a row
without a name would show as an empty group. Streams in a dropped category
show no group, the same as streams whose category id matches nothing.

The calls use `decodeLossyList`, which already backs `liveStreams()`. When
the category call fails in any way other than cancellation (bad status,
transport, a body that is not a list), `liveLoad()`, `vodLoad()` and
`seriesLoad()` go on without categories. A failed stream or title call
still fails the load. `vodLoad()` and `seriesLoad()` are new so the rule is
in AntennaCore and tested there; `ShelfLoader` calls them.

### One text decoder

`TextEncoding` in AntennaCore holds the UTF-8 sequence check and the
Windows-1252 table, moved out of `XtreamBody`. `TextEncoding.text(_:)`
reads a UTF-8 mark, then the UTF-16 marks, then UTF-8 with each byte that
starts no valid sequence read as Windows-1252. Per byte rather than per
document, so a file that mixes UTF-8 names with a few Latin-1 ones keeps
both. `PlaylistImport.decode`, `SourceLoader` and `SourceConnector` call it.
Windows-1252 over Latin-1 because it is a superset for the printable range
and is what panels on Windows save.

Valid UTF-8 costs one check per byte above 0x7F. ASCII text is copied as is.

### Latin-1 guides

The guide is streamed from disk through `XMLEntitySanitizer`, which already
rewrites bytes in pieces. It gains the same per-byte repair, on only when
the XML declaration names no encoding or names UTF-8. A guide declaring
`ISO-8859-1` or any other encoding is left to `XMLParser`, which reads it
correctly; converting it would double-encode. Latin-1 inside CDATA,
comments and the DOCTYPE stays as is, because the sanitizer skips those.

Options considered: transcode the whole file before parsing (a second full
copy of a 100 MB guide on Apple TV), or inject an `encoding="windows-1252"`
declaration (wrong for a guide that is mostly UTF-8). The per-byte repair
keeps the single streamed copy.

### Programmes without a stop

Options:
1. Give every stopless programme a fixed length.
2. End it at the next start on the same channel, and give the last one a
   fixed length.

Chosen: 2. Guides that omit `stop` list programmes back to back, so the next
start is the real end. The parser holds the stopless programme of each
channel until the next programme of that channel arrives in the document,
then ends it there. If that next start is not later (an unsorted guide),
or no programme follows, the stopless one gets the cap.

The cap is two hours (`XMLTVParser.stoplessLength`). A guide's last
programme is often the late film or the overnight loop; two hours covers a
film without claiming the next morning. `SourceGuide.Builder` still sorts
and cuts overlaps afterwards, so an unsorted guide ends up the same as a
sorted one wherever the cap was longer than the gap.

Memory: one pending programme per channel, at most the channel count.

### Case-insensitive guide ids

Options:
1. Fold every id to lowercase when the guide is built and when channels ask.
2. Keep exact keys and retry a miss through a folded index.

Chosen: 2. Two ids that differ only in case stay separate when a guide has
both, and an exact match always wins. `SourceGuide` builds a map from the
lowercased id to the first stored id with that folding, once per guide.
`SourceGuide.slots(for:)` reads the exact key, then the folded one.
`GuideIndex.located` tries every layer exactly before trying any layer
folded, so a lower guide with the exact id beats a higher one that only
matches ignoring case. The channel's `GuideKey` keeps the playlist's id;
reminders and favorites still compare the same strings. Ids were already
trimmed of spaces and newlines.

### Bare words among attributes

The attribute loop skips a token with no `=` and reads on. A value without
quotes still ends at the first space, so `tvg-name=Two Words tvg-id="x"`
now gives the name "Two" and the guide id "x". Both the character and the
ASCII readers change the same way, so they keep agreeing.

## Identifiers

- `TextEncoding.text(_ data: Data) -> String`, `TextEncoding.utf8Length`,
  `TextEncoding.windows1252(_:)`.
- `XtreamClient.vodLoad()`, `XtreamClient.seriesLoad()`.
- `XMLTVParser.stoplessLength` = 7 200 seconds.
- `SourceGuide.slots(for:)`, `SourceGuide.name(for:)`.

## Risks

- A guide that is mostly UTF-8 with one stray Latin-1 byte now parses with
  that one character in Windows-1252, instead of failing whole.
- A real 2-hour cap can overrun a short last programme until the next
  refresh brings the following one.
