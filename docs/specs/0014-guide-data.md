# 0014. Guide data: download, join and query

- Status: Implemented
- Date: 2026-11-03
- Depends on ADRs: 0002, 0003, 0005
- Builds on specs: 0002, 0003, 0004, 0013, 0016
- Follow-up ADR: where the guide is kept on the device (in memory and rebuilt at launch, a file cache, or a local-only database). This spec assumes memory only until then; AC-13 holds under every option.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-4, US-9, US-10

## Summary

Every screen that says what is on a channel needs this: the channel overlay and zap bar on Apple TV, the guide grid, the Live screen and Search. Once it ships, the app downloads each source's TV guide, matches its programmes to the user's channels, and can answer "what is on now", "what is next" and "what is on between these times", while telling screens how far a download has got and why it failed. It refreshes the guide about twice a day and never lets a password show up in a log. It draws nothing itself, does not let the user pick or fix guide sources (0021), and does not decide yet where the guide is stored between launches.

## Design

Boards: none, no UI. Screens in 0006, 0007, 0008, 0009, 0010 and 0012 show the progress and states this spec reports.
Design rules that apply: DR-15.

## Problem

The parser for XMLTV, the common TV guide file format, exists (0002) and nothing calls it. Nothing downloads a guide, matches programmes to channels, or answers "what is on this channel now". Every live TV screen needs that answer.

## Scope

In:
- Finding each source's guide link: the one the user entered, else the playlist's own, else the one an Xtream provider offers for the user's login.
- Downloading guides one source at a time, including gzip-compressed ones (a common compression format), with progress the screens can show.
- Matching programmes to channels within each source.
- Answering what is on now, what is next, what is on in a time window, and how far ahead the guide reaches.
- A guide state per channel that screens can show: loading, has a guide, no data, unavailable, failed.
- Refreshing when the guide on this device is more than 12 hours old, and on request.
- Removing a source's guide when the source is deleted.
- A size limit so a huge guide cannot exhaust memory.
- Keeping logins out of logs and file names.

Out (explicitly):
- Where the guide is stored between launches (the follow-up ADR).
- Syncing the guide through iCloud: each device downloads its own (ADR-0002).
- More than one guide per playlist, choosing a guide, and matching a channel to the guide by hand (0021).
- Programme artwork and details beyond what the parser reads.
- Reminders, recording and catch-up windows.
- Drawing anything.

## User flow

None. Screens ask for guide data; the user sees it through them.

## Acceptance criteria

### AC-1 Find each source's guide
Given a source
When the app works out where its guide lives
Then it uses the guide link the user entered, else for a playlist the first guide link the playlist names, else for an Xtream source the provider's guide link built from the user's login; a playlist with no guide link and a Stalker portal (a provider type with its own login) without one have no guide; working this out sends nothing over the network.

### AC-1a Login not on this device
Given an Xtream source with no guide link of its own, whose login has not reached this device or cannot be read
When its guide is due to load
Then nothing is downloaded, the caller hears once that the login is missing or unreadable, and its channels report the guide as unavailable while the login is missing, or failed when it cannot be read; when the login arrives, the guide loads at the next refresh trigger (AC-13) without the user doing anything.

### AC-2 Programmes land on the right channels
Given a channel and a programme whose guide ids differ only by spaces around them, a channel with no guide id, and two sources whose guides both use the id "one"
When the guide and the channel list have both loaded, in either order
Then the first channel gets its programme, with ids otherwise matched exactly including case, and each source's channels get programmes only from that source's guide.

### AC-4 What is on now and next
Given programmes 20:00 to 22:00, 22:00 to 23:00 and 23:15 to 00:00 on one channel
When a caller asks what is on at 21:34 and at 22:00, and for the next three from 22:00
Then 21:34 gives the 20:00 programme, 22:00 gives the 22:00 programme (a programme starts on its start time and is over at its stop time), a time with nothing on gives nothing, and the next three are the 22:00 and 23:15 programmes in order.

### AC-7 Programmes in a time window
Given programmes on a channel with a gap between two of them, some overlapping, and one that ends as it starts
When a caller asks for 20:00 to 22:00, or how far the guide reaches
Then it gets every programme that overlaps the window, in start order, with the gap left empty; where two overlap the later one wins and the earlier is cut short, never split; the reach runs from the earliest start to the latest stop across all sources.

