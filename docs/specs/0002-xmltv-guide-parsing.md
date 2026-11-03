# 0002. XMLTV guide parsing

- Status: Draft
- Date: 2026-11-03
- Depends on ADRs: 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. Tests that do not yet cite a
  criterion are marked TBD in the test plan.

## Problem

Guide data arrives as XMLTV files that are routinely 20 to 100 MB. Holding one
as a DOM on an Apple TV is not an option. The app needs programmes and
channel display names extracted in one streaming pass, tolerant of the two
timestamp forms providers use, and strict about dropping entries it cannot
place on a timeline.

## Scope

In:
- `<channel id>` with its first `<display-name>`.
- `<programme channel start stop>` with `title`, `sub-title`, `desc`,
  `category` and `icon src`.
- Timestamps `yyyyMMddHHmmss Z` and `yyyyMMddHHmmss` (treated as UTC).
- Streaming parse via `XMLParser`; no DOM.

Out (explicitly):
- Downloading the file or decompressing `.gz` (future guide spec).
- Matching programmes to channels (`Programme.channelID` to `Channel.epgID`).
- Storing or caching programmes.
- Language selection among multiple `<title lang>` elements.
- `episode-num`, `credits`, `rating`, `date`, multiple categories, channel icons.

## User flow

1. (Future) The app fetches an XMLTV document for a source (header `url-tvg`, explicit EPG URL, or Xtream `xmltv.php`). Today `XMLTVParser` has no caller outside tests.
2. `XMLTVParser` returns channel names keyed by XMLTV id and a flat list of programmes.
3. (Future) The guide joins programmes to channels by `epgID`.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Channel display names
Given `<channel id="a"><display-name>A HD</display-name><display-name>A</display-name></channel>`
When parsed
Then `channelNames["a"]` is "A HD".

### AC-2 Programme fields
Given a programme with title, sub-title, desc, category and `<icon src="http://i/x.jpg"/>`
When parsed
Then `title` is the `<title>` text, `subtitle` the `<sub-title>` text, `summary` the `<desc>` text, `category` the `<category>` text, `iconURL` is http://i/x.jpg and `channelID` equals the `channel` attribute.

### AC-3 Empty optional fields are nil
Given a programme with only `title`
When parsed
Then `subtitle`, `summary`, `category` and `iconURL` are nil.

### AC-4 Timestamp with zone offset
Given `start="20261103200000 +0100"`
When parsed
Then `start` equals 2026-11-03T19:00:00Z.

### AC-5 Timestamp without zone is UTC
Given `start="20261103200000"`
When parsed
Then `start` equals 2026-11-03T20:00:00Z.

### AC-6 Invalid intervals are dropped
Given a programme whose `stop` is before or equal to `start`, or that lacks `start`, `stop` or `channel`
When parsed
Then it is not in `programmes` and the remaining programmes are still returned.

### AC-7 Malformed XML throws
Given a document that is not well-formed XML
When parsed
Then `parse` throws (the underlying `XMLParser` error, or `XMLTVError.malformed` if none is reported) and no `Result` is returned.

### AC-8 First non-empty repeated text element wins
Given a programme with `<title lang="en">A</title><title lang="sv">B</title>`
When parsed
Then `title` is the first non-empty `<title>` text, "A".

### AC-9 Channel icons are not attributed to programmes
Given a `<channel>` element containing `<icon src>`, followed by a programme without an icon
When parsed
Then the programme `iconURL` is nil.

### AC-10 Airing check
Given a programme from 20:00 to 21:00
When `isAiring(at:)` is asked for 20:00, 20:30 and 21:00
Then it returns true, true and false.

### AC-11 Large documents parse in bounded time
Given a generated document with 100,000 programmes
When parsed on the reference machine recorded in the test
Then parsing completes within 20 seconds. This is a benchmark, excluded from the default `swift test` run and not CI-gated. Measured about 14 seconds in both debug and release on an Apple Silicon Mac; build mode makes no difference because the time is spent inside `XMLParser`.

## Edge cases and failure modes

- Whitespace and newlines inside text elements are trimmed.
- An empty first element is skipped in favour of a later non-empty one. Applies to title, sub-title, desc and category. `<display-name>` differs: the first one wins even if empty.
- Namespaced documents are parsed with namespaces disabled; prefixed element names are not matched.
- A timestamp whose first 14 characters do not parse as `yyyyMMddHHmmss` is dropped by AC-6. Anything after the 14th character that is not a recognised zone offset is ignored and the time is read as UTC.
- Empty `Data` throws via the AC-7 path.
- A well-formed document that is not XMLTV (for example an HTML page) returns an empty `Result` with no error.
- A `<programme>` with no `<title>` is kept with `title == ""`.
- A `<channel>` without an `id` attribute is ignored; a channel without `<display-name>` is absent from `channelNames`.
- Peak memory for a 50 MB file cannot be asserted in CI; check on device when the guide ships.

## Test plan

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | `XMLTVParserTests.parsesProgrammesAndDropsInvalid` |
| AC-2 | core | `XMLTVParserTests.parsesProgrammesAndDropsInvalid` |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core (parameterised over the four cases) | `XMLTVParserTests.parsesProgrammesAndDropsInvalid` (stop before start only; missing attributes TBD) |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9 | core | TBD |
| AC-10 | core | `XMLTVParserTests.parsesProgrammesAndDropsInvalid` (mid-interval only; boundaries TBD) |
| AC-11 | core (benchmark, not CI-gated) | TBD |

## Open questions

- Wrap the `XMLParser` error in `XMLTVError` so callers get a typed error as conventions require.
- Language preference for repeated elements: device locale or first in file?
- Should `Programme.id` include `stop` to avoid collisions when a provider emits two programmes with the same start on one channel?
