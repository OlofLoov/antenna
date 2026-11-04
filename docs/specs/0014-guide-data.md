# 0014. Guide data: download, join and query

- Status: Draft (three spec-reviewer rounds; the PR lists what each round changed and what is still open)
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005, and a pending ADR on guide storage (unnumbered until written; this spec stays Draft until it is accepted)
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0002 (XMLTV parsing), 0003 (Xtream client, `xmltvURL()`), 0004 (sources), 0013 (catalogue). Requires 0013/AC-1 (`Channel.sourceID`) merged first. 0016 is referenced for its error names only.
- Blocked on the storage ADR: where programmes and the per-device "last completed load" timestamp live. Programmes are never written to the CloudKit-synced container of ADR-0002; the options are an in-memory index rebuilt on launch, a local file cache, or a local-only SwiftData store. The timestamp lives outside the synced container in every option. AC-13 and AC-14 assume the in-memory option as the floor and are written so that they hold under every option.

## Design

Boards: none, no UI. Progress and states are rendered by 0006 (checklist), 0007, 0008, 0009, 0010, 0012.
Design rules that apply: DR-15 (progress reporting is defined here).

## Problem

The XMLTV parser exists and has no caller. Nothing downloads a guide, joins programmes to channels, or answers "what is on channel X now". Every screen in this set needs that answer.

## Scope

In:
- `GuideKey` value type in AntennaCore: (`sourceID: UUID`, `epgID: String`). Channels with the same key share programmes and state. Every query takes a `GuideKey` or a `Channel` from which it derives one. A channel with `epgID` nil or `sourceID` nil has no key: `loadingState(for channel:)` for it is `.loading` until its source's first join and `.noData` afterwards, and its queries return nil or empty. `Channel.id` and `Channel.streamURL` are never part of a key, event, file name or log line (0013 edge case, ADR-0003), because an M3U fallback id embeds the stream URL.
- `GuideLoadingState` in AntennaCore: `.loading`, `.loaded`, `.noData`, `.unavailable`, `.failed(GuideError)`. Consumers (0007/AC-7, 0009/AC-12, 0010/AC-9) switch on it.
- `GuideIndex` value type in AntennaCore, `Sendable` and immutable, built from `[Programme]` per source and `[Channel]`: join, overlap resolution, `current`, `next`, `programmes(in:)`, `horizon`, `unmatched`. It treats input order as document order. AC-2 to AC-8 and AC-16 test this type directly.
- `GuideURLResolver.resolve(kind:epgURL:playlistEPGURLs:credential:) -> URL?` in AntennaCore (AC-1). `GuideDecoder` in AntennaCore: sniffing and gunzip (AC-17); gunzip enforces the inflated limit during inflation, not after. `redacted(_ url: URL) -> String` in AntennaCore (AC-15). Size limits are constants in AntennaCore (AC-20).
- `GuideStore` protocol in AntennaCore, implemented in the app layer: `programmes(for: [GuideKey], in: DateInterval)`, `current(for: GuideKey, at: Date)`, `next(for: GuideKey, after: Date, count: Int)`, `horizon`, `loadingState(for: GuideKey)`, `progressStream()` factory, `refreshIfStale(now:)`, `refresh(source:)`, `update(channels: [Channel])` (called by the app after each source finishes loading; runs the join of AC-2 and AC-19), `register(epgURLs: [URL], for sourceID: UUID)` (called by the loader for M3U sources), `remove(sourceID:)` (called by the app when a `SourceRecord` is deleted locally or disappears from the synced container; AC-18 and AC-18a hold for both paths). The protocol is not actor-isolated; the app implementation is `@MainActor`. Download, decode, parse and the join run off the main actor and publish a new `GuideIndex` by a single assignment; queries read the current index.
- Loader call order after each source finishes: `register(epgURLs:for:)`, then `update(channels:)`, then `refreshIfStale(now:)`.
- `GuideProgress`: `.downloading(sourceID:, bytesReceived:, expectedBytes:)`, `.loaded(sourceID:, channelsWithGuide:, channelsTotal:, days:, unmatched:)`, `.failed(sourceID:, GuideError)`.
- `GuideError`: `.httpStatus(Int)`, `.timeout`, `.offline`, `.network(URLError.Code)`, `.malformed`, `.empty`, `.unsupportedEncoding`, `.tooLarge`, `.credentialMissing`, `.credentialUnreadable`, `.unauthorized`.
- Guide sources: `SourceRecord.epgURL` for any kind; else for M3U the first of `Playlist.epgURLs`; else for Xtream `XtreamClient.xmltvURL()` (0003/AC-5) with the Keychain credential. A Stalker source with `epgURL` nil has no guide URL.
- The guide is fetched with `URLSession.bytes(for:)` on the resolved URL, never through `XtreamClient`, so that byte progress (AC-9) is observable. There is no reachability pre-check; offline is detected from the `URLError` of the attempt.
- Guide loads run one source at a time in `SourceRecord.sortOrder`; a `refresh(source:)` for another source queues behind the running one.
- Join on `GuideKey`, re-run on every `update(channels:)`.
- Progress in two phases; gzip detection by magic bytes.
- Refresh: stale after 12 hours per device, plus on demand.
- Overlap resolution, interval queries, horizon, size limit.

