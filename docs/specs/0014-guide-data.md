# 0014. Guide data: download, join and query

- Status: Draft (two spec-reviewer rounds; remaining findings listed in the PR)
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0002 (XMLTV parsing), 0003 and 0016 (Xtream client, `unauthorized`, `transport`), 0004 (sources), 0013 (catalogue).
- Blocked on an ADR for where programmes and the per-device "last completed load" timestamp are stored. Programmes are never written to the CloudKit-synced container of ADR-0002; the options are an in-memory index rebuilt on launch, a local file cache, or a local-only SwiftData store. The timestamp lives outside the synced container in every option. AC-13 and AC-14 assume the in-memory option as the floor.

## Design

Boards: none, no UI. Progress and states are rendered by 0006 (checklist), 0007, 0008, 0009, 0010, 0012.
Design rules that apply: DR-15 (progress reporting is defined here).

## Problem

The XMLTV parser exists and has no caller. Nothing downloads a guide, joins programmes to channels, or answers "what is on channel X now". Every screen in this set needs that answer.

## Scope

In:
- `GuideKey` value type in AntennaCore: (`sourceID: UUID`, `channelID: String`) where `channelID` is `Channel.epgID ?? Channel.id`. Channels with the same key share programmes and state. Every query takes a `GuideKey` or a `Channel` from which it derives one.
- `GuideStore` protocol in AntennaCore, implemented in the app layer: `programmes(for: [GuideKey], in: DateInterval)`, `current(for: GuideKey, at: Date)`, `next(for: GuideKey, after: Date, count: Int)`, `horizon`, `loadingState(for: GuideKey)`, `progressStream()` factory, `refreshIfStale(now:)`, `refresh(source:)`.
- `GuideProgress`: `.downloading(sourceID:, bytesReceived:, expectedBytes:)`, `.loaded(sourceID:, channelsWithGuide:, channelsTotal:, days:, unmatched:)`, `.failed(sourceID:, GuideError)`.
- `GuideError`: `.httpStatus(Int)`, `.timeout`, `.offline`, `.network(URLError.Code)`, `.malformed`, `.empty`, `.unsupportedEncoding`, `.tooLarge`, `.credentialMissing`, `.unauthorized`.
- Guide sources: `SourceRecord.epgURL` for any kind; else for M3U the first of `Playlist.epgURLs` (the loader hands them to the store); else for Xtream `xmltv.php` with the Keychain credential.
- Join on `GuideKey`, re-run whenever the catalogue changes.
- Progress in two phases; gzip detection by magic bytes.
- Refresh: stale after 12 hours per device, plus on demand.
- Overlap resolution, interval queries, horizon.

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
Given an M3U source with `epgURL` set; an M3U source with `epgURL` nil whose playlist yields `epgURLs` [u1, u2]; an Xtream source with `epgURL` set; an Xtream source with `epgURL` nil; and an Xtream source whose credential cannot be loaded
When guide URLs are resolved
Then they are `epgURL`; u1 (u2 ignored); `epgURL`; `<server>/xmltv.php?username=…&password=…` built from the Keychain credential; and for the last no request is issued, `progressStream()` emits `.failed(sourceID:, .credentialMissing)` once and its channels report `.unavailable`. A source with no URL at all has no guide and its channels report `.unavailable`.

### AC-2 Join by GuideKey
Given a channel with `epgID` "sport1.se" and a programme with `channelID` "sport1.se", and a channel with `epgID` nil and `id` "x1" with a programme whose `channelID` is "x1"
When the join runs
Then both channels have their programme through their `GuideKey`; a programme whose `channelID` matches no key of that source is dropped and counted as `unmatched`.

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
Then it returns the 22:00 and 23:15 programmes in start order (programmes with `start >= after`); callers pass the current programme's stop, or now when there is none.

### AC-6 Overlap resolution
Given programmes A 20:00 to 22:00 and B 20:30 to 21:00 on one key, and C and D with equal start
When the store ingests them
Then the later start wins the overlap and truncation never splits a programme: A becomes 20:00 to 20:30, B stays, and 21:00 to 22:00 is a gap; of C and D the last parsed is kept; a programme whose duration becomes zero is dropped.

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
Then `progressStream()` emits `.downloading(sourceID:, …)` on the first chunk, then at most once per 250 ms of the injected clock, and once more with the final byte count before `.loaded` or `.failed`; `expectedBytes` is nil when the response has no Content-Length; every caller of `progressStream()` receives its own stream.

### AC-10 Progress, parsed phase
Given the download completed and parsing finished for a source with 412 channels
When the join completes
Then it emits `.loaded(sourceID:, channelsWithGuide: 388, channelsTotal: 412, days: 7, unmatched: 1200)` once, where `channelsWithGuide` is the number of distinct keys of that source with at least one programme whose stop is after now, `channelsTotal` counts every channel of the source including those with `epgID` nil, and `days` is the number of distinct UTC calendar days from now to the source's latest stop containing at least one programme start; `loadingState` is `.loaded` for matched keys and `.noData` for unmatched ones.

### AC-11 Loading state before data
Given a source whose guide has never completed a load on this device
When `loadingState(for:)` is read for its keys
Then it is `.loading` while a load is in progress or pending; `.unavailable` for a source with no guide URL; `.failed` after a failed first load.

