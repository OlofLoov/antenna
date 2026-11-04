# 0002. XMLTV guide parsing

- Status: Implemented
- Date: 2026-11-03
- Depends on ADRs: 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. Every criterion has a test
  citing it since the retroactive test pass.

## Problem

Guide data arrives as XMLTV files that are routinely 20 to 100 MB. Holding one
as a DOM on an Apple TV is not an option. The app needs programmes and
channel display names extracted in one event-driven pass, tolerant of the
timestamp forms providers use, and strict about dropping entries it cannot
place on a timeline.

## Scope

In:
- `<channel id>` with its first `<display-name>`.
- `<programme channel start stop>` with `title`, `sub-title`, `desc`,
  `category` and `icon src`.
- Timestamps `yyyyMMddHHmmss ±HHMM` and `yyyyMMddHHmmss` (treated as UTC).
- Event-driven parse of an in-memory `Data` via `XMLParser`. No DOM tree is
  built, but the input bytes and the full `Result` are held in memory.

Out (explicitly):
- Downloading the file or decompressing `.gz` (future guide spec).
- Matching programmes to channels (`Programme.channelID` to `Channel.epgID`).
- Storing or caching programmes.
- Language selection among multiple `<title lang>` elements.
- `episode-num`, `credits`, `rating`, `date`, multiple categories, channel icons.
- Recovering a partial guide from a document with a well-formedness error.
- Parsing from a file URL or `InputStream`, incremental delivery of
  programmes, and cancelling a running parse.
- Reading zone offsets in forms other than those listed under Edge cases.

## User flow

1. (Future) The app fetches an XMLTV document for a source (header `url-tvg`, explicit EPG URL, or Xtream `xmltv.php`). Today `XMLTVParser` has no caller outside tests.
2. `XMLTVParser` returns channel names keyed by XMLTV id and a flat list of programmes.
3. (Future) The guide joins programmes to channels by `epgID`.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.
Unless a criterion says otherwise, "a programme" means
`<programme channel="a" start="20261103200000" stop="20261103210000">` with the
children the criterion names.

### AC-1 Channel display names
Given `<channel id="a"><display-name>A HD</display-name><display-name>A</display-name></channel>`
When parsed
Then `channelNames["a"]` is "A HD".

### AC-1b Empty first display-name wins
Given `<channel id="a"><display-name></display-name><display-name>A</display-name></channel>`
When parsed
Then `channelNames["a"]` is "".

### AC-2 Programme fields
Given the first programme of `Tests/AntennaCoreTests/Fixtures/sample.xmltv`
When parsed
Then it equals `Programme(channelID: "SkySportsF1.uk", start: 2026-11-03T18:00:00Z, stop: 2026-11-03T20:00:00Z, title: "Grand Prix Live", subtitle: "São Paulo", summary: "Lights out.", category: "Sport", iconURL: http://img/gp.jpg)`.

### AC-3 Absent optional fields are nil
Given a programme whose only child is `<title>T</title>`
When parsed
Then `subtitle`, `summary`, `category` and `iconURL` are nil.

### AC-3b Whitespace-only text is nil
Given a programme with `<title>T</title><desc>  </desc>`
When parsed
Then `summary` is nil.

### AC-4 Timestamp with zone offset
Given a programme with `start="20261103200000 +0100" stop="20261103210000 +0100"`
When parsed
Then its (`start`, `stop`) is (2026-11-03T19:00:00Z, 2026-11-03T20:00:00Z).

### AC-4b Negative zone offset
Given a programme with `start="20261103200000 -0500" stop="20261103210000 -0500"`
When parsed
Then its (`start`, `stop`) is (2026-11-04T01:00:00Z, 2026-11-04T02:00:00Z).

### AC-5 Timestamp without zone is UTC
Given a programme with `start="20261103200000" stop="20261103210000"`
When parsed
Then its (`start`, `stop`) is (2026-11-03T20:00:00Z, 2026-11-03T21:00:00Z).

### AC-6 Invalid intervals are dropped
Given a programme titled "Bad" with the attributes of one case below, followed
by a programme titled "Good" on channel "a" from 21:00 to 22:00
When parsed
Then `programmes.map(\.title)` is ["Good"].

- AC-6a: `stop` before `start`.
- AC-6b: `stop` equal to `start`.
- AC-6c: no `start`.
- AC-6d: no `stop`.
- AC-6e: no `channel`.
- AC-6f: `start="2026XX03200000"`, which does not parse.

### AC-7 Malformed XML throws
Given `<tv><programme channel="a" start="20261103200000" stop="20261103210000"><title>T</title></tv>` (unclosed `programme`)
When parsed
Then `parse` throws.

### AC-7b Non-XML data throws
Given empty `Data`, or gzip bytes passed without decompression
When parsed
Then `parse` throws.

### AC-8 First repeated title wins
Given a programme with `<title lang="en">A</title><title lang="sv">B</title>`
When parsed
Then `title` is "A".

### AC-8b Empty first element is skipped
Given a programme with `<title></title><title>T</title>`, `<sub-title> </sub-title><sub-title>S</sub-title>`, `<desc></desc><desc>D</desc>` and `<category/><category>C</category>`
When parsed
Then (`title`, `subtitle`, `summary`, `category`) is ("T", "S", "D", "C").

