## Context

Pure parsing in AntennaCore with no UI, so no board or design-system requirement applies. Follows decision adr-0005 (AntennaCore is UI-free). Runs on iOS, iPadOS, macOS and tvOS.

## Goals / Non-Goals

**Goals:**
- One `XMLParser` pass with no DOM.
- Typed errors only; no `NSError` reaches the caller.

**Non-Goals:**
- Streaming from disk or bounding peak memory; the input bytes and the full result stay in memory.
- Language selection among repeated elements.

## Decisions

- The first non-empty `title`, `sub-title`, `desc` and `category` wins, but the first `<display-name>` wins even when empty. The owner chose to keep that difference.
- Namespaces are disabled, so prefixed element names are not matched.
- Offsets `±HHMM` and `±HH:MM` are applied when the hours are at most 14; any other suffix is ignored and the first 14 characters are read as UTC.
- A pre-pass rewrites a stray `&` to `&amp;` and HTML named entities to their characters before `XMLParser` sees the document. CDATA, comments, processing instructions and the DOCTYPE are not rewritten. Documents that declare entities or start with a UTF-16 byte order mark skip the pre-pass. When it rewrites anything, the copy and the input are both held, so the input's share of peak memory doubles.
- `Programme.id` is channel plus start, so it collides for two programmes with equal channel and start.
- The 100,000-programme benchmark runs only with `ANTENNA_BENCHMARKS=1`, at about 15 s on an Apple M1 in both debug and release, since the time is spent inside `XMLParser`.

## Risks / Trade-offs

- Peak memory for a 50 MB file and parse time on tvOS cannot be checked in CI. Check on device when the guide ships.
- Open question: language preference for repeated elements, device locale or first in file?
- Open question: should `Programme.id` include the stop time to avoid collisions when a provider emits two programmes with the same start on one channel?