### AC-9 Progress a screen can show
Given guides loading
When a caller listens for progress
Then it hears how many bytes have arrived (and the total, when known) as the download runs, then for each source the channels that have a guide, the channels in total, the number of days covered and the programmes left unmatched, or why the load failed; a caller that starts listening late first hears the latest news for each source.

### AC-11 A guide state that does not flicker
Given a source
When a caller asks for a channel's guide state
Then before the first completed download it is loading, unavailable (no guide link) or failed; after one it is "has a guide" or "no data" per channel and stays so through later refreshes, failed ones and offline included, with the previous guide still answering questions and the failure reported only through progress.

### AC-12 Failures say why
Given a guide link that answers with an error, times out, fails offline, sends a damaged or unreadable file, sends a file with no programmes, refuses the user's login, or is larger than the limit
When the guide loads
Then the caller hears the reason in those terms (server error with its code, timeout, offline, malformed, empty, unsupported, login refused, too large), a too-large download stops as soon as it crosses the limit, and other sources' guides are untouched.

### AC-13 Refreshed about twice a day
Given sources whose guide on this device is missing or more than 12 hours old, and others refreshed more recently
When the app launches, comes to the foreground, or finishes loading a source's channels
Then only the missing or stale guides download, never two at once for the same source; an explicit refresh downloads regardless of age and restarts one already running; a guide counts as fresh only if its programmes are actually on this device.

### AC-15 Logins never in the clear
Given a guide link with a username, password or token in it, in the query or before the host
When anything is logged or a file name is chosen
Then no log line or file name contains any part of the login or the full link; logs show the link with query values replaced by "…" and the login removed, plus only the source and the kind of failure.

### AC-17 Compressed guides
Given a guide sent gzip-compressed without saying so
When it loads
Then it is unpacked and gives the same programmes as the uncompressed file; anything that is neither XML nor gzip fails as unsupported.

### AC-18 Deleting a source removes its guide
Given a source whose guide is loading or has loaded
When the source is deleted on this device or through iCloud
Then any download stops, its programmes disappear from every answer, the guide's reach shrinks accordingly, its channels report unavailable, and callers hear nothing more about it.

## Edge cases

- A channel with no guide id gets no programmes and reports no data.
- A programme with no length is ignored; with no programmes from any source, the guide has no reach.
- With no sources, nothing is requested.
- A guide link changed on another device takes effect at the next refresh.
- A provider that answers with an HTML login page instead of a guide ends as "empty" or "malformed", not as a crash or a silent blank.
- A guide whose programmes are all in the past still counts as loaded; nothing is on now.
- Offline with a previous guide, screens keep showing it. Offline without one, the guide fails as offline and loads on the next foreground.
- The app suspended mid-download fails that attempt and retries on the next foreground.
- A Stalker source with its own guide link downloads it, but every programme is unmatched until it has channels.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core |
| AC-1a | integration |
| AC-2 | core + integration |
| AC-4 | core |
| AC-7 | core |
| AC-9 | integration |
| AC-11 | integration |
| AC-12 | integration |
| AC-13 | integration + ui |
| AC-15 | core + integration |
| AC-17 | core + integration |
| AC-18 | integration + device |

## Open questions

- Decided: the guide is kept in memory until the follow-up ADR. If that ADR picks a cache, it adds a criterion that a cached guide answers at launch before any refresh, through a revision of this spec.
- Decided: the 12-hour refresh interval is fixed; there is no setting.
- Decided: a broken guide is tried again on every launch and foreground, with no hold-off between attempts (AC-13).
- Decided: a source's guide loads whether or not it has channels yet (AC-13).
- A streaming XMLTV parser to lift the size limit (a 0002 follow-up). Can be decided in the plan.

## Notes for the plan

