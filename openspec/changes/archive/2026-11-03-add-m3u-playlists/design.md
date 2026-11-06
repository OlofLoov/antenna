## Context

Pure parsing in AntennaCore with no UI, so no board or design-system requirement applies. Follows decision adr-0005 (AntennaCore is UI-free). Runs on iOS, iPadOS, macOS and tvOS.

## Goals / Non-Goals

**Goals:**
- One pass over the text that tolerates the attribute and group variants providers emit.
- Ids that stay the same for byte-identical input.

**Non-Goals:**
- Fetching, decompressing or deduplicating playlists.
- Honoring per-stream user agent or referrer headers.

## Decisions

- Ids use `tvg-id` and the stream URL when `tvg-id` is present. Without it the id is positional, `m3u#<url>#<n>`, with `n` 1-based. Positional ids are stable only for byte-identical input; the `favorites` capability must not rely on them.
- The attribute block ends at the first unquoted comma, so an `#EXTINF` without a comma gives an empty name and no attributes.
- Catch-up precedence: `catchup` decides the flag over `tvg-rec`, and `catchup-days` decides the days over `tvg-rec`.
- Stream and guide links go through Foundation's lenient URL parsing, so junk text becomes a relative URL rather than an error. No scheme check at parse time.
- The 50,000-entry benchmark runs only with `ANTENNA_BENCHMARKS=1`. It took 1.2 s on an Apple M1.

## Risks / Trade-offs

- Two entries with the same `tvg-id` and URL get the same id and collide in identity-keyed lists.
- Open question: should `#EXTVLCOPT` user agent and referrer be honored when fetching the stream? Many providers require it. It needs its own spec and a playback-engine hook.
- Open question: should duplicate URLs be collapsed at parse time or in the app layer?
