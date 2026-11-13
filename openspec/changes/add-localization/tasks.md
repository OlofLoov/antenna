# Tasks

## 1. Catalog setup, checks and English test runs (PR 1)

- [ ] 1.1 Set `developmentLanguage: en`, `SWIFT_EMIT_LOC_STRINGS` and `LOCALIZATION_PREFERS_STRING_CATALOGS` in `project.yml`, add empty `Localizable.xcstrings`, `InfoPlist.xcstrings` and `Intents/AppShortcuts.xcstrings` under `Apps/Shared`, and verify both app targets and the Top Shelf extension build and the catalogs fill with the English literals, Intents titles, Siri phrases and the local network reason
- [ ] 1.2 Add `scripts/check-translations.sh` for missing, incomplete-plural and stale entries, run it from `scripts/fast-checks.sh` and the Repo rules job, and verify it fails on a fixture catalog with a missing Arabic plural form
- [ ] 1.3 Add the export check to the Build apps job (`xcodebuild -exportLocalizations` for both schemes, fail on strings missing from the catalogs), and verify it fails on a branch with a literal added without a catalog sync
- [ ] 1.4 Add the three `localization:` rules to `scripts/check-rules.sh`, replace the `chevron.left`/`chevron.right`/`arrow.*` symbols they find with `backward`/`forward` names, and verify the script passes
- [ ] 1.5 Add `scripts/strip-unreviewed-languages.sh` as a Release-only run-script phase on both app targets with an empty `Config/reviewed-languages`, and verify a Release build with a test `sv.lproj` ends up without it while a Debug build keeps it
- [ ] 1.6 Add the shared launch helper that pins `-AppleLanguages (en) -AppleLocale en_US` to `Apps/UITests` and `Apps/TVUITests`, move every UI test class onto it, and verify the UI test classes that touch Live and the guide pass on a simulator set to Swedish

## 2. App strings (PR 2)

- [ ] 2.1 Prove with an Arabic preview that `Text(LocalizedStringResource)` follows `.environment(\.locale)`, and record the result in design.md
- [ ] 2.2 Change component parameters that carry app copy from `String` to `LocalizedStringResource` and keep source-data parameters as `String`, component folder by component folder, and add the rule to the `swiftui-composition` skill
- [ ] 2.3 Give `GuideText` and `LiveModel+Text` an app-side `Words` over `Bundle.main` that takes the environment locale, and verify their unit tests with an explicit English locale
- [ ] 2.4 Sync the catalog, check that no English copy is left outside it with the export check and the `localization:` rules, and verify every preview still renders the same English text in CI

## 3. AntennaCore strings (PR 3)

- [ ] 3.1 Add `defaultLocalization: "en"` and `Resources/Localizable.xcstrings` to AntennaCore, add `Words` with first-strong isolates around source text, and verify with tests that an explicit locale picks its table and that `swift test` compiles the catalog under the Command Line Tools toolchain (record the result in design.md)
- [ ] 3.2 Convert the guide and guide-sources helpers (`GuideSourcesText`, `GuideSourcesText+Reasons`, `GuideGridText`, `LiveNowText`, `GuideNowPlaying`, `GuideLine`) to whole-sentence entries with plural variations, and verify their tests with `en_US` pinned
- [ ] 3.3 Convert onboarding, import, setup and source status (`SetupText`, `ImportText`, `ConnectFailure`, `SourceStatus`, `PaywallCopy`, `UnlockGate`), and verify their tests
- [ ] 3.4 Convert player, zap bar, timeshift, multi-view, search, shelf, reminders, Top Shelf and intents replies (`ZapBarText`, `TimeshiftText`, `MultiViewFailureText`, `FailureMessage`, `TrackMenu`, `TrackName`, `SubtitleText`, `SearchText`, `ShelfText`, `ShelfCaptions`, `ReminderText`, `TopShelfContent`, `IntentReply`), and verify their tests
- [ ] 3.5 Localize the built-in group names (Favorites, All channels, Ungrouped) at display time, and verify a test that switching the locale renames them and that no SwiftData record stores them (localization/built-in-names-follow-the-language)
- [ ] 3.6 Pass `@Environment(\.locale)` from every view that calls a Core text helper, and verify the iOS and tvOS builds and the previews

## 4. Numbers, dates and durations (PR 4)

