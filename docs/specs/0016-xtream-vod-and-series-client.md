# 0016. Xtream VOD and series client

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore)
- Builds on spec 0003 (Xtream live client, decoding rules). Extends `XtreamClient` with the VOD and series endpoints that 0003 listed as out of scope. Supersedes 0003/AC-7 (401 and 403 become `unauthorized`, AC-11), 0003/AC-8 (`DecodingError` becomes `XtreamError.decoding(path:)`, AC-4a and AC-4b), 0003's `URLError` passthrough (AC-10) and 0003/AC-1, AC-4 and AC-5 for credential encoding (AC-1 and AC-7 of this spec apply to every URL the client builds). 0003's tests for those criteria assert the new behaviour. Resolves 0003's `user_info.auth` question (AC-11). Resolves 0003's row-skipping question for VOD, series and episode lists only (AC-4, AC-6d); `liveStreams()` keeps 0003's `[XtreamLiveStream]` and fails whole on a row lacking `name` or `stream_id`, as 0003's edge case states. 0003 edge cases on `auth: 0` and on broken rows are superseded by AC-11 and AC-4 respectively. Specs 0006 and 0011 to 0014 are in open PRs, not in this tree; they consume this spec and do not block it.
- Type names: `XtreamClient.XtreamError` and `XtreamClient.DecodedList` are nested in `XtreamClient` as 0003's error is; this spec writes them without the prefix. `VODItem`, `VODInfo`, `Series`, `SeriesInfo`, `Episode` and `XtreamTitleID` are top-level types in AntennaCore like `XtreamLiveStream`.

## Design

Boards: none, no UI. Rendered by 0011 and 0012.
Design rules that apply: none.

## Problem

Xtream providers expose movies and series through five more `player_api.php` actions. Spec 0011 needs categories, lists, per-title info, episodes and playable URLs, with stable ids and tolerant decoding, and none of it exists.

## Scope

In:
- `vodCategories()`, `vodStreams(categoryID:)`, `vodInfo(streamID:)`, `seriesCategories()`, `series(categoryID:)`, `seriesInfo(seriesID:)`. Categories reuse 0003's `XtreamCategory`.
- Decoding exposed as pure static functions on `XtreamClient` taking `Data` and the server host: `decodeVODList(_:host:) -> DecodedList<VODItem>`, `decodeSeriesList(_:host:) -> DecodedList<Series>`, `decodeVODInfo(_:host:) -> VODInfo`, `decodeSeriesInfo(_:host:) -> SeriesInfo`. The six calls compose request plus decode. AC-2 to AC-6e except AC-4b, AC-12 and AC-13 use the decode functions; AC-1, AC-4b, AC-10, AC-10a and AC-11 use a `URLProtocol` stub.
- Models: `VODItem`, `VODInfo`, `Series`, `SeriesInfo` (with `skippedEpisodes`), `Episode`, `DecodedList<T>` (`items`, `skipped`) and `XtreamTitleID` (AC-13a). `VODItem`, `VODInfo`, `Series`, `SeriesInfo`, `Episode` and `DecodedList<T: Sendable & Hashable>` are `Sendable` and `Hashable`; `VODItem`, `Series` and `Episode` are `Identifiable` with `id: String`.
- `XtreamAccountInfo.UserInfo` gains `auth: Int?`, decoded loosely per 0003/AC-2.
- Raw ids (`streamID`, `seriesID`, `episodeID`: `Int`) for requests and URLs; title ids `xtream#<host>#vod#<stream_id>`, `xtream#<host>#series#<series_id>`, `xtream#<host>#episode#<episode_id>` for storage and cross-device identity, and parsing a title id back to its kind and raw id.
- Playable URL builders for movies and episodes.
- Tolerant decoding: loose types per 0003, row skipping for broken and duplicate rows in VOD, series and episode lists, no trap on any input.
- `XtreamError.unauthorized`, `XtreamError.transport(URLError.Code)` and `XtreamError.decoding(path: String)` on every `XtreamClient` call, including 0003's. `XtreamError` stays `Sendable`; `decoding` stores the joined coding path only.
- Error and client values carry no credentials or URLs.

