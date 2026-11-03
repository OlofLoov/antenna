# 0016. Xtream VOD and series client

- Status: Draft (two spec-reviewer rounds; remaining findings listed in the PR)
- Date: 2026-11-03
- Depends on ADRs: 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore)
- Builds on spec 0003 (Xtream live client, decoding rules). Extends `XtreamClient` with the VOD and series endpoints that 0003 listed as out of scope. Supersedes 0003/AC-7 for status 401 and 403 on every endpoint and resolves 0003's open question on `user_info.auth` equal to 0 (AC-11). Supersedes 0003's `URLError` passthrough (AC-10).

## Design

Boards: none, no UI. Rendered by 0011 and 0012.
Design rules that apply: none.

## Problem

Xtream providers expose movies and series through five more `player_api.php` actions. Spec 0011 needs categories, lists, per-title info, episodes and playable URLs, with stable ids and tolerant decoding, and none of it exists.

## Scope

In:
- `vodCategories()`, `vodStreams(categoryID:)`, `vodInfo(streamID:)`, `seriesCategories()`, `series(categoryID:)`, `seriesInfo(seriesID:)`. Categories reuse 0003's `XtreamCategory`.
- Models: `VODItem`, `VODInfo`, `Series`, `SeriesInfo`, `Episode`, and `DecodedList<T>` (`items`, `skipped`).
- Raw ids (`streamID`, `seriesID`, `episodeID`: `Int`) for requests and URLs; title ids `xtream#<host>#vod#<stream_id>`, `xtream#<host>#series#<series_id>`, `xtream#<host>#episode#<episode_id>` for storage and cross-device identity.
- Playable URL builders for movies and episodes.
- Tolerant decoding: loose types per 0003, row skipping for broken rows in VOD and series lists.
- `XtreamError.unauthorized` and `XtreamError.transport(URLError.Code)` on every `XtreamClient` call.
- Redaction of credentials in error descriptions.

Out (explicitly):
- Any UI, caching, images.
- M3U-based VOD.
- Catch-up and timeshift URLs.
- Stalker.
- A logger. AntennaCore has none; the app layer applies 0014/AC-15's redaction when it logs.

## User flow

None.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Request shape
Given credentials for server H
When each of the six calls runs, parameterised
Then exactly one GET is issued to `<server>/player_api.php` with query items in the order `username`, `password`, `action`, then the id item; `action` is one of `get_vod_categories`, `get_vod_streams`, `get_vod_info`, `get_series_categories`, `get_series`, `get_series_info`, and the id item is `category_id`, `vod_id` or `series_id`, absent when no id is given.

### AC-2 VOD item fields
Given a `get_vod_streams` row with `stream_id`, `name`, `stream_icon`, `added` ("1730600000"), `rating` ("7.4"), `container_extension` ("mkv"), `category_id` ("12")
When decoded
Then `VODItem` has `streamID` 55-style `Int`, `id` "xtream#H#vod#<stream_id>", `name`, `posterURL` (nil when `stream_icon` is empty or not a URL), `added` as a `Date` from Unix seconds, `rating` 7.4, `containerExtension` "mkv", `categoryID` "12"; `stream_id` and `category_id` accept number or string per 0003/AC-2 and AC-3; `added` and `rating` accept a JSON number or a numeric string and any other value yields nil.

### AC-3 Unparseable added
Given `added` values "0", "", null, "abc"
When decoded
Then `added` is nil for each.

### AC-4 Broken rows are skipped
Given a list response where one row lacks `stream_id` or `name`, or has `stream_id` "abc"
When decoded
Then the call returns `DecodedList<VODItem>` with `items` holding the other rows in server order and `skipped` equal to the number of rows missing or failing to decode `stream_id` or `name` (same for `series_id` on series lists); a body that is not a JSON array and is not `{}` or `false` throws `DecodingError` as in 0003/AC-8; category lists keep 0003's whole-list failure.

### AC-5 VOD info
Given a `get_vod_info` response with `info.plot`, `info.releasedate` ("2024-03-01"), `info.duration` ("02:08:00"), `info.duration_secs`, `info.genre`, `info.age` ("15"), `info.backdrop_path` (array), `movie_data.container_extension`
When decoded
Then `VODInfo` has `plot`, `year` 2024, `duration` (`duration_secs` when present and numeric, else parsed from `hh:mm:ss` or `mm:ss`, else nil), `genre`, `ageRating` "15", `backdropURLs`, `containerExtension`; `info` given as an empty array decodes with every optional field nil; `year` is nil when `releasedate` or `release_date` does not start with four digits or is "0000".