Out (explicitly):
- Where programmes persist (the ADR above).
- Multiple guide sources per playlist; guide source selection UI.
- Manual channel-to-guide mapping.
- Programme artwork and metadata beyond `Programme`.
- Reminders, recording, catch-up windows.
- Any rendering.

## User flow

None. Consumed by screens.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Guide URL per source
Given each source row below, with the credential passed in to `GuideURLResolver.resolve`
When guide URLs are resolved
Then the result is the URL in that row and no request is issued during resolution.

| Source | Result |
|--------|--------|
| M3U with `epgURL` | `epgURL` |
| M3U without `epgURL`, playlist `epgURLs` [u1, u2] | u1 (u2 ignored) |
| M3U without `epgURL`, empty `epgURLs` | none; its keys report `.unavailable` |
| Xtream with `epgURL` | `epgURL` |
| Xtream without `epgURL` | `XtreamClient.xmltvURL()` built from the credential |
| Stalker without `epgURL` | none; its keys report `.unavailable` |

### AC-1a Credential missing
Given an Xtream source without `epgURL` whose Keychain item is absent
When `refresh(source:)` runs
Then no request is issued, `progressStream()` emits `.failed(sourceID:, .credentialMissing)` exactly once per load on each live stream (replay under AC-9a does not count), and its keys report `.unavailable`. This is the one failure whose keys report `.unavailable` rather than `.failed`, because the source is not misconfigured; every AC-13 trigger retries it since no load has completed.

### AC-1b Credential unreadable
Given an Xtream source without `epgURL` whose Keychain read fails with a status other than not-found
When `refresh(source:)` runs
Then no request is issued, `progressStream()` emits `.failed(sourceID:, .credentialUnreadable)` once, and its keys report `.failed`.

### AC-2 Join by GuideKey
Given a channel with `epgID` " sport1.se" and a programme with `channelID` "sport1.se ", and a channel with `epgID` nil
When the join runs
Then the first channel has its programme through its `GuideKey`; both `Channel.epgID` and `Programme.channelID` are trimmed of whitespace and newlines before comparison, which is otherwise exact and case-sensitive; the second channel has no key, gets no programme and reports `.noData` after the join; a programme whose `channelID` matches no key of that source is dropped and counted as `unmatched`.

### AC-3 Join is per source
Given two sources whose guides both contain channel id "one"
When the join runs
Then each source's keys receive programmes only from that source's guide.

### AC-4 Current programme
Given programmes 20:00 to 22:00 and 22:00 to 23:00 on a key
When `current(for:, at: 21:34)` runs
Then it returns the 20:00 programme; at 22:00 exactly it returns the 22:00 programme (start inclusive, stop exclusive); with no programme covering `at` it returns nil.

### AC-5 Next programmes
Given the programmes of AC-4 and a third at 23:15
When `next(for:, after: 22:00, count: 3)` runs
Then it returns the 22:00 and 23:15 programmes in start order, programmes with `start >= after` only, at most `count`.

### AC-6 Overlap resolution
Given `Programme` values constructed directly, in the order listed: A 20:00 to 22:00 and B 20:30 to 21:00 on one key; C 21:00 to 22:00 and then D 21:00 to 21:30 on another key; and E whose start equals its stop
When `GuideIndex` ingests them
Then the later start wins the overlap and truncation never splits a programme: A becomes 20:00 to 20:30, B stays, and 21:00 to 22:00 is a gap; of C and D the last in input order is kept, so D, and 21:30 to 22:00 is a gap; E is dropped before resolution because a programme whose start is not before its stop has no duration (the parser already drops these per 0002/AC-6, so the index must too).