### AC-11a Loading state is sticky after a first load
Given a source with a previously completed guide on this device
When a refresh starts, fails, or is skipped offline
Then `loadingState` for its keys keeps its per-key `.loaded` or `.noData` value throughout, the previous guide stays queryable, and a failure is reported only as `.failed(sourceID:, GuideError)` on `progressStream()`.

### AC-12 Failure
Given a guide URL that returns a non-2xx status, times out (request 30 s, resource 10 min), fails offline, returns bytes the parser rejects, returns a document the parser accepts with zero programmes, or is gzip-free binary
When the load runs
Then `progressStream()` emits `.failed(sourceID:, error)` with `.httpStatus(n)`, `.timeout`, `.offline` (for `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`), `.network(code)`, `.malformed`, `.empty` or `.unsupportedEncoding`; an Xtream 401 or 403 maps to `.unauthorized`; channels of other sources are unaffected, and AC-11 or AC-11a governs `loadingState`.

### AC-13 Refresh policy
Given a source for which this device holds no completed guide, or whose last completed load on this device finished more than 12 hours ago
When the app launches, returns to the foreground, or that source's channels finish loading
Then `refreshIfStale(now:)` starts a load for it; a source with a completed guide younger than 12 hours is not refreshed; `refresh(source:)` starts one regardless; the timestamp is stored per device outside the synced container.

### AC-14 Resume after relaunch
Given a guide download interrupted by termination
When the app relaunches
Then a fresh request without a `Range` header starts and `loadingState` is `.loading` until it completes; no partial guide is exposed.

### AC-15 Credentials never in the clear
Given a guide URL whose query carries `username`, `password` or `token` items
When it appears in a `GuideError` description or an app-layer log line, or a cache or file name is derived
Then the items are replaced with "…" in descriptions and logs, the cache or file is keyed by `sourceID` never by URL, and the raw URL exists only in the `URLRequest`.

### AC-16 Query performance
Given 2 000 keys with seven days of programmes
When `current(for:at:)` runs for 50 keys, `programmes(for:in:)` for a 2.5-hour window over 42 keys, and `programmes(for: all 2 000 keys, in: horizon)`
Then the first two each return in under 10 ms and the third in under 100 ms in a debug `swift test` run on the reference machine named in the test (same baseline as 0013/AC-14); benchmark, not CI-gated.

### AC-17 Gzipped guide
Given a guide body that starts with the gzip magic bytes `1f 8b` and no Content-Encoding header
When loaded
Then the body is decompressed before parsing and the result equals parsing the uncompressed document; a body that is neither XML nor gzip fails with `.unsupportedEncoding`.

### AC-18 Source deleted during a load
Given a load in progress for source S
When S is deleted
Then the task is cancelled, `progressStream()` emits nothing further for S, and `programmes(for:)` for S's keys returns empty.

### AC-19 Guide before channels
Given a source whose guide finishes downloading before its channel list has loaded
When the catalogue later gains that source's channels
Then the join runs then, `loadingState` is `.loading` until it does, and `.loaded` is emitted once after the join.

## Edge cases and failure modes

- Memory budget: 150 MB resident on tvOS, 400 MB elsewhere, measured on device before the implementing PR; a parse that would exceed it, or a response whose Content-Length exceeds it, fails with `.tooLarge`. A streaming parser (0002 follow-up) lifts this.
- Time zones: `Programme` times are absolute dates; `days` in AC-10 uses UTC calendar days by definition.
- A guide whose programmes all lie in the past: horizon set, `current` nil everywhere, 0009 shows AC-12 blocks.
- Offline at refresh with a previous guide: AC-11a; with none: AC-11 and AC-12 `.offline`.
- Duplicate `Programme.id` across channels (0002 open question): the store keys on `GuideKey` plus start time.
- User-supplied M3U EPG URLs with embedded credentials (0004 edge case) are covered by AC-15.

## Test plan

Join, current, next, overlap, interval, horizon and performance are swift-testing tests over fixtures in AntennaCore. Download, progress, refresh, failure, gzip, deletion and the relaunch recipe (a store constructed over a cache directory holding a partially written download and no completed guide) use a stubbed `URLSession` and an injected clock in the app layer.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (URL builder) + integration (credential lookup, `Playlist.epgURLs`) | TBD |
| AC-2 | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9 | integration (chunked stub, injected clock) | TBD |
| AC-10 | integration | TBD |
| AC-11 | integration | TBD |
| AC-11a | integration | TBD |
| AC-12 | integration (parameterised over causes) | TBD |
| AC-13 | integration (injected clock, per-device timestamp) | TBD |
| AC-14 | integration (relaunch recipe) | TBD |
| AC-15 | core (redaction) + integration (cache key) | TBD |
| AC-16 | core benchmark | TBD |
| AC-17 | integration (gzipped fixture) | TBD |
| AC-18 | integration | TBD |
| AC-19 | integration | TBD |

## Open questions

- ADR: storage of programmes and the per-device timestamp (memory, file cache, local-only store). A cache lets the guide appear before the first refresh completes.
- Should the refresh interval be a setting? If synced, it is a record under ADR-0002 and needs the ADR.
- Streaming XMLTV parsing to lift the size budget (0002 follow-up).