- [ ] 4.1 Format channel numbers without grouping in the locale's digits, and make the tvOS number pad map keys to values, and verify Core tests and `ZapBarUITests` in English (localization/numbers-use-the-region-s-digits-and-separators)
- [ ] 4.2 Move every clock time, weekday, date and relative day to `Date.FormatStyle` with the locale, calendar and guide time zone, make "Today", "Tomorrow" and "Now" catalog entries, and verify Core tests for 24-hour Swedish and 12-hour German (localization/times-and-dates-follow-the-user-s-region)
- [ ] 4.3 Move runtimes, time left, skip amounts and reminder lead times to `Duration.UnitsFormatStyle` or plural entries, and verify Core tests in Spanish and German (localization/durations-follow-the-user-s-language)

## 5. Swedish (PR 5)

- [ ] 5.1 Add `sv` to the project and translate every catalog, plural forms and Siri phrases included, with each string marked `needs_review`
- [ ] 5.2 Add Core tests for one Swedish plural, one count and one 24-hour time, and verify `scripts/check-translations.sh` passes

## 6. German (PR 6)

- [ ] 6.1 Add `de` and translate every catalog as `needs_review`
- [ ] 6.2 Add `.previewLanguage(.german)` in `Apps/Shared/Debug` and the six German previews named in design.md, fix any copy that truncates, and verify the CI preview PNGs (design-system/copy-fits-in-every-language)
- [ ] 6.3 Add Core tests for a German count with grouping ("12.500") and a plural, and verify the translation check passes

## 7. Spanish (PR 7)

- [ ] 7.1 Add `es` and translate every catalog as `needs_review`
- [ ] 7.2 Add Core tests for a Spanish plural and a duration, and verify on a simulator set to Spanish (Mexico) that the app shows the `es` text

## 8. French (PR 8)

- [ ] 8.1 Add `fr` and translate every catalog as `needs_review`
- [ ] 8.2 Add Core tests for a French plural and the day chips, and verify the translation check passes

## 9. Portuguese, Brazil (PR 9)

- [ ] 9.1 Add `pt-BR` and translate every catalog as `needs_review`
- [ ] 9.2 Verify on a simulator set to Portuguese (Portugal) that the app shows the Brazilian text, and record the result in design.md (localization/the-app-speaks-the-user-s-language)

## 10. Arabic text (PR 10)

- [ ] 10.1 Add `ar` and translate every catalog with all six plural forms as `needs_review`
- [ ] 10.2 Add Core tests for the Arabic zero, two, few and many forms, Arabic-Indic digits under `ar_SA`, and a Latin title isolated inside an Arabic sentence (localization/counts-use-the-language-s-plural-forms, localization/mixed-scripts-keep-their-own-direction)

## 11. Right-to-left layout (PR 11)

- [ ] 11.1 Draw the four Arabic boards listed under Not drawn on the canvas and export them as `*-RTL` boards before this PR opens
- [ ] 11.2 Rebuild guide block placement in `GuideBlocks` and `GuideScrollGrid` on leading padding instead of `.offset(x:)`, and verify the Arabic guide previews on iPhone and Apple TV (design-system/the-guide-s-time-axis-follows-the-reading-direction)
- [ ] 11.3 Route scrubber and timeshift drags and tvOS `onMoveCommand` left and right through `layoutDirection`, audit the other `.offset(x:)` and `.position` uses listed in design.md, and verify `TimeshiftUITests` in English
- [ ] 11.4 Add `.previewLanguage(.arabic)` and the ten Arabic previews named in design.md, and fix what they show
- [ ] 11.5 Add `LocalizationRTLUITests` on iPhone and `LocalizationRTLTVUITests` on Apple TV, and verify both on local simulators (design-system/layouts-mirror-in-right-to-left-languages, design-system/focus-moves-where-the-remote-points, design-system/playback-glyphs-keep-their-meaning)
- [ ] 11.6 Add the "Right to left" section to the design-system reference and an RTL note on each board named in design.md

## 12. Native-speaker review (one small PR per language)

- [ ] 12.1 Swedish reviewed: strings moved to `translated`, `sv` added to `Config/reviewed-languages`
- [ ] 12.2 German reviewed, `de` added to `Config/reviewed-languages`
- [ ] 12.3 Spanish reviewed, `es` added to `Config/reviewed-languages`
- [ ] 12.4 French reviewed, `fr` added to `Config/reviewed-languages`
- [ ] 12.5 Portuguese (Brazil) reviewed, `pt-BR` added to `Config/reviewed-languages`
- [ ] 12.6 Arabic reviewed, including the guide and scrubber direction, `ar` added to `Config/reviewed-languages`

## 13. Verify

- [ ] 13.1 Each requirement has a test citing `localization/<requirement-slug>` or `design-system/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 13.2 `/opsx:verify` passes

## Workflow follow-up

- Archive the change in PR 11, with the review tasks in group 12 carried as open items in the archive note, or in the last review PR if every language is reviewed by then.
- Propose the App Store metadata change after `add-app-screenshots-ci` lands.