### AC-7 Interval query
Given programmes 19:30 to 20:30, 21:00 to 21:30 (a gap 20:30 to 21:00), and 22:00 to 23:00
When `programmes(for:, in: 20:00..<22:00)` runs
Then it returns every programme with `start < interval.end` and `stop > interval.start`, sorted by start: the 19:30 and 21:00 programmes; the gap is not filled.

### AC-8 Horizon
Given loaded sources whose programmes, after overlap resolution, span 2026-11-03 06:00 to 2026-11-10 06:00 in union
When `horizon` is read
Then it equals that interval; with no source holding programmes it is nil.

### AC-9 Progress, download phase
Given a guide download in progress
When bytes arrive
Then `progressStream()` emits `.downloading(sourceID:, …)` on the first chunk, then at most once per 250 ms of the injected clock, and, if at least one chunk arrived, once more with the final byte count before `.loaded` or `.failed`; `expectedBytes` is `URLResponse.expectedContentLength`, or nil when it is unknown; every caller of `progressStream()` receives its own stream.

### AC-9a Late subscriber replay
Given loads for sources A (in progress) and B (`.failed` earlier in this process)
When a new `progressStream()` is created
Then its first events are the most recent event of A and of B, in `sortOrder`, followed by live events; replay is not an emission for AC-1a's count.

### AC-10 Progress, parsed phase
Given a fixture of 412 channels, 24 of which have no programme with `stop > now`, 1200 programmes whose `channelID` matches no key of the source, and programme starts on exactly 7 distinct UTC calendar days from the day containing now to the day containing the latest stop
When the join completes
Then it emits `.loaded(sourceID:, channelsWithGuide: 388, channelsTotal: 412, days: 7, unmatched: 1200)`, where `channelsWithGuide` is the number of channels of the source whose key has at least one programme with `stop > now`, `channelsTotal` is the number of channels of the source including those with `epgID` nil, `unmatched` counts programmes, and `days` is the number of UTC calendar days, from the day containing now through the day containing the source's latest stop, on which at least one programme of the source starts or is airing at 00:00 UTC. `.loaded` is emitted after every join of that source, including re-joins caused by `update(channels:)`, with recomputed counts. `loadingState` is `.loaded` for a key with at least one programme at any time and `.noData` for a key with none.

### AC-11 Loading state before data
Given a source whose guide has never completed a load on this device
When `loadingState(for:)` is read for its keys
Then it is `.loading` while a load is in progress or pending, or while the guide URL is not yet known (an M3U source before `register(epgURLs:for:)`); `.unavailable` for a source known to have no guide URL; `.failed` after a failed first load.

### AC-11a Loading state is sticky after a first load
Given a source with a previously completed guide on this device
When a refresh starts or fails, offline included
Then `loadingState` for its keys keeps its per-key `.loaded` or `.noData` value throughout, the previous guide stays queryable, and a failure is reported only as `.failed(sourceID:, GuideError)` on `progressStream()`.

### AC-12 Failure
Given a guide URL that returns a non-2xx status, exceeds `timeoutIntervalForRequest`, fails offline, returns a gzip body that does not inflate, returns bytes the parser rejects, returns a document the parser accepts with zero programmes, or returns a body that is neither XML nor gzip (AC-17 sniffing rule)
When the load runs
Then `progressStream()` emits `.failed(sourceID:, error)` with `.httpStatus(n)`, `.timeout`, `.offline` (for `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`), `.malformed` (for both the corrupt gzip and the rejected XML), `.empty` or `.unsupportedEncoding`, and any other `URLError` as `.network(code)`; a 401 or 403 maps to `.unauthorized` only when the URL was built from the Xtream credential (AC-1 row five), for any other URL it is `.httpStatus(401)` or `.httpStatus(403)`; channels of other sources are unaffected, and AC-11 or AC-11a governs `loadingState`.

### AC-12a Session configuration
Given the store's `URLSessionConfiguration`
When it is read
Then `timeoutIntervalForRequest` is 30, `timeoutIntervalForResource` is 600, `urlCache` is nil, `requestCachePolicy` is `.reloadIgnoringLocalCacheData` and `httpShouldSetCookies` is false.

