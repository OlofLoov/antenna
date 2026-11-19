# Proposal

## Why

> As a viewer in Stockholm, Madrid, São Paulo or Riyadh, I want Antenna in my own language, with times, dates and counts written the way my phone writes them, and in Arabic I want the screens to read from the right.

Antenna is English only today. Every word is an English literal in a SwiftUI view or in an AntennaCore text helper such as `GuideSourcesText` or `SetupText`, and there is no String Catalog. A household setter-upper who hands an Apple TV to a parent should not have to explain English menus. After this change the app follows the device or per-app language in seven languages, and Arabic gets a mirrored layout.

## What Changes

- String Catalogs for the app on iPhone, iPad, Mac and Apple TV, for AntennaCore's text helpers, for the permission text in Info.plist, for the Top Shelf extension, and for Siri and Shortcuts phrases. English is the development language.
- Six translations: Swedish, German, Spanish, French, Portuguese (Brazil) and Arabic. The first pass is machine translation by the model; each language then gets a native-speaker review, and a release build leaves the language out until that review is done.
- Counts (channels, programmes, days, minutes, episodes) use plural rules per language from the catalog, so Arabic gets its six plural forms and Swedish its two.
- Times, dates, durations, file sizes and numbers follow the user's locale: 24-hour clocks where the region uses them, local weekday names, and the region's digits and separators.
- Arabic mirrors the layout: lists, rows, chips, the tab bar and the player controls read from the right, progress runs from the right, and the guide's time axis runs from right to left. Swiping right on the Siri Remote moves focus to whatever is drawn to the right.
- Text the user or the provider supplies (channel names, programme titles, group names, plot text) is shown as it arrives, never translated, and keeps its own direction inside a mirrored screen.
- A CI check that fails when the app has a string in the catalog with a missing translation, plus a rule in `scripts/check-rules.sh` against English copy stored in plain `String` constants in views and components.
- A small set of deterministic Arabic and German previews for the screens most likely to break, and one right-to-left UI smoke test per platform. Every other UI test runs in English.

Out of scope:
- Translating the website under `Web/` (setup page, Terms of Use, Privacy Policy). The paywall links stay on the English pages.
- App Store metadata and localized screenshots. A later change, building on `add-app-screenshots-ci`, localizes the subtitle, description, keywords and screenshots per language.
- Translating channel names, programme titles, plots or any provider data, and choosing guide data by language.
- Hebrew, Persian, Urdu and other languages beyond the seven named above. The setup makes adding one a catalog edit plus review.
- An in-app language picker. iOS, iPadOS, macOS and tvOS already offer a per-app language in Settings.
- Portuguese (Portugal) as its own translation; Portuguese speakers in Portugal get the Brazilian text.

## Capabilities

### New Capabilities
- `localization`: which languages the app ships in, how its own words, plurals, times, dates and numbers follow the user's language and region, how provider text is left alone, and how missing translations are caught.

### Modified Capabilities
- `design-system`: adds rules for right-to-left mirroring (layout, progress, the guide's time axis, player controls, focus movement on Apple TV) and for copy that must fit when a translation runs longer than English.

## Impact

- Platforms: iOS, iPadOS, macOS and tvOS, plus the Top Shelf extension and App Intents on iPhone, iPad and Mac.
- Code: every screen and component in `Apps/Shared`, the text helpers in AntennaCore (`*Text.swift`, `PaywallCopy`, `FailureMessage`, `TrackName`, `ConnectFailure`, the synthetic group names), `project.yml` (known regions, catalogs, string extraction), `Package.swift` for AntennaCore (default localization and the catalog resource), `scripts/check-rules.sh`, the CI workflow, and the UI test launch arguments.
- Tests: AntennaCore tests that compare English text pin an English locale. The preview set grows by about 16.
- Boards: no new boards. The design-system reference gains a right-to-left section, and the boards for the guide grid, the Live list, the player and the zap bar get an RTL note (see design.md).
- Depends on: the screens as they stand on main, including `add-app-intents` and `add-top-shelf`. Changes that land after this one add their strings to the catalog in the same PR.
- Blocked on: native speakers for the six review tasks. The translations can merge before review; a release build leaves out each language until its review is done.
