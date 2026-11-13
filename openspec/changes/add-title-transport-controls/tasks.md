# Tasks

## 1. Engines

- [ ] 1.1 `Demuxer` measures the length of a film whose header has none (MPEG-TS) from its two ends, when `DemuxRun` asks for it on non-live loads
- [ ] 1.2 AntennaDemux test: a `.ts` film resumes at its saved time, reports its length and skips

## 2. Core

- [ ] 2.1 `TitleTimeline`: skips clamped to the start and the end, bar fraction and time, Apple TV slide span, elapsed, remaining and spoken text
- [ ] 2.2 `PositionSaving.moved(to:at:)` saves a skip or scrub at once
- [ ] 2.3 Tests for both

## 3. App

- [ ] 3.1 `TitleTransport` per title: position, state, pending skip, drag or slide target, notice, show and hide
- [ ] 3.2 `ShelfPlayback.seek(to:)`: seek, or load again for an ended title; save the new place; report a refusal
- [ ] 3.3 `Transport` components: the Apple TV bar with its target, the iPhone, iPad and Mac controls with the system slider, the notice; previews on each platform
- [ ] 3.4 `TitleRemote` on Apple TV: arrow clicks and touch-surface slides from window recognizers
- [ ] 3.5 `ShelfPlayerView`: the Apple TV layer (select, play/pause, Menu, hold select) and the touch layer (tap, double tap, hover, keys)
- [ ] 3.6 Scripted UI-testing engine seeks and reports `shelf.debug.position`
- [ ] 3.7 Unit tests for `TitleTransport` and `ShelfPlayback.seek(to:)`
- [ ] 3.8 A failed load or a failed state shows the player error with Try again and Back on every platform, with a unit test
- [ ] 3.9 UI tests in `ShelfPlayerUITests` and `ShelfTVUITests` for skips, the scrubber and select

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 4.2 `/opsx:verify` passes