- Types other specs already code against: `GuideKey(sourceID:epgID:)`; `GuideLoadingState` `.loading`, `.loaded`, `.noData`, `.unavailable`, `.failed(GuideError)`; an immutable `Sendable` `GuideIndex`; `GuideURLResolver.resolve(kind:url:epgURL:playlistEPGURLs:credential:) -> URL?`; `GuideDecoder`; `redacted(_:)`; `GuideProgress` `.downloading`, `.loaded(channelsWithGuide:channelsTotal:days:unmatched:)`, `.failed`; `GuideError` `.httpStatus`, `.timeout`, `.offline`, `.network(URLError.Code)`, `.malformed`, `.empty`, `.unsupportedEncoding`, `.tooLarge`, `.credentialMissing`, `.credentialUnreadable`, `.unauthorized`.
- `GuideStore` (protocol in AntennaCore, `@MainActor` implementation in the app): `programmes(for:in:)`, `current(for:at:)`, `next(for:after:count:)`, `horizon`, `loadingState(for:)`, `progressStream()`, `refreshIfStale(now:)`, `refresh(sourceID:)`, `update(channels:)`, `register(epgURLs:for:)`, `remove(sourceID:)`. The loader calls `register`, then `update(channels:)`, then `refreshIfStale(now:)`. The protocol never names `SourceRecord`; the app maps records to `GuideSourceDescriptor`. Work runs off the main actor and publishes a new index in one assignment.
- Memory: budget 150 MB resident on tvOS and 400 MB elsewhere, still to be measured on device. Limits tvOS 32 MB compressed and 96 MB unpacked, elsewhere 96 MB and 256 MB, checked during gunzip too, stopping within one chunk. A parse never holds the document in memory: the entity rewrite goes to a file in pieces, the parser reads that file as a stream, and each programme goes straight into compact storage. A 95 MB guide with 538 604 programmes takes about 42 MB once loaded. The previous guide keeps answering during a refresh (AC-11), so a refresh holds two.
- Security (ADR-0003): `Channel.id` and `Channel.streamURL` never appear in a key, event, file name or log line. A thrown `URLError` is reduced to its code. Files are keyed by `sourceID`. Session: request timeout 30 s, resource timeout 600 s, no URL cache, `.reloadIgnoringLocalCacheData`, no cookies. Fetch with `URLSession.bytes(for:)`, not `XtreamClient`.
- Storage: programmes never go in the CloudKit container (ADR-0002). The per-device "last completed load" time lives outside it; `SourceRecord.lastRefreshedAt` syncs and is not it. A time without its programmes is ignored and removed. After relaunch nothing from an interrupted download is queryable, the new request has no `Range` header, and a partial cache file is deleted first.
- Join and queries: trim whitespace and newlines from both ids; start inclusive, stop exclusive; `next` returns starts at or after `after`; callers pass the current stop, or now. Overlaps: later start wins, equal starts keep the last in input order. Duplicate `Programme.id` across channels: key on `GuideKey` plus start.
- Progress: first chunk, then at most every 250 ms on an injected clock, then the final count; `expectedBytes` nil when unknown; each caller gets its own stream. `days` counts UTC calendar days from today through the latest stop on which a programme starts or is airing at 00:00 UTC. `.loaded` follows every join after a completed load, re-joins included.
- Failure mapping: offline is `.notConnectedToInternet`, `.networkConnectionLost`, `.dataNotAllowed`; 401 and 403 are `.unauthorized` only for the Xtream-login link, else `.httpStatus`; a missing credential reports `.unavailable`, an unreadable one `.failed`; a cancelled task is never reported. No reachability pre-check. Loads queue in source `sortOrder`.
- Sniffing: skip a UTF-8 BOM; first non-space `<` is XML; `1f 8b` is gunzipped and sniffed once more. Transparent `Content-Encoding: gzip` is checked by hand against a real server.
- Budget from the dropped AC-16: with 2 000 channels over seven days, "now" for 50 channels and a 2.5-hour window over 42 channels each under 10 ms, all channels over the full reach under 100 ms; with 500 000 programmes and 20 000 channels the join under 2 s on the worker and `update(channels:)` back within 5 ms on the main actor; debug `swift test`, baseline as 0013, not CI-gated.

## Dropped

- Moved to the implementation plan: AC-12a, AC-14, AC-16.
- Merged into AC-1a: AC-1b.
- Merged into AC-2: AC-3, AC-19.
- Merged into AC-4: AC-5.
- Merged into AC-7: AC-6, AC-8.
- Merged into AC-9: AC-9a, AC-10.
- Merged into AC-11: AC-11a.
- Merged into AC-12: AC-20.
- Merged into AC-13: AC-13a, AC-13b, AC-13c.
- Merged into AC-18: AC-18a.
