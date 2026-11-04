# 0001. M3U playlist parsing

- Status: Implemented
- Date: 2026-11-03
- Depends on ADRs: 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. Every criterion has a test
  citing it since the retroactive test pass.

## Problem

Most users arrive with an M3U playlist URL from a provider. The format is
loosely specified: attribute quoting, group tags and catch-up hints vary by
panel. The app must turn any of these into a stable list of channels quickly
enough that playlists with tens of thousands of entries do not stall the UI.

## Scope

In:
- `#EXTM3U` header attributes `url-tvg` and `x-tvg-url` (comma-separated).
- `#EXTINF` attributes: `tvg-id`, `tvg-name`, `tvg-logo`, `tvg-chno`,
  `group-title`, `catchup`, `catchup-days`, `tvg-rec`. Quoted and unquoted values.
  Attribute names are case-insensitive; the last duplicate wins.
- `#EXTGRP` as a group fallback.
- Stable, unique channel ids derived from the entry.
- Unknown directives ignored without losing the pending entry.

Out (explicitly):
- Downloading the playlist (spec 0004) or importing a local file.
- `#EXTVLCOPT` / `#KODIPROP` headers such as user-agent or referrer.
- Gzip or other compressed playlists.
- Classifying entries as live, VOD or series.
- Deduplicating entries that share a URL.

## User flow

1. User adds an M3U source (spec 0004).
2. The app downloads the playlist text and hands it to `M3UParser`.
3. The returned channels appear in the Channels tab. `epgURLs` is returned by
   the parser but discarded by the app today; a guide spec will consume it.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Header EPG URLs
Given a header `#EXTM3U url-tvg="http://a/epg.xml,http://b/epg.xml.gz"`
When the playlist is parsed
Then `epgURLs` contains both URLs in that order.

### AC-2 Standard attributes map to the channel
Given an entry with `tvg-id="x.uk" tvg-name="X" tvg-logo="http://l/x.png" group-title="UK" tvg-chno="12"`
When the playlist is parsed
Then the channel has `epgID` "x.uk", `name` "X", `logoURL` http://l/x.png, `group` "UK" and `number` 12.

### AC-3 Title fallback
Given an entry whose `#EXTINF` has no `tvg-name` (or an empty one) and ends with `,Channel Title`
When the playlist is parsed
Then the channel `name` is "Channel Title".

### AC-4 Comma inside a quoted attribute
Given `group-title="Kids, Family",Cartoon Network`
When the playlist is parsed
Then `group` is "Kids, Family" and `name` is "Cartoon Network".

### AC-5 Empty tvg-id is not an EPG id
Given an entry with `tvg-id=""`
When the playlist is parsed
Then `epgID` is nil.

### AC-6 EXTGRP applies when no group-title
Given `#EXTGRP:News` between an `#EXTINF` without `group-title` and its URL, followed by a second `#EXTINF` without `group-title` and its URL
When the playlist is parsed
Then the first channel `group` is "News", and after that channel is emitted the pending EXTGRP value is cleared, so a following entry without `group-title` has `group` nil.

### AC-7 group-title wins over EXTGRP
Given `#EXTGRP:News` between an `#EXTINF` with `group-title="Sport"` and its URL
When the playlist is parsed
Then the channel `group` is "Sport".

### AC-8 Catch-up flags
Given `catchup="default" catchup-days="7"`
When the playlist is parsed
Then `hasCatchup` is true and `catchupDays` is 7.

### AC-9 Stable and unique ids
Given the same playlist text parsed twice
When the ids are compared
Then they are identical between runs and unique within one run, including two entries with the same `tvg-id` but different URLs.

### AC-10 Unknown directives are ignored
Given an `#EXTVLCOPT:http-user-agent=Foo` line between an `#EXTINF` and its URL
When the playlist is parsed
Then the channel is still produced with the URL that follows.

### AC-11 Orphan URL lines are skipped
Given a URL line with no preceding `#EXTINF`, followed by a valid `#EXTINF` and URL pair
When the playlist is parsed
Then the orphan line produces no channel and the following pair still produces one.

### AC-12 Empty input
Given an empty string or a string with only a header
When the playlist is parsed
Then the result has zero channels and zero `epgURLs`.