### AC-13 Refresh policy
Given a source for which this device holds no completed guide, or whose last completed load on this device finished more than 12 hours ago
When the app launches, `scenePhase` becomes `.active` on any platform, or that source's channels finish loading
Then `refreshIfStale(now:)` starts a load for it; a source with a completed guide younger than 12 hours is not refreshed; a source with a load in progress is not started again; `refresh(source:)` starts one regardless of age. A source counts as holding a completed guide only when its programmes are queryable now; a timestamp without its programmes is ignored and removed. The timestamp is stored per device outside the synced container; `SourceRecord.lastRefreshedAt` is not it, because it syncs and would mark a guide fresh on a device that never downloaded it.

### AC-13a Refresh during a load
Given a source with a load in progress
When `refresh(source:)` runs for it
Then the running load is cancelled and a new one starts, nothing is emitted for the cancelled task, and `URLError.cancelled` is never emitted as `.failed`.

### AC-13b No sources
Given zero sources
When `refreshIfStale(now:)` runs
Then no request is issued and `progressStream()` emits nothing (0004/AC-8).

### AC-14 Resume after relaunch
Given a fresh store, a stub that records request headers, and, when the storage ADR chooses a file cache, a partially written file for the source in the cache directory
When `refreshIfStale(now:)` runs
Then `programmes(for:)` for that source's keys is empty, `loadingState` is `.loading` until the new request completes, the request has no `Range` header, and the partial file is deleted before the request starts; nothing from the interrupted download is queryable.

### AC-15 Credentials never in the clear
Given a guide URL whose query carries credential items (`username`, `password`, `token`, `pass`, `key` or any other name) or whose userinfo carries credentials (`http://u:p@host/epg.xml`)
When a log line is written or a cache or file name is derived
Then `redacted(_:)` keeps scheme, host, port and path, replaces every query value with "…" keeping the names, and drops userinfo; the injected logger receives only `redacted(url)`, the `sourceID` and the `GuideError` case name; the thrown `URLError` is reduced to its `code` and not retained (as 0016/AC-10); the cache or file is keyed by `sourceID` never by URL; the test asserts every recorded log line against the raw URL.

### AC-16 Query performance
Given 2 000 keys with seven days of programmes, and separately 500 000 programmes and 20 000 channels
When `current(for:at:)` runs for 50 keys, `programmes(for:in:)` for a 2.5-hour window over 42 keys, `programmes(for: all 2 000 keys, in: horizon)`, the join of the large fixture, and `update(channels:)` with the large fixture on the main actor
Then the first two each return in under 10 ms, the third in under 100 ms, the join completes in under 2 s measured on the worker, and `update(channels:)` returns within 5 ms on the main actor, in a debug `swift test` run on the reference machine named in the test (same baseline as 0013/AC-14); benchmark, not CI-gated.

### AC-17 Gzipped guide
Given a guide body that starts with the gzip magic bytes `1f 8b` and no Content-Encoding header
When loaded
Then `GuideDecoder` sniffs the body: after stripping an optional UTF-8 BOM, a body whose first non-whitespace byte is `<` is XML; a body starting `1f 8b` is gunzipped and sniffed once more; anything else fails with `.unsupportedEncoding`. The gzipped fixture parses to the same result as its uncompressed document. A body `URLSession` already inflated through transparent `Content-Encoding: gzip` reaches the sniffer as XML; this is verified manually against a server that sends `Content-Encoding: gzip` and is not in the automated test plan.

### AC-18 Source deleted during a load
Given a load in progress for source S
When `remove(sourceID:)` runs for S
Then the task is cancelled, `progressStream()` emits nothing further for S, and `programmes(for:)` for S's keys returns empty.

### AC-18a Source deleted after a completed load
Given a source S with a completed guide
When `remove(sourceID:)` runs for S
Then `programmes(for:)` for S's keys is empty, `horizon` no longer includes S's span, `loadingState` for S's keys is `.unavailable`, and S's per-device timestamp and any cached file are removed.

### AC-19 Guide before channels
Given a source whose guide finishes downloading before its channel list has loaded
When `update(channels:)` later delivers that source's channels
Then the join runs then, `loadingState` is `.loading` until it does, and `.loaded` is emitted after the join.