### AC-9 Channel icons are not attributed to programmes
Given a `<channel>` element containing `<icon src>`, followed by a programme without an icon
When parsed
Then the programme `iconURL` is nil.

### AC-10 Airing check
Given a programme from 2026-11-03T20:00:00Z to 21:00:00Z
When `isAiring(at:)` is asked for 20:00Z, 20:30Z and 21:00Z
Then it returns true, true and false. One parameterised test, three rows.

### AC-11 Large documents parse in bounded time
Given a generated document of 100,000 programmes across 500 channels, each with `title`, `desc` and `category`
When parsed with `ANTENNA_BENCHMARK` set
Then `programmes.count` is 100,000 and the parse takes under 20 seconds on macOS.

### AC-12 Programmes keep document order
Given two programmes on channel "a", both 20:00 to 21:00, titled "T1" then "T2"
When parsed
Then `programmes.map(\.title)` is ["T1", "T2"].

### AC-13 CDATA text is read
Given a programme with `<title><![CDATA[A & B]]></title><desc><![CDATA[D]]></desc>`
When parsed
Then (`title`, `summary`) is ("A & B", "D").

## Edge cases and failure modes

- Whitespace and newlines inside text elements are trimmed.
- An empty first element is skipped in favour of a later non-empty one (AC-8b).
  Applies to title, sub-title, desc and category. `<display-name>` differs:
  the first one wins even if empty (AC-1b).
- Namespaced documents are parsed with namespaces disabled; prefixed element names are not matched.
- Timestamps: `yyyyMMddHHmmss ±HHMM` with one space is read with its offset,
  and `+01:00` after a space is also accepted by the formatter. Any other
  suffix (`UTC`, an offset with no space) is ignored and the first 14
  characters are read as UTC, so the time is off by the offset. A timestamp
  whose first 14 characters do not parse, including `yyyyMMddHHmm` without
  seconds, is dropped per AC-6f.
- Any well-formedness error anywhere in the document, including an unescaped
  `&` or an undeclared entity such as `&nbsp;`, throws per AC-7 and discards
  every programme already parsed.
- A well-formed document that is not XMLTV (for example `<tv/>` or an XHTML
  page) returns an empty `Result` with no error. A non-well-formed HTML page
  throws per AC-7.
- A `<programme>` with no `<title>` is kept with `title == ""`.
- `channel=""` is kept with `channelID == ""`; only a missing attribute drops the programme.
- A programme whose `channel` has no `<channel>` element is still returned.
- Duplicate and overlapping programmes are all returned (AC-12); `Programme.id`
  collides for equal channel and start (see Open questions).
- Attribute values (`channel`, `id`) are not trimmed.
- A `<channel>` without an `id` attribute is ignored; a channel without `<display-name>` is absent from `channelNames`.
- If two `<channel>` elements share an id, the first display-name across both wins.
- Text of child elements inside a text element is concatenated: `A <b>bold</b> c` gives "A bold c".
- With several `<icon>` in one programme the last `src` wins; a `src` that `URL(string:)` rejects gives `iconURL == nil`.
- Peak memory for a 50 MB file and parse time on tvOS cannot be asserted in CI; check on device when the guide ships.

## Test plan

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | `XMLTVParserTests.channelDisplayNames` |
| AC-1b | core | `XMLTVParserTests.emptyDisplayNameWins` |
| AC-2 | core | `XMLTVParserTests.programmeFields` |
| AC-3 | core | `XMLTVParserTests.absentOptionalFields` |
| AC-3b | core | `XMLTVParserTests.whitespaceDescIsNil` |
| AC-4 | core | `XMLTVParserTests.timestampWithOffset` |
| AC-4b | core | `XMLTVParserTests.timestampWithNegativeOffset` |
| AC-5 | core | `XMLTVParserTests.timestampWithoutZone`; CI runners are on UTC, so it only catches a lost UTC zone on the no-offset formatter when run on a host in another zone |
| AC-6 | core (parameterised over cases a to f) | `XMLTVParserTests.invalidIntervalsDropped` |
| AC-7 | core | `XMLTVParserTests.malformedThrows` |
| AC-7b | core | `XMLTVParserTests.nonXMLDataThrows` |
| AC-8 | core | `XMLTVParserTests.firstTitleWins` |
| AC-8b | core | `XMLTVParserTests.emptyFirstElementSkipped` |
| AC-9 | core | `XMLTVParserTests.channelIconIgnored`; checks the combined effect of the icon guard and the per-programme reset, each of which alone keeps it passing |
| AC-10 | core (parameterised, three rows) | `XMLTVParserTests.airingCheck` |
| AC-11 | core (benchmark, not CI-gated) | `XMLTVParserTests.largeGuideBenchmark`, runs only with `ANTENNA_BENCHMARK=1`; about 14 s on an Apple M1, in both debug and release because the time is spent inside `XMLParser` |
| AC-12 | core | `XMLTVParserTests.documentOrder` |
| AC-13 | core | `XMLTVParserTests.cdataText` |

## Open questions

- Wrap the `XMLParser` error in `XMLTVError` so callers get a typed error as conventions require.
- Language preference for repeated elements: device locale or first in file?
- Should `Programme.id` include `stop` to avoid collisions when a provider emits two programmes with the same start on one channel?
- Should an empty first `<display-name>` give way to a later non-empty one, as programme text elements do? AC-1b records today's behaviour.
