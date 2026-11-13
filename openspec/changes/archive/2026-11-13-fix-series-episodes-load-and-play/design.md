# Design

## Context

A series page calls `ShelfModel.info` → `ShelfLoader.info` → `XtreamClient.seriesInfo` → `decodeSeriesInfo`. Any thrown error that is not a missing login or an offline `URLError` becomes `TitleProblem.failed`, "Could not load episodes" (`TitleModel.swift`). Continue watching and the poster's Play go through `ShelfModel.loadEpisodes` and show the same words in an alert (`ShelfPlayback.Problem.episodesFailed`).

`decodeSeriesInfo` first asks `isObjectBody`, which throws `decoding(path: "")` for anything `JSONDecoder` refuses. Tried against Foundation's decoder: a UTF-8 byte-order mark decodes, but a PHP notice before the body, a Latin-1 byte, and a raw tab or line feed inside a string each fail the whole body. The list decoders also check the first byte for `[`, so a list with a byte-order mark failed.

The episode decoder tried `[Lossy<EpisodeRow>]` first. For an array of arrays that succeeds with every row nil, so the list came out empty and every season counted as skipped. PHP's `json_encode` writes an array as a JSON array only when its keys are 0, 1, 2 in order, so seasons numbered from 0 arrive that way, and a season keyed by episode number from 1 arrives as an object.

Episode links use `container_extension`, "mp4" when missing. `EngineRouter` routes `.mp4` to `AVPlayerEngine`, which probed the first bytes but only refused HTML and TS at an HLS address. Matroska or TS at an `.mp4` address reached `AVPlayer` and failed.

`XtreamClient` maps transport failures to `XtreamError.transport(code)`, so the offline check in `TitleModel`, which looked for `URLError`, never matched a panel.

No screen changes, so no board applies.

## Decisions

### Clean the body, do not swap the decoder

`XtreamBody.readable(_:)` makes one pass over the bytes. It drops a byte-order mark; when the body does not start like JSON and the text before the first `{` or `[` holds no `<html` or `<!doctype`, it starts there; it stops after the top-level value closes; it reads a byte that is not part of valid UTF-8 as Windows-1252; it escapes control characters inside strings and drops them outside. It copies nothing until the first change, so a clean body is returned as is. Every Xtream decode entry point runs it first.

Options considered:
- `JSONSerialization` with `.fragmentsAllowed` (rejected): it refuses the same bodies.
- Retry with repairs only after a decode fails (rejected): two parse attempts for every broken body, and the list decoders branch on the first byte before decoding.
- A third-party lenient JSON parser (rejected): a new dependency for four repairs.
- One pass before decoding (chosen).

Windows-1252 rather than Latin-1 because panels' plots use its curly quotes (0x92 is ’). Bytes it leaves undefined become U+FFFD.

### Season arrays and episode objects

`episodes` decodes as `[EpisodesEntry]`: an element that is an array is a season, its index the season key; any other element is an episode in a keyless group. Under a season key, `SeasonRows` takes an array, an object with an `id` as one episode, or an object of episodes visited by numeric key. Any other value still gives none and counts nothing, so the "x holding 5" scenario holds. An episode's own `season` still wins over the key.

Index as season, not index + 1: it is what PHP's array keys were. Panels that renumber seasons send `season` on each episode.

### Hand the stream to the demuxer

`StreamSniff` gains `.matroska` (EBML magic `1A 45 DF A3`) and `.avi` (`RIFF....AVI `), and `needsDemuxer` for those and `.mpegTS`. `AVPlayerEngine.open` throws `EngineHandoff.toDemuxer` when the probe says so; `AVPlayerEngine.load` closes and goes idle; `RoutedEngine.load` loads the same address on the demuxer, the mirror of `toSystemPlayer`. `DemuxRun.prepare` lists the new cases with `.mpegTS`.

Options considered:
- Ask `get_vod_info`-style per episode for the real extension (rejected): an extra request per play, and panels that lie in the list lie there too.
- Route every series episode to the demuxer (rejected): Apple's player handles mp4 better on Apple TV (frame-rate matching, Atmos passthrough).
- Probe and hand off (chosen): the probe already runs, one more check.

### Reason in the log

`LoadFailureReason.text(for:)` in AntennaCore turns an error into "status 503", "transport -1001", "decoding at episodes.1[0].id", "decoding body", "unauthorized" or the error's type name. `TitleModel.logger` (subsystem `se.codecrave.antenna`, category `titles`) logs it in public for a failed info call, a failed episode list from Continue watching, and an episode with no playable address. None of these holds a URL, login or body. `LoadFailureReason.isOffline` treats `XtreamError.transport` with an offline code like the `URLError` it came from.

### Playlist series after a reload

`ShelfLoader.playlistSeriesInfo` loads the playlist once more when the kept load has no series with that id, then fails with `unknownTitle` as before.

### Left as is

- Title ids for hosts with ports: `XtreamTitleID` uses `URL.host()`, without the port, and parses back. Covered by `xtream-vod-client/ids-are-stable`.
- Timeouts: panels answer `get_series_info` on `URLSession.shared`, 60 seconds per request. Retry on the page asks again.

## Platforms

All changes are in AntennaCore and `Apps/Shared`, so iPhone, iPad, Mac and Apple TV get them alike. The handoff runs in `AVPlayerEngine`, which every platform uses for files.
