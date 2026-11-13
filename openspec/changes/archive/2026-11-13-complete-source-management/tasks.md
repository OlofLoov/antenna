## 1. Covered by other changes

- [x] 1.1 A link without a scheme keeps the add-source form open with its error: `OnboardingConnectTests.formMistakes` and `OnboardingUITests.testConnectWithAnEmptyFieldSaysWhatToFix` (first-run-onboarding/mistakes-in-the-form-are-caught-before-connecting)
- [x] 1.2 No source opens onboarding, and deleting the last source returns there: `OnboardingRoutingTests.noSourceOpensOnboarding` and `OnboardingUITests.testNoSourceOpensOnTheWelcomeScreen` (first-run-onboarding/a-new-user-is-asked-for-a-provider), `SettingsUITests.testDeletingEverySourceReturnsToOnboarding` (sources-and-settings/delete-a-source-and-everything-that-came-with-it)
- [x] 1.3 Sources are listed in the user's order with no link: `SettingsUITests.testEachSourceShowsItsStatusAndNoLink` (sources-and-settings/see-how-each-source-is-doing), `SourcesSettingsTests.reorder` (sources-and-settings/put-sources-in-your-order)
- [x] 1.4 Picking a channel plays it: `LiveUITests.testPickingAChannelPlaysItInPlace` (live-tv-on-iphone-ipad-mac/watch-without-leaving-the-list), and on Apple TV `ChannelOverlayUITests.testSelectChangesChannel` (tv-channel-overlay/select-changes-channel)
- [x] 1.5 A change from another device shows up and unchanged sources do not reload: `SourceRefresherTests.syncChanges` (sources-and-settings/changes-from-other-devices-show-up-by-themselves, source-management/sources-sync-between-devices)

## 2. Device check

- [x] 2.1 Run the two-device check in design.md. The device check is in `docs/release/device-checklist.md`.

## 3. Verify

- [x] 3.1 Each requirement has a test citing `source-management/<requirement-slug>`: `SourceRefresherTests.syncChanges` cites `source-management/sources-sync-between-devices` for this device's side
- [x] 3.2 `openspec validate --all --strict` and `scripts/check-spec-refs.sh` pass
