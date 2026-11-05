# 0003. Xtream Codes live source

- Status: Implemented
- Date: 2026-11-03
- Depends on ADRs: 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore, no UI)
- User stories: US-1
- Retroactive: documents behaviour shipped in commit 082034b. Written so later
  changes have a spec to revise or supersede. Every criterion has a test
  citing it since the retroactive test pass.

## Problem

Xtream Codes logins (server, username, password) are the other common way
users hold a subscription. Panels return JSON with inconsistent types and
require the credentials in every URL. The app needs a client that lists live
categories and streams, builds playable URLs, and maps streams onto the same
`Channel` model as M3U so the rest of the app does not care where a channel
came from.

## Scope

In:
- `player_api.php` actions `get_live_categories`, `get_live_streams`
  (optionally filtered by category) and the no-action account call.
- Tolerant decoding of ids and counters that arrive as numbers or strings.
- Live stream URL in `.ts` or `.m3u8` form, and the `xmltv.php` guide URL.
- Mapping `XtreamLiveStream` plus category name to `Channel`.
- Non-2xx responses surface as a typed error.

Out (explicitly):
- VOD and series endpoints.
- `get_short_epg` and `get_simple_data_table`.
- Catch-up (`timeshift`) URLs.
- Retries, timeouts beyond `URLSession` defaults, rate limiting.
- Detecting an expired or disabled account from `user_info`.
- Storing credentials (spec 0004, ADR-0003).

## User flow

1. User adds an Xtream source with server URL, username and password (spec 0004).
2. The app loads categories and live streams concurrently and maps them to channels.
3. Channels appear in the Channels tab grouped by category name.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Request shape
Given credentials for `http://panel:8080` with username `u` and password `p`
When `liveStreams(categoryID: "3")` is called
Then exactly one GET is issued to `http://panel:8080/player_api.php?username=u&password=p&action=get_live_streams&category_id=3`, with query items in the order username, password, action, then category_id, and without a category the `category_id` item is absent.

Superseded in part by 0016/AC-1: credentials are percent-encoded outside the RFC 3986 unreserved set in every request.

### AC-2 Loose numeric types decode
Given a live stream JSON where `num`, `stream_id`, `tv_archive` and `tv_archive_duration` are strings and `category_id` is a number
When decoded
Then the values are the corresponding integers and `categoryID` is the string "3".

Narrowed by 0016/AC-4: an integer decodes only from a whole number, so "7.5" is not 7.

### AC-3 Category id as number or string
Given categories JSON with `category_id` as `7` in one item and `"8"` in another
When decoded
Then `categoryID` is "7" and "8".

### AC-4 Live stream URL
Given stream id 42
When `streamURL(for:)` is built
Then it is `http://panel:8080/live/u/p/42.ts`, and with `container: .m3u8` it ends in `42.m3u8`.

Superseded in part by 0016/AC-7: credentials in the path are percent-encoded.

### AC-5 Guide URL
Given the same credentials
When `xmltvURL()` is built
Then it is `http://panel:8080/xmltv.php?username=u&password=p`.

Superseded in part by 0016/AC-1 and 0016/AC-7: credentials in the query are percent-encoded.

### AC-6 Channel mapping
Given a stream with `stream_id` 42, `name` "BBC One", `num` 7, `stream_icon` "", `epg_channel_id` "", `tv_archive` 1, `tv_archive_duration` 3 and category name "UK"
When mapped with `channel(from:categoryName:)`
Then `id` is `xtream#panel#42`, `name` is "BBC One", `number` is 7, `group` is "UK", `epgID` is nil, `logoURL` is nil, `hasCatchup` is true and `catchupDays` is 3.

### AC-7 Non-2xx response is a typed error
Given the server answers 403
When any endpoint is called
Then the call throws `XtreamClient.XtreamError.badStatus(403)`.

Superseded by 0016/AC-11: 401 and 403 throw `XtreamError.unauthorized`; other non-2xx statuses still throw `badStatus`.

### AC-8 Malformed JSON is an error, not a crash
Given the server answers 200 with an HTML login page
When `liveStreams()` is called
Then the call throws a `DecodingError`.

Superseded by 0016/AC-4b: the call throws `XtreamError.decoding(path: "")`, and no call lets `DecodingError` escape.

### AC-9 Account info decodes loose types
Given `user_info` with `exp_date` as a number and `max_connections` as a string
When `accountInfo()` is decoded
Then both are available as strings.

### AC-10 Ids are stable per server and stream
Given the same stream decoded from two separate responses
When mapped to channels
Then the ids are equal, two different stream ids on one server give different ids, and ids do not distinguish scheme or port.

## Edge cases and failure modes

- Credentials are part of every URL. URLs built by this client must never be logged (ADR-0003, conventions). Error values carry status codes only.
- Channel ids use the server host only. Two panels on the same host with different ports, or one panel over http and https, produce colliding ids. A server URL without a host yields `xtream##42`.
- Many panels answer 200 with `{"user_info":{"auth":0}}` for bad credentials. Since 0016/AC-11 every call throws `XtreamError.unauthorized` for it.
- A response that is not `HTTPURLResponse` surfaces as `badStatus(-1)`.
- A server URL with a path component keeps the path: `http://host/xtream` and `http://host/xtream/` both yield `http://host/xtream/player_api.php`.
- Since 0016/AC-4, `liveStreams()` skips a row that is not an object, lacks `name` or `stream_id`, or whose `stream_id` is not a whole number, and returns the rest. Duplicate stream ids are kept.
- Categories missing `category_name` fail decoding for the whole category list.
- Duplicate `category_id` values (for example `7` and `"7"`) decode to equal `categoryID` strings; the client does not deduplicate. Spec 0004 records the consequence.

## Test plan

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (URLProtocol stub) | `XtreamClientTests.requestShape` |
| AC-2 | core | `XtreamClientTests.looseNumericTypes` |
| AC-3 | core | `XtreamClientTests.categoryIDNumberOrString` |
| AC-4 | core | `XtreamClientTests.liveStreamURL` |
| AC-5 | core | `XtreamClientTests.guideURL` |
| AC-6 | core | `XtreamClientTests.channelMapping` |
| AC-7 | core (URLProtocol stub, parameterised over the three endpoints and 403, 500) | `XtreamClientTests.nonSuccessStatus` (asserts 0016/AC-11) |
| AC-8 | core (URLProtocol stub) | `XtreamClientTests.malformedJSON` (asserts 0016/AC-4b) |
| AC-9 | core | `XtreamClientTests.accountInfoLooseTypes` |
| AC-10 | core | `XtreamClientTests.stableIDs` |

## Open questions

- Resolved by 0016/AC-11: bad credentials (`auth: 0`) throw `XtreamError.unauthorized`.
- Resolved by 0016/AC-4: an undecodable live row is skipped instead of failing the whole stream list.
