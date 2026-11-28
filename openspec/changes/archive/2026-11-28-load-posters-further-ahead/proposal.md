# Proposal

## Why

> As a viewer on Apple TV with a big Xtream catalogue, I want the posters of the rows and columns I move into to be there when the highlight gets there, so browsing Movies and Series does not show posters popping in.

On the owner's Apple TV, posters and titles showed late as the highlight moved through Movies and Series. The owner asked for more to be loaded ahead, and accepts it is a balance against memory. What loads ahead today (`expand-focused-title-on-apple-tv`, decisions 4 and 5) was tuned against a fixture server that answers in a tenth of a second. A provider's poster host is slower, and on a simulator with posters that take half a second, a first walk six rows down and up found 28 of 112 cards still loading.

Three things leave the highlight ahead of its posters:

- The rows by the highlight load the posters around its column only one row above and one below, so two quick presses down reach a row nothing loaded around the column.
- Every poster asked for ahead starts downloading at once. With 30 or more asked for in a move, a card on screen waits behind them for one of the 4 connections the shared session opens to a host.
- Each new highlight position stops what the last one asked for and asks again, so a poster both positions want is dropped mid-download and starts over.

## What Changes

- Along a row, the next 6 posters in the direction of travel load ahead, not 3. When a row shows, the next 2 rows in the direction of the scroll load their first posters, not 1.
- On Apple TV, the posters around the highlight's column load in 2 rows ahead of its last move up or down and 1 behind, nearest first, in place of 1 above and 1 below.
- Posters load through a session of their own with 6 connections to a host, as a browser opens, where the shared session opened 4. At most 5 posters load ahead at a time, so a card on screen always finds a connection free. The rest wait in line, newest first. A card on screen whose poster is in line starts it at once. A poster that leaves the line before it starts is never downloaded.
- A new highlight position replaces what the last one asked for: posters both want keep loading, the rest stop.
- Poster memory goes from 50 MB to 80 MB on every platform, so the larger window fits next to the rows on screen.

Out of scope: loading each title's details (plot, year, backdrop) ahead of the 0.8 s rest. Those come from the provider's API, one call per title, and asking for the neighbours of every position multiplies the calls a provider may limit. The decode size, the disk limit and the fade of a late poster stay as they are.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: "Browsing stays responsive" loads further ahead, gains "A slow poster host" and "The highlight moves on before the posters around it load", and its memory limit is 80 MB.

## Impact

- Platforms: the window along a row, the rows ahead of the scroll, the line, the posters' session and the 80 MB apply on iPhone, iPad, Mac and Apple TV. The rows around the highlight are Apple TV only, since only it has a highlight that moves between rows.
- Code: `PosterPrefetch` in AntennaCore (the window, `aroundHighlight`, the highlight's direction in `Trail`), `PosterCache` (`session`, `prefetchLimit`, `prefetch(replacing:)`, `memoryLimit`), the new `PosterLine`, and `PosterMemory`, `Poster` and `PosterTrace` moved out of `PosterCache.swift` into files of their own, `ShelfPrefetch.swift` and `ShelfSync.swift`. A benchmark walk on a fresh install in `ShelfLargeTVUITests`.
- Depends on `expand-focused-title-on-apple-tv` and `keep-the-gap-around-the-expanded-card`, both archived.