### AC-6 Series list and info
Given `get_series` rows with `series_id`, `name`, `cover`, `last_modified`, `category_id`, and a `get_series_info` whose `episodes` is a dictionary keyed by season ("1", "2", "10") or an array, each episode with `id`, `episode_num`, optional `season`, `title`, `container_extension`, `info.duration_secs`
When decoded
Then `Series` has `seriesID`, `id` "xtream#H#series#<series_id>", `name`, `posterURL` from `cover` (nil when empty or not a URL), `lastModified` parsed as `added` is, `categoryID`; `SeriesInfo` has `plot`, `year`, `genre`, `ageRating`, `backdropURLs` by the AC-5 rules from `info`, `seasonCount` equal to the number of distinct `season` values, and `episodes` flat, each with `episodeID`, `id` "xtream#H#episode#<id>", `season` (its own field, else the integer value of the dictionary key), `number`, `title`, `containerExtension`, `duration` seconds, sorted by `season` then `number` numerically; `id`, `season` and `episode_num` accept strings or numbers.

### AC-7 Playable URLs
Given raw `streamID` 55 with extension "mkv" and raw `episodeID` 901 with extension "mp4" on server `http://h:8080` with user u and password p
When `movieURL(streamID:extension:)` and `episodeURL(episodeID:extension:)` run
Then they are `http://h:8080/movie/u/p/55.mkv` and `http://h:8080/series/u/p/901.mp4`; a missing extension falls back to "mp4".

### AC-8 Redaction
Given any `XtreamError` produced by these calls
When its description is read
Then `username` and `password` values are replaced with "…" and no server URL with credentials appears.

### AC-9 Decoding is fast
Given a `get_vod_streams` body of 50 000 rows generated in the test from a 20-row template
When decoded
Then it completes in under 500 ms in a debug `swift test` run on the reference machine named in the test (the same baseline as 0013/AC-14); benchmark, not CI-gated.

### AC-10 Transport failures carry no URL
Given the session throws `URLError` (for example `.notConnectedToInternet`)
When any `XtreamClient` call runs
Then the call throws `XtreamError.transport(URLError.Code)` whose description and `userInfo` contain neither the server URL nor the credentials, and no `URLError` escapes the client.

### AC-11 Unauthorised
Given the server answers 401 or 403, or 200 with a body whose `user_info.auth` is 0
When any `XtreamClient` call runs, including `accountInfo()` and the live endpoints
Then it throws `XtreamError.unauthorized`; other non-2xx statuses still throw `badStatus(n)`.

### AC-12 Empty list shapes
Given a list endpoint answering `[]`, `{}` or `false`
When decoded
Then the result has zero `items` and zero `skipped`.

### AC-13 Ids are stable
Given the same row decoded from two responses, and a live stream, a movie and an episode with the same numeric id on one host
When ids are compared
Then equal rows give equal ids, the three kinds give three different ids, and ids ignore scheme and port as 0003/AC-10.

## Edge cases and failure modes

- `category_id` absent on a row: `categoryID` nil; 0011 lists the item only in Recently added and All.
- `rating` "N/A": nil (AC-2 rule).
- Ids are never built from `streamURL`-like fields; `direct_source`, when present, is ignored (open question).
- Paging: the unfiltered `vodStreams(categoryID: nil)` stays available because 0006/AC-10a counts from it.

## Test plan

Fixtures under `Tests/AntennaCoreTests/Fixtures/Xtream/` for every endpoint, including broken-row, array-episodes, empty-`info`, `{}` and `false` variants; the 50 000-row body is generated at test time.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (request builder, parameterised) | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9 | core benchmark | TBD |
| AC-10 | core (stubbed session throwing) | TBD |
| AC-11 | core (stubbed 401, 403, `auth: 0`) | TBD |
| AC-12 | core | TBD |
| AC-13 | core | TBD |

## Open questions

- Should `vodStreams(categoryID: nil)` page through categories for providers whose unfiltered list exceeds tens of megabytes? Any resolution must keep an unfiltered count path for 0006/AC-10a.
- Is the `/movie/` and `/series/` URL shape universal, or do some providers require `direct_source` when present?