### AC-13 Group list preserves first-seen order
Given channels in groups "B", "A", "B", "C"
When `Playlist.groups` is read
Then it is `["B", "A", "C"]`.

### AC-14 Large playlists stay fast
Given a generated playlist of 50,000 entries
When parsed in a debug build on the reference machine recorded in the test
Then parsing completes within 5 seconds. This is a benchmark, excluded from the default `swift test` run and not CI-gated.

### AC-15 Catch-up disabled explicitly
Given `catchup="0"`
When the playlist is parsed
Then `hasCatchup` is false.

### AC-16 Legacy tvg-rec
Given only `tvg-rec="3"` and no `catchup` or `catchup-days`
When the playlist is parsed
Then `hasCatchup` is true and `catchupDays` is 3.

## Edge cases and failure modes

- Windows line endings (`\r\n`): the trailing `\r` must not become part of a URL or title.
- Two entries with identical `tvg-id` and identical URL produce the same id; they are not deduplicated here (out of scope) and will collide in `Identifiable` lists.
- Fallback ids (no `tvg-id`) are positional: `m3u#<url>#<n>`. They are stable only for byte-identical input; when a provider reorders or inserts entries, every later entry without `tvg-id` gets a new id. Spec 0005 must not rely on these.
- Catch-up precedence: `catchup` wins over `tvg-rec` for the flag, `catchup-days` wins over `tvg-rec` for the days. `catchup="0" tvg-rec="3"` gives `hasCatchup` false and `catchupDays` 3. `tvg-rec="0"` gives false and 0. `catchup="default"` alone gives true and nil.
- Any non-empty, non-`#` line after an `#EXTINF` is taken as the stream URL. `URL(string:)` percent-encodes spaces and other invalid characters rather than rejecting the line, so free text becomes a channel with a relative URL. No scheme validation is done at parse time.
- An `#EXTGRP` whose entry is never emitted (orphan or missing URL) is not cleared and applies to the next entry that is. `#EXTGRP` placed before the `#EXTINF` is also honoured.
- An `#EXTINF` without a comma yields a channel with empty name, no attributes and a positional id, because the attribute block ends at the first unquoted comma.
- Two consecutive `#EXTINF` lines silently drop the first.
- An entry with neither `tvg-name` nor a title yields `name == ""` and is not skipped.
- A `tvg-chno` that is not an integer yields `number` nil rather than failing the entry.
- A `url-tvg` entry is dropped only if `URL(string:)` returns nil; in practice Foundation percent-encodes invalid characters, so junk entries survive as relative URLs.

## Test plan

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | `M3UParserTests.headerEPGURLs` |
| AC-2 | core | `M3UParserTests.standardAttributes` |
| AC-3 | core | `M3UParserTests.titleFallback` |
| AC-4 | core | `M3UParserTests.commaInsideQuotedAttribute` |
| AC-5 | core | `M3UParserTests.emptyTvgID` |
| AC-6 | core | `M3UParserTests.extgrpAppliesOnce` |
| AC-7 | core | `M3UParserTests.groupTitleWinsOverExtgrp` |
| AC-8 | core | `M3UParserTests.catchupFlags` |
| AC-9 | core | `M3UParserTests.stableUniqueIDs` |
| AC-10 | core | `M3UParserTests.unknownDirectivesIgnored` |
| AC-11 | core | `M3UParserTests.orphanURLSkipped` |
| AC-12 | core | `M3UParserTests.emptyInput` (empty string and header only) |
| AC-13 | core | `M3UParserTests.groupOrder` |
| AC-14 | core (benchmark, not CI-gated) | `M3UParserTests.largePlaylistBenchmark`, runs only with `ANTENNA_BENCHMARK=1`; 1.2 s on an Apple M1 |
| AC-15 | core | `M3UParserTests.catchupDisabled` |
| AC-16 | core | `M3UParserTests.legacyTvgRec` |

## Open questions

- Should `#EXTVLCOPT` user-agent and referrer be honoured when fetching the stream? Many providers require it. Needs its own spec and a playback-engine hook.
- Should duplicate URLs be collapsed at parse time or in the app layer?