Out (explicitly):
- Any UI, caching, images.
- M3U-based VOD.
- Catch-up and timeshift URLs.
- Stalker.
- Interpreting `user_info.status` ("Disabled", "Expired"), as in 0003.
- How callers render cancellation; 0006 and 0011 own that.
- A logger. AntennaCore has none; the app layer applies 0014/AC-15's redaction when it logs.

## User flow

None.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Request shape
Given credentials for server H with username `alice-7f3e` and password `a&b/c+d`
When each of the six calls, `liveCategories()`, `liveStreams(categoryID:)` and `accountInfo()` runs, parameterised, and `xmltvURL()` is built
Then each call issues exactly one GET to `<server>/player_api.php` with query items in the order `username`, `password`, `action`, then the id item; `action` is one of `get_vod_categories`, `get_vod_streams`, `get_vod_info`, `get_series_categories`, `get_series`, `get_series_info`, `get_live_categories` or `get_live_streams`, and the id item is `category_id`, `vod_id` or `series_id`, absent when no id is given. `accountInfo()` has no `action` item. The query is `username=alice-7f3e&password=a%26b%2Fc%2Bd&action=<action>[&<id item>]`: every byte outside the RFC 3986 unreserved set (ALPHA, DIGIT, `-`, `.`, `_`, `~`) is percent-encoded in both values. `xmltvURL()` targets `<server>/xmltv.php` with `username` and `password` only, encoded the same way.

### AC-2 VOD item fields
Given a `get_vod_streams` row with `stream_id` 55, `name` "Dune", `stream_icon` "http://h/p.jpg", `added` "1730600000", `rating` "7.4", `container_extension` "mkv", `category_id` "12"
When decoded with host H
Then `VODItem` has `streamID` 55, `id` "xtream#H#vod#55", `name` "Dune", `posterURL` `http://h/p.jpg`, `added` `Date(timeIntervalSince1970: 1730600000)`, `rating` 7.4, `containerExtension` "mkv", `categoryID` "12".

### AC-2a Loose forms
Given the AC-2 row with `stream_id` and `category_id` each as number or string, and `added` and `rating` each as a JSON number, a numeric string, "N/A", "" and null
When decoded, parameterised
Then `streamID` and `categoryID` equal the AC-2 values in every form (0003/AC-2, AC-3); `added` and `rating` equal the AC-2 values for the number and numeric-string forms and are nil for the others; `rating` 0 or "0" is nil.

### AC-2b URL fields
Given `stream_icon` values `http://h/p.jpg`, `https://h/p.jpg`, `ftp://h/p`, `//h/p`, `p.jpg`, `""`, `http://`
When decoded
Then only the first two yield a non-nil `posterURL`: a URL field is nil unless the value parses to a URL whose scheme is `http` or `https` and whose host is non-empty. The same rule applies to `cover` (AC-6) and to each `backdrop_path` entry (AC-5).

### AC-3 Unparseable added
Given `added` values "0", "", null, "abc", "nan", "inf", "-inf", "1e400" and a number outside `Int` range
When decoded
Then `added` is nil for each and decoding never traps.

### AC-4 Broken rows are skipped
Given a list response where one element is not a JSON object, one row lacks `stream_id`, one lacks `name`, one has `stream_id` "abc", one has `stream_id` "1e400" and one repeats an earlier row's `stream_id`
When decoded
Then `DecodedList<VODItem>.items` holds the other rows in server order and `skipped` is 6. A row is skipped and counted only when it is not a JSON object, lacks `stream_id` (`series_id` on series lists) or `name`, `stream_id` (`series_id`) does not decode to `Int` (including "nan", "inf", "-inf", "1e400" and out-of-range numbers, which never trap), or its `id` equals an earlier row's `id` in the same response. Failure of any other field yields nil for that field and keeps the row. Skipping applies to VOD, series and episode lists only; `liveStreams()` keeps 0003's behaviour and fails whole on a broken row.

### AC-4a Non-array list body
Given a body that is a JSON object other than `{}`, a string, `true`, or not JSON at all (an HTML login page)
When decoded
Then `XtreamError.decoding(path:)` is thrown; `path` is the coding path as a dotted string (for example "[3].stream_id" for a nested failure), and `path` is "" for the root cases and the HTML body; `String(reflecting:)` of the error does not contain the body, nor any substring of the body eight bytes or longer.

