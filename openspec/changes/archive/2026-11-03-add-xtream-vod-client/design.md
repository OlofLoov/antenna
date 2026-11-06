## Context

No board and no UI; rendered by `add-movies-and-series-browsing` and `add-search`. No design-system requirement applies. Follows decision adr-0003 (credentials in iCloud Keychain) and decision adr-0005 (AntennaCore is UI-free). Runs on iOS, iPadOS, macOS and tvOS.

## Goals / Non-Goals

**Goals:**
- Never trap on any provider response.
- No credential or URL in any error or client value.

**Non-Goals:**
- Paging very large unfiltered lists, and honoring `direct_source`.

## Decisions

- Calls: `vodCategories()`, `vodStreams(categoryID:)`, `vodInfo(streamID:)`, `seriesCategories()`, `series(categoryID:)`, `seriesInfo(seriesID:)`. Categories reuse `XtreamCategory`.
- Decode functions: `decodeVODList(_:host:) -> DecodedList<VODItem>`, `decodeSeriesList(_:host:) -> DecodedList<Series>`, `decodeVODInfo(_:host:) -> VODInfo`, `decodeSeriesInfo(_:host:) -> SeriesInfo`. Each call composes request and decode.
- `XtreamError` and `DecodedList` are nested in `XtreamClient`. `VODItem`, `VODInfo`, `Series`, `SeriesInfo`, `Episode` and `XtreamTitleID` are top-level. All model types are `Sendable` and `Hashable`; `VODItem`, `Series` and `Episode` are `Identifiable` with `id: String`. `XtreamError` stays `Sendable`; `decoding` stores the joined coding path only.
- `XtreamAccountInfo.UserInfo` gains `auth: Int?`, decoded loosely.
- The client percent-encodes credentials itself, because `URLQueryItem` leaves `+` literal, `appending(path:)` splits on `/`, and `appending(component:)` encodes it.
- The `auth` probe runs only when the body's first non-whitespace byte is `{`, before any list or info decoding.
- Episodes keyed by season are visited by numeric key ascending, then non-numeric keys by name, since JSON object key order is not kept. That order settles sort ties and the first occurrence of a duplicate across seasons.
- Ids are never built from stream-URL-like fields; `direct_source` is ignored and links are always built from the server, credentials and id.
- `vodStreams(categoryID: nil)` and `series(categoryID: nil)` stay available because onboarding counts movies and series from them.
- Fixtures under `Tests/AntennaCoreTests/Fixtures/Xtream/` cover every endpoint, including broken-row, duplicate-row, duplicate-episode, array-episodes, empty-`info`, `{}`, `false`, `null` and HTML-body variants. The 50,000-row body is generated at test time, and its benchmark runs only with `ANTENNA_BENCHMARKS=1`.
- Supersedes parts of `xtream-live-source`: 401 and 403 become `unauthorized`, `DecodingError` becomes `decoding(path:)`, `URLError` becomes `transport(code)`, credential encoding applies to every URL, integers no longer truncate, and broken live rows are skipped instead of failing the list.

## Risks / Trade-offs

- Host-only ids collide for two panels on one host with different ports. Accepted, as in `xtream-live-source`.
- Open question: should `vodStreams(categoryID: nil)` page through categories for providers whose unfiltered list runs to tens of megabytes? Any answer must keep an unfiltered count path for onboarding.
- Open question: do some providers require `direct_source` instead of the `/movie/` and `/series/` link shape?