### AC-20 Guide too large
Given the AntennaCore limit constants (tvOS 32 MB compressed and 96 MB inflated, elsewhere 96 MB and 256 MB, each below half the platform's resident budget; the test reads the constants rather than restating them) and a response whose `expectedContentLength` exceeds the applicable limit, or whose body exceeds it when the length was unknown
When loaded
Then `expectedContentLength` is compared to the compressed limit when the body sniffs as gzip and to the inflated limit otherwise, the byte count from `bytes(for:)` is compared to the limit of the body it delivers, the inflated size is checked again during gunzip, the task is cancelled before the next chunk is requested once a limit is crossed with no more than one chunk read beyond it, and `.failed(sourceID:, .tooLarge)` is emitted.

## Edge cases and failure modes

- Memory budget: 150 MB resident on tvOS, 400 MB elsewhere, measured on device before the implementing PR. AC-20's limits and the one-at-a-time load rule in Scope keep a parse under it; the constants are revised from that measurement. A streaming parser (0002 follow-up) lifts this.
- Time zones: `Programme` times are absolute dates; `days` in AC-10 uses UTC calendar days by definition.
- A guide whose programmes all lie in the past: horizon set, `current` nil everywhere, keys are `.loaded` (AC-10), 0009 shows AC-12 blocks.
- Offline at refresh with a previous guide: AC-11a, the attempt fails with `.offline` on `progressStream()`; with none: AC-11 and AC-12 `.offline`. There is no reachability pre-check.
- A 200 response whose body is an HTML login page (the common Xtream failure) sniffs as XML, parses to zero programmes and fails with `.empty` (0002 edge case).
- A Stalker source with `epgURL` set (zero channels, 0004/AC-13) still downloads its guide; every programme is `unmatched`. Open: load only after the source delivers a channel.
- `next(for:after:count:)` callers (0007/AC-19, 0010/AC-8) pass the current programme's stop, or now when there is none.
- Duplicate `Programme.id` across channels (0002 open question): the store keys on `GuideKey` plus start time.
- User-supplied M3U EPG URLs with embedded credentials (0004 edge case) are covered by AC-15.

## Test plan

Join, current, next, overlap, interval, horizon, URL resolution, decoding, redaction and performance are swift-testing tests over fixtures in AntennaCore against `GuideIndex`, `GuideURLResolver`, `GuideDecoder` and `redacted(_:)`. Download, progress, refresh, failure, deletion and relaunch use a stubbed `URLSession` that records request headers, an injected clock and an injected logger in the app layer.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (`GuideURLResolver`, parameterised over the rows) | TBD |
| AC-1a | integration (Keychain lookup around the resolver) | TBD |
| AC-1b | integration (Keychain stub returning a read error) | TBD |
| AC-2 | core (`GuideIndex`) | TBD |
| AC-3 | core (`GuideIndex`) | TBD |
| AC-4 | core (`GuideIndex`) | TBD |
| AC-5 | core (`GuideIndex`) | TBD |
| AC-6 | core (`GuideIndex`) | TBD |
| AC-7 | core (`GuideIndex`) | TBD |
| AC-8 | core (`GuideIndex`) | TBD |
| AC-9 | integration (chunked stub, injected clock) | TBD |
| AC-9a | integration (two sources, late subscriber) | TBD |
| AC-10 | integration | TBD |
| AC-11 | integration | TBD |
| AC-11a | integration | TBD |
| AC-12 | integration (parameterised over causes) | TBD |
| AC-12a | integration (configuration assertions) | TBD |
| AC-13 | integration (injected clock, per-device timestamp) | TBD |
| AC-13a | integration (re-entrancy) | TBD |
| AC-13b | integration | TBD |
| AC-14 | integration (fresh store, header-recording stub, partial file when a cache exists) | TBD |
| AC-15 | core (`redacted(_:)`) + integration (logger, cache key) | TBD |
| AC-16 | core benchmark + integration (main-actor timing) | TBD |
| AC-17 | core (`GuideDecoder`, gzipped fixture) + integration (end to end); transparent decoding manual | TBD |
| AC-18 | integration | TBD |
| AC-18a | integration | TBD |
| AC-19 | integration | TBD |
| AC-20 | integration (stub with and without a known length, gzip and plain) | TBD |

## Open questions

- ADR: storage of programmes and the per-device timestamp (memory, file cache, local-only store). A cache lets the guide appear before the first refresh completes.
- Should the refresh interval be a setting? If synced, it is a record under ADR-0002 and needs the ADR.
- Retry after a failed first load: AC-11 and AC-13 retry on every launch and every `.active`, so a permanently broken guide is re-downloaded each time the user returns. A 15-minute hold between attempts was proposed in review and is undecided.
- Should a guide load wait until the source has delivered at least one channel through `update(channels:)`? Undecided; see the Stalker edge case.
- Streaming XMLTV parsing to lift the size budget (0002 follow-up).