### AC-4b Category lists fail whole
Given a category list of three rows where the second lacks `category_name`
When `vodCategories()` or `seriesCategories()` decodes it
Then `XtreamError.decoding(path: "[1].category_name")` is thrown. This replaces 0003/AC-8's `DecodingError` for every list the client decodes. No `XtreamClient` call lets `DecodingError` escape; `accountInfo()` on the HTML body of AC-4a throws `XtreamError.decoding(path: "")`.

### AC-5 VOD info
Given a `get_vod_info` response with `info.plot` "A desert", `info.releasedate` "2024-03-01", `info.duration` "02:08:00", `info.duration_secs` 7680, `info.genre` "Sci-Fi", `info.age` "15", `info.backdrop_path` ["http://h/b1.jpg", "p.jpg"], `movie_data.container_extension` "mkv"
When decoded
Then `VODInfo` has `plot` "A desert", `year` 2024, `duration: TimeInterval?` 7680, `genre` "Sci-Fi", `ageRating` "15", `backdropURLs` [`http://h/b1.jpg`], `containerExtension` "mkv". Duration rule: `duration_secs` when it is a number or numeric string greater than 0, else `duration` parsed from `hh:mm:ss` or `mm:ss`, else nil; a parsed value of 0 is nil; with `duration_secs` absent the AC-5 body yields 7680 from "02:08:00". `info` absent, `{}` or `[]` decodes with every optional field nil; `movie_data` absent yields `containerExtension` nil; `backdrop_path` accepts an array of strings or one string and keeps only entries that pass AC-2b; `year` is taken from the first of `releasedate`, `release_date`, `releaseDate` that is a non-empty string, and is nil when that value does not start with four digits or is "0000"; `age` accepts a number or string.

### AC-6 Series row fields
Given a `get_series` row with `series_id` 7, `name` "Dark", `cover` "http://h/c.jpg", `last_modified` "1730600000", `category_id` "3"
When decoded with host H
Then `Series` has `seriesID` 7, `id` "xtream#H#series#7", `name` "Dark", `posterURL` `http://h/c.jpg` (AC-2b rule on `cover`), `lastModified` `Date(timeIntervalSince1970: 1730600000)` (AC-2a and AC-3 rules as for `added`), `categoryID` "3"; `series_id` and `category_id` accept number or string.

