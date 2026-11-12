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

## Implementation decisions

The screens these tasks test have been replaced, so the tasks are left open and no test is written against the old screens. The behavior each one covered is proven where the newer change shows it.

- 1.1 Invalid URL keeps the sheet open: the add-source sheet is now onboarding's form (`add-first-run-onboarding`). A link without a scheme shows "Enter a valid URL." under the form, saves nothing and keeps the form open: `OnboardingConnectTests.formMistakes` (first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting) and `OnboardingUITests.testConnectWithAnEmptyFieldSaysWhatToFix`. The `addSource.save` and `addSource.error` identifiers no longer exist.
- 1.2 No sources shows the empty state: with no source the app opens on onboarding's welcome screen instead (first-run-onboarding/a-new-user-is-asked-for-a-provider), and deleting the last source returns there (`SettingsUITests.testDeletingEverySourceReturnsToOnboarding`, sources-and-settings/delete-a-source-and-everything-that-came-with-it). `channels.emptyState` is no longer reached without a source.
- 1.3 Settings lists sources in order: the order is proven by `SourcesSettingsTests.reorder` (sources-and-settings/put-sources-in-your-order). The requirement's "each row showing the source's name and URL" contradicts `add-sources-and-settings`, whose rows never show a link (sources-and-settings/see-how-each-source-is-doing, `SettingsUITests.testEachSourceShowsItsStatusAndNoLink`). The newer change wins; this requirement should drop the URL or be removed when the change is next revised.
- 1.4 Tapping a channel starts playback: `ChannelsView` and the pushed `PlayerView` are gone. Live plays the channel in place on iPhone, iPad and Mac and full screen on Apple TV (live-tv-on-iphone-ipad-mac capability, `LiveUITests`; tvos-shell capability). The player no longer uses `AVPlayer` for every URL.
- 2.1 Sources sync between devices stays open: it needs two devices signed in to one iCloud account, and CloudKit does not sync on a simulator.

