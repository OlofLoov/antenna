## Context

No board and no UI. Screens in `add-first-run-onboarding`, `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-tv-guide-grid`, `add-live-tv-on-iphone-ipad-mac` and `add-search` show the progress and states this capability reports. Design-system requirement that applies: "Loading shows real progress per step". Follows decision adr-0002 (SwiftData with private CloudKit for sync), decision adr-0003 (credentials in iCloud Keychain) and decision adr-0005 (AntennaCore is UI-free). Runs on iOS, iPadOS, macOS and tvOS.

## Goals / Non-Goals

**Goals:**
- One immutable index that answers now, next, window and reach for every screen.
- Bounded memory and no credential in any log or file name.

**Non-Goals:**
- Persisting the guide between launches, syncing it, or letting the user pick guide sources.

## Decisions

- Types other changes code against: `GuideKey(sourceID:epgID:)`; `GuideLoadingState` `.loading`, `.loaded`, `.noData`, `.unavailable`, `.failed(GuideError)`; an immutable `Sendable` `GuideIndex`; `GuideURLResolver.resolve(kind:url:epgURL:playlistEPGURLs:credential:) -> URL?`; `GuideDecoder`; `redacted(_:)`; `GuideProgress` `.downloading`, `.loaded(channelsWithGuide:channelsTotal:days:unmatched:)`, `.failed`; `GuideError` `.httpStatus`, `.timeout`, `.offline`, `.network(URLError.Code)`, `.malformed`, `.empty`, `.unsupportedEncoding`, `.tooLarge`, `.credentialMissing`, `.credentialUnreadable`, `.unauthorized`.
- `GuideStore`, a protocol in AntennaCore with a `@MainActor` app implementation: `programmes(for:in:)`, `current(for:at:)`, `next(for:after:count:)`, `horizon`, `loadingState(for:)`, `progressStream()`, `refreshIfStale(now:)`, `refresh(sourceID:)`, `update(channels:)`, `register(epgURLs:for:)`, `remove(sourceID:)`. The loader calls `register`, then `update(channels:)`, then `refreshIfStale(now:)`. The protocol never names `SourceRecord`; the app maps records to `GuideSourceDescriptor`. Work runs off the main actor and publishes a new index in one assignment.
- Memory: budget 150 MB resident on tvOS and 400 MB elsewhere, still to be measured on device. Limits are 32 MB compressed and 96 MB unpacked on tvOS, 96 MB and 256 MB elsewhere, checked during gunzip and stopping within one chunk. The entity rewrite goes to a file in pieces, the parser streams that file, and each programme goes straight into compact storage. A 95 MB guide with 538,604 programmes takes about 42 MB once loaded. A refresh holds the old guide and the new one.
- Security (decision adr-0003): `Channel.id` and `Channel.streamURL` never appear in a key, event, file name or log line. A thrown `URLError` is reduced to its code. Files are keyed by `sourceID`. The session has a 30 s request timeout, a 600 s resource timeout, no URL cache, `.reloadIgnoringLocalCacheData` and no cookies. Downloads use `URLSession.bytes(for:)`, not `XtreamClient`.
- Storage: programmes never go in the CloudKit container (decision adr-0002). The per-device last-completed-load time lives outside it; `SourceRecord.lastRefreshedAt` syncs and is not that time. A time without its programmes is ignored and removed. After relaunch nothing from an interrupted download is queryable, the new request has no `Range` header, and a partial cache file is deleted first.
- Join and queries: whitespace and newlines are trimmed from both ids; start is inclusive and stop exclusive; `next` returns starts at or after `after`. Of two overlapping programmes the later start wins; equal starts keep the last in input order. Duplicate `Programme.id` across channels is keyed on `GuideKey` plus start.
- Progress: first chunk, then at most every 250 ms on an injected clock, then the final count; `expectedBytes` is nil when unknown; each caller gets its own stream. `days` counts UTC calendar days from today through the latest stop on which a programme starts or is airing at 00:00 UTC. `.loaded` follows every join after a completed load.
- Failures: offline is `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`. 401 and 403 are `.unauthorized` only for the Xtream login link, else `.httpStatus`. A missing credential reports `.unavailable`, an unreadable one `.failed`. A cancelled task is never reported. No reachability pre-check. Loads queue in source sort order.
- Sniffing: skip a UTF-8 byte order mark; the first non-space `<` means XML; `1f 8b` is gunzipped and sniffed once more. Transparent `Content-Encoding: gzip` was checked by hand against a real server.
- Performance budget: with 2,000 channels over seven days, "now" for 50 channels and a 2.5-hour window over 42 channels each under 10 ms, all channels over the full reach under 100 ms; with 500,000 programmes and 20,000 channels the join under 2 s on the worker and `update(channels:)` back within 5 ms on the main actor. Debug test run, same baseline as `channel-catalogue`, not CI-gated.
- Decided: the guide stays in memory until the follow-up decision. If that decision picks a cache, a cached guide must answer at launch before any refresh.
- Decided: the 12-hour refresh interval is fixed, with no setting.
- Decided: a broken guide is tried again on every launch and foreground, with no hold-off.
- Decided: a source's guide loads whether or not it has channels yet.

## Risks / Trade-offs

- Holding two guides during a refresh doubles the guide's share of memory.
- Open question: a streaming XMLTV parser would lift the size limit. It belongs to `xmltv-guide-parsing` and can be settled in a plan.