### AC-6a Episodes flatten
Given a `get_series_info` whose `episodes` is a dictionary keyed by season ("1", "2", "10") or an array, each episode with `id`, `episode_num`, optional `season`, `title`, `container_extension`, `info.duration_secs` and optional `info.duration`
When decoded with host H
Then `SeriesInfo` has `plot`, `year`, `genre`, `ageRating`, `backdropURLs` by the AC-5 rules from `info`, and `episodes` flat, each with `episodeID`, `id` "xtream#H#episode#<id>", `season: Int?` (the episode's own `season` field, else the dictionary key when it parses as `Int`, else nil), `number: Int?` (`episode_num`, nil when absent or not numeric), `title`, `containerExtension`, and `duration: TimeInterval?` by the AC-5 duration rule over `info.duration_secs` and `info.duration`; `id`, `season` and `episode_num` accept strings or numbers. The `seasons` array in the response is ignored.

### AC-6b Episode order
Given episodes with seasons nil, 1, 2 and 10 and numbers nil, 1, 2 and 10 in shuffled server order, plus two episodes with equal `season` and `number`
When decoded
Then `episodes` is sorted by `season` then `number`, numerically, nil before any value in both; ties keep server order (stable sort).

### AC-6c Season count
Given episodes under dictionary key "2" where one carries `season` 3 and the others none
When decoded
Then `seasonCount` is the number of distinct non-nil `Episode.season` values after resolution (2 here), not the number of dictionary keys.

### AC-6d Episode skipping and title fallback
Given an episode list where one element is not a JSON object, one lacks `id`, one has `id` "abc", one has `title` "", one lacks `title` and one repeats an earlier episode's `id`
When decoded
Then the first three and the duplicate are skipped and `SeriesInfo.skippedEpisodes` is 4; the first occurrence wins; the two title cases have `title` "Episode <number>", or "Episode" when `number` is nil.

### AC-6e Empty episodes shapes
Given `episodes` absent, `{}`, `[]` or `false`
When decoded
Then `episodes` is empty, `seasonCount` is 0 and `skippedEpisodes` is 0.

### AC-7 Playable URLs
Given raw `streamID` 55 with extension "mkv" and raw `episodeID` 901 with extension "mp4" on server `http://h:8080` with user u and password p
When `movieURL(streamID:extension:)` and `episodeURL(episodeID:extension:)` run
Then they are `http://h:8080/movie/u/p/55.mkv` and `http://h:8080/series/u/p/901.mp4`. `extension` is used after trimming whitespace and one leading dot; nil or empty falls back to "mp4". A server URL with a path keeps it: `http://h/xtream` yields `http://h/xtream/movie/u/p/55.mkv`. For password `a&b/c+d` the movie URL is `http://h:8080/movie/u/a%26b%2Fc%2Bd/55.mkv`, with the same unreserved-set rule as AC-1; `streamURL(for:)` and `xmltvURL()` from 0003 produce the same segments and query.

### AC-8 Errors and client values never carry credentials
Given a client for server `http://panel.example:8080` with username `alice-7f3e` and password `s3cr3t-9b2a`
When `String(describing:)` and `String(reflecting:)` are read for `XtreamCredentials`, `XtreamClient`, `XtreamError.badStatus(500)`, `.unauthorized`, `.transport(.notConnectedToInternet)` and `.decoding(path: "[3].stream_id")`, and `(error as NSError).userInfo` for each of those errors
Then none of them contains `alice-7f3e`, `s3cr3t-9b2a`, `:8080`, `player_api.php`, `/movie/`, `/series/` or `/live/`; `String(describing:)` of `XtreamCredentials` and of `XtreamClient` equals `panel.example`. Both types conform to `CustomStringConvertible` and `CustomDebugStringConvertible`.

### AC-9 Decoding is fast
Given a `get_vod_streams` body of 50 000 rows generated in the test from a 20-row template
When `decodeVODList(_:host:)` runs over the `Data`
Then it completes in under 500 ms in a debug `swift test` run on the reference machine recorded in a comment on the test (the same baseline as 0013/AC-14). Benchmark, not CI-gated, excluded from the default run with `.enabled(if: ProcessInfo.processInfo.environment["ANTENNA_BENCHMARKS"] == "1")`. This defines the mechanism 0001/AC-14 and 0013/AC-14 refer to.

### AC-10 Transport failures carry no URL
Given the session throws `URLError` with code c, for c in `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`, `.timedOut`, `.cannotFindHost`, `.secureConnectionFailed`
When any `XtreamClient` call runs, parameterised over the calls and the codes
Then it throws `XtreamError.transport(c)`, and `String(reflecting:)` and `(error as NSError).userInfo` of the thrown error contain neither the server URL nor the credentials (no `NSURLErrorFailingURLStringErrorKey`).

### AC-10a Cancellation
Given the calling task is cancelled while the request is in flight
When any `XtreamClient` call runs
Then the call throws `CancellationError`, not `XtreamError`.

### AC-11 Unauthorised
Given the server answers 401 or 403, or 200 with a body that is a JSON object whose `user_info.auth` decodes to 0 as a number or numeric string
When any `player_api.php` call runs (`accountInfo()`, `liveCategories()`, `liveStreams()` and the six calls of this spec)
Then it throws `XtreamError.unauthorized`. Other non-2xx statuses throw `badStatus(n)`, and a response that is not `HTTPURLResponse` throws `badStatus(-1)` as in 0003. The `auth` probe runs only when the body's first non-whitespace byte is `{`, before any list or info decoding, so it takes precedence over AC-4a; array bodies are never probed. The probe is tested through `decodeVODList` on `{"user_info":{"auth":0}}` and `{"user_info":{"auth":"0"}}`. `UserInfo.auth` is nil when the key is absent, null or does not decode to `Int`, and otherwise equals the decoded value; `{"user_info":{"auth":1}}` yields `auth == 1` and `{"user_info":{"auth":"yes"}}` returns normally with `auth == nil`.

### AC-12 Empty list shapes
Given a list endpoint answering `[]`, `{}`, `false` or `null`, and `vodInfo` or `seriesInfo` answering the same
When decoded
Then the list result has zero `items` and zero `skipped`; the info result has every optional field nil and, for `SeriesInfo`, zero episodes, `seasonCount` 0 and `skippedEpisodes` 0. Any other info body that is not a JSON object throws `XtreamError.decoding(path:)`.

### AC-13 Ids are stable
Given the same row decoded from two responses, and a live stream, a movie, a series and an episode sharing numeric id 55 on host h
When ids are compared
Then equal rows give equal ids; the four kinds give `xtream#h#55`, `xtream#h#vod#55`, `xtream#h#series#55`, `xtream#h#episode#55`; ids ignore scheme and port as 0003/AC-10, so two panels on one host with different ports collide (0003 edge case, accepted).

### AC-13a Title id round trip
Given the strings `xtream#h#55`, `xtream#h#vod#55`, `xtream#h#series#55`, `xtream#h#episode#55`, `xtream#h#vod#abc`, `xtream#h#movie#55`, `xtream##55` and `m3u#x`
When `XtreamTitleID(parsing:)` runs
Then the first four yield `host` "h", `kind` `.live`, `.vod`, `.series`, `.episode` and `rawID` 55; the last four yield nil, `xtream##55` because its host is empty.

## Edge cases and failure modes

- `category_id` absent on a row: `categoryID` nil; 0011 lists the item only in Recently added and All.
- Duplicate rows: a repeated `id` within one response is skipped and counted (AC-4), so 0011's `ForEach` over `id` never sees a duplicate. The first occurrence wins.
- Ids are never built from `streamURL`-like fields. `direct_source` is ignored in this spec and URLs are always built per AC-7. Whether some providers require `direct_source` is an open question for a follow-up spec, not this one.
- Credentials with reserved characters (`&`, `#`, `/`, `?`, `+`, `%`, space): `URLQueryItem` leaves `+` literal, `appending(path:)` splits on `/` and `appending(component:)` encodes it, so the implementation percent-encodes explicitly (AC-1, AC-7).
- Paging: `vodStreams(categoryID: nil)` and `series(categoryID: nil)` stay available because 0006/AC-10a counts movies and series from them.

## Test plan

Fixtures under `Tests/AntennaCoreTests/Fixtures/Xtream/` for every endpoint, including broken-row, duplicate-row, duplicate-episode, array-episodes, empty-`info`, `{}`, `false`, `null` and HTML-body variants; the 50 000-row body is generated at test time.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (`URLProtocol` stub, parameterised over the nine calls; `xmltvURL()` built directly) | TBD |
| AC-2 | core (decode function) | TBD |
| AC-2a | core (decode function, parameterised) | TBD |
| AC-2b | core (decode function, parameterised) | TBD |
| AC-3 | core (decode function, parameterised) | TBD |
| AC-4 | core (decode function) | TBD |
| AC-4a | core (decode function, parameterised, HTML body included) | TBD |
| AC-4b | core (`URLProtocol` stub: category list, `accountInfo()` on HTML) | TBD |
| AC-5 | core (decode function) | TBD |
| AC-6 | core (decode function) | TBD |
| AC-6a | core (decode function) | TBD |
| AC-6b | core (decode function) | TBD |
| AC-6c | core (decode function) | TBD |
| AC-6d | core (decode function) | TBD |
| AC-6e | core (decode function, parameterised) | TBD |
| AC-7 | core | TBD |
| AC-8 | core (parameterised) | TBD |
| AC-9 | core benchmark, `ANTENNA_BENCHMARKS=1` | TBD |
| AC-10 | core (`URLProtocol` stub throwing, parameterised) | TBD |
| AC-10a | core (`URLProtocol` stub, task cancelled) | TBD |
| AC-11 | core (`URLProtocol` stub: 401, 403, 500, non-`HTTPURLResponse`, `auth: 0`, `auth: "0"`, `auth: 1`, `auth: "yes"`) | TBD |
| AC-12 | core (decode function, parameterised) | TBD |
| AC-13 | core (decode function) | TBD |
| AC-13a | core (parameterised) | TBD |

## Open questions

- Should `vodStreams(categoryID: nil)` page through categories for providers whose unfiltered list exceeds tens of megabytes? Any resolution must keep an unfiltered count path for 0006/AC-10a.
- Do some providers require `direct_source` instead of the `/movie/` and `/series/` shape? Tracked for a follow-up spec; this spec ignores the field.
