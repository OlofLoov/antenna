## Context

No board. The shipped UI predates the design boards; the boarded Settings is `add-sources-and-settings`, the add flow `add-first-run-onboarding`, and Live `add-live-tv-on-iphone-ipad-mac`. No design-system requirement applies.

Accessibility identifiers the UI tests use: `settings.addSource`, `settings.source.<id>`, `addSource.save`, `addSource.error`, `channels.emptyState`, `player.view`.

On tvOS the add form is the same, driven by the remote and on-screen keyboard, with Save and Cancel as toolbar items. Deleting a source has no affordance on tvOS or macOS. Source rows are not focusable on tvOS; only the Add source button is, so a long list cannot be scrolled.

## Goals / Non-Goals

**Goals:**
- A test for every on-screen source-management behavior.

**Non-Goals:**
- Redesigning Settings or the channel list; the boarded versions belong to other changes.

## Decisions

- The sheet and empty-state checks are UI tests against the identifiers above. The save path and the zero-request check already pass as integration tests under `source-management`.
- Sync between devices is a manual two-device check; CloudKit cannot run in CI.
- The player check is a UI test that the player view is pushed, plus a manual check of the current item's URL until `PlayerView` exposes its player.
- The player uses `AVPlayer` for every URL as a stopgap. The project rule is two playback paths: HLS and containers the system can demux play through `AVPlayer`, and raw MPEG-TS plays through FFmpeg demux, VideoToolbox decode and `AVSampleBufferVideoRenderer`, so HDR, Dolby Vision, Atmos and frame-rate matching keep working. A playback change replaces the stopgap.

## Risks / Trade-offs

- Equal sort orders, from two devices adding at once, render in undefined order.
- Open question: delete affordance on tvOS and macOS.
- Open question: on the tvOS add sheet, where does initial focus land, and does Menu dismiss without saving? Not checked against a build.
