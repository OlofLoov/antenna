# Design

## Context

Boards: no new screens. Every existing board applies in every language, and
the mirrored Arabic layout is a variant of each. The boards most likely to
break in right-to-left are named below and get an RTL note:

- `TV-Guide`, `TV-Guide-Future`, `iPad-Guide`, `iPhone-Guide`: the time axis.
- `iPhone`, `iPad`, `Main`: the Live list, channel row and group chips.
- `TV-ZapBar`, `TV-ZapBar-Timeshift`, `TV-Player`, `iPhone-Player`, `iPhone-Player-Timeshift`, `iPad-Player`: progress, scrubber and transport buttons.
- `TV-Shell-Menu`, `TV-Movies-Rows`: the tvOS tab bar and first focus.
- `iPhone-Paywall`, `TV-Paywall`, `iPhone-Onboard-2`, `iPhone-Settings-Detail`, `TV-GuideSources`: the longest English copy, checked in German.

Design-system requirements that apply: "Channel rows share one anatomy",
"A current programme always shows its progress", "Focus is the lifted white
card", "Text stays above the platform caption floor", "Targets are large
enough to hit", "Visual changes update the boards in the same change",
"Undrawn states are listed and drawn before implementation", "Accessibility
identifiers follow the board", and the six requirements this change adds.

Drawn for this change, as `*-RTL` boards next to the English ones:
- `iPhone-RTL`: the Arabic Live list on iPhone (`iPhone`), mirrored, body and caption styles unchanged.
- `TV-Guide-RTL`: the Arabic guide grid on Apple TV (`TV-Guide`), channel column at the right, time running left.
- `iPhone-Player-Timeshift-RTL`: the Arabic player strip on iPhone (`iPhone-Player-Timeshift`), skip back to the right of play.
- `TV-ZapBar-RTL`: the Arabic zap bar (`TV-ZapBar`), identity at the right, badges at the left.

They were drawn after PR 11 landed, from the app and this spec (see PR 11
under Findings). The German copy needs no board: the rule is that it fits,
and the German previews show it.

What the code does today:
- No String Catalog, no `String(localized:)` outside App Intents, and no
  `knownRegions` beyond English. `project.yml` sets English Info.plist
  values inline, including `NSLocalNetworkUsageDescription`.
- About 108 `Text("...")` literals in `Apps/Shared`. SwiftUI already treats
  those as `LocalizedStringKey`, so Xcode extracts them once extraction is on.
  About 330 `Text(someString)` calls pass a `String`, which SwiftUI shows
  verbatim and Xcode never extracts. 39 components take copy as a `String`
  parameter (`title: String`, `message: String`).
- AntennaCore builds about 1,500 lines of English in 14 `*Text.swift`
  helpers (`GuideSourcesText`, `SetupText`, `ZapBarText`, `SearchText`,
  `ReminderText` and others) plus `PaywallCopy`, `FailureMessage`,
  `ConnectFailure`, `TrackName`, `TopShelfContent` and the "Ungrouped" and
  "Favorites" names. Several already take a `Locale` and format numbers,
  dates and byte counts with it; the words are English.
- App Intents titles are `LocalizedStringResource` literals and the
  `AppShortcutsProvider` phrases are literals, so both extract once a
  catalog exists.
- Three UI test classes already pin `-AppleLanguages (en) -AppleLocale en_US`.
  The rest inherit the simulator's language.
- `Apps/Shared/Views/Guide/GuideScrollGrid.swift`,
  `Components/GuideGrid/GuideBlocks.swift`, `Components/Timeshift/Timeshift.swift`
  and about 15 other files place views with `.offset(x:)`, `.position`,
  drag `translation.width` or `onMoveCommand`, which do not mirror on their own.

## Goals / Non-Goals

**Goals:**
- One rule for where each kind of text is localized, so the next change knows where its strings go.
- Every sentence is one catalog entry with arguments, so translators can reorder words.
- Previews and AntennaCore tests can render any language deterministically, without changing the simulator's language.

**Non-Goals:**
- Localizing search matching, sorting or the M3U and XMLTV parsers. They work on source text and stay as they are.
- StoreKit product names and prices; the App Store supplies them per storefront once the metadata change adds product localizations.
- Changing any English copy. English stays the source text as agreed in each capability.

## Decisions

### Catalogs and where they live

| Catalog | Path | Holds |
|---|---|---|
| App strings | `Apps/Shared/Localizable.xcstrings` | Every literal in views, components, app models and App Intents titles, for both app targets |
| Permission text | `Apps/Shared/InfoPlist.xcstrings` | `NSLocalNetworkUsageDescription` for both app targets. `CFBundleDisplayName` stays "Antenna" in every language and is left out |
| Siri phrases | `Apps/Shared/Intents/AppShortcuts.xcstrings` | `AppShortcutsProvider` phrases. The folder is already excluded from the tvOS target |
| AntennaCore | `Packages/AntennaCore/Sources/AntennaCore/Resources/Localizable.xcstrings` | Every word the Core text helpers return. `Package.swift` sets `defaultLocalization: "en"` and processes the folder |
| Top Shelf | none of its own | The extension's titles and captions come from `TopShelfContent` in AntennaCore, so Core's catalog covers them. A catalog is added in `Apps/TopShelf` only if the extension gains its own literals |

`project.yml` sets `options.developmentLanguage: en`, and the app targets set
`SWIFT_EMIT_LOC_STRINGS: YES` and `LOCALIZATION_PREFERS_STRING_CATALOGS: YES`.
Keys are the English text, as Xcode writes them for literals, so a missing
translation falls back to readable English. Core uses explicit keys only
where two meanings share the same English ("Live" the badge and "Live" the
tab), written as `badge.live` with the English as default value.

Options considered:
- One catalog for app and Core. Rejected: Core is a separate package with
  its own resource bundle, and Xcode's extraction cannot write into a
  package's catalog from the app target.
- Legacy `.strings` and `.stringsdict` files. Rejected: the catalog holds
  plurals, device variations and review state in one file, and Xcode 26
  manages it.
- Generated symbols for manually managed strings (Xcode 26
  `STRING_CATALOG_GENERATE_SYMBOLS`). Not now: the extracted literal keys
  cover the app, and Core's helpers are already the one place each string
  is built. Revisit if key typos show up in review.

### AntennaCore localizes its own words

Options considered:
1. Core resolves with its own catalog. Each text helper takes a `Locale`
   (most already do), builds a `LocalizedStringResource` with that locale
   and `bundle: .atURL(Bundle.module.bundleURL)`, and returns `String`.
2. Core returns `LocalizedStringResource` values and SwiftUI resolves them
   with the environment. Lazy and SwiftUI-native, but every public return
   type changes, `SearchText` and `GuideSourcesText.Line` still need a
   `String` for highlight ranges and equality, and Top Shelf, notifications
   and accessibility labels resolve outside SwiftUI anyway.
3. Core returns enums and numbers, and the app owns all wording. Rejected:
   it moves about 1,500 lines of tested text logic into `Apps`, where only
   simulator tests reach it, against the rule that logic lives in Core.

Chosen: option 1. Core keeps its tested functions and gains a small internal
helper, `Words`, that holds the locale and resolves a
`String.LocalizationValue` against Core's bundle. Rules for the helpers:
- A sentence is one entry with arguments. "Loaded · %lld of %lld channels · %lld days"
  is one key with plural variations on the arguments, never three
  translated pieces joined with " · ".
- Static English constants (`GuideSourcesText.title`) become instance
  members, since a `static let` cannot know the locale.
- Every `init(locale:)` default stays `.autoupdatingCurrent`, and Core tests
  pass `Locale(identifier: "en_US")` explicitly, so a test machine in Swedish
  still sees English.
- Source text passed into a sentence (a channel name, a programme title, a
  source name) is wrapped in Unicode first-strong isolates (U+2068 and
  U+2069) by `Words`, so a Latin name inside Arabic, or an Arabic name inside
  English, keeps its own direction (localization/mixed-scripts-keep-their-own-direction).

The app side passes `@Environment(\.locale)` into each helper. In the
running app that is `Locale.autoupdatingCurrent`, which carries the per-app
language and the user's 12 or 24-hour override. In a preview it is whatever
the preview sets, which keeps previews deterministic.

The first Core PR proves two assumptions with a test before converting the
helpers: that a `LocalizedStringResource` with an explicit `locale` picks
that language's table from the package bundle, and that `swift test` with
the Command Line Tools toolchain compiles the package catalog. If the first
fails, `Words` picks the `.lproj` sub-bundle by `locale.language` itself. If
the second fails, the per-language Core tests run only in CI, which uses
Xcode's toolchain, and English tests still pass locally because the keys
are the English text.

### App strings

- Literals in `Text`, `Button`, `Label`, `navigationTitle`, `.accessibilityLabel`
  and `.help` stay literals. They are `LocalizedStringKey` and Xcode
  extracts them.
- A component parameter that carries app copy changes from `String` to
  `LocalizedStringResource`, so a literal at the call site is extracted and
  the component's `Text(title)` resolves it with the environment. A
  parameter that carries source data (channel name, group name, title)
  stays `String`, which `Text` shows verbatim. The `swiftui-composition`
  skill gains this rule.
- App models that build sentences (`GuideText`, `LiveModel+Text`) follow
  Core: they take the environment locale and return `String` through the
  app's own `Words` twin over `Bundle.main`.
- Built-in group names come from one place per side: `Catalogue` group
  cases map to a localized name in Core, and nothing stores the English
  name in SwiftData, so a language change renames them on every device.

Options considered for component parameters: `LocalizedStringKey` (SwiftUI
only, not `Equatable`, cannot be built in a model) and `String` resolved at
the call site with `String(localized:)` (resolves with the process language,
so an Arabic preview shows English). `LocalizedStringResource` works in
models and resolves lazily in `Text`. The first app PR checks with an Arabic
preview that `Text(resource)` follows `.environment(\.locale)`; if it does
not, components resolve the resource with `String(localized:)` and the
environment locale before handing it to `Text`.

### Plurals, numbers, dates and durations

- Plurals: catalog plural variations on `%lld` arguments. Arabic fills zero,
  one, two, few, many and other; Swedish, German, Spanish, French and
  Portuguese fill one and other (Spanish, French and Portuguese also "many"
  where Xcode offers it for large round numbers).
- Counts: `%lld` resolved with the helper's locale gives that region's
  grouping and digits ("12.500" in German, Arabic-Indic digits where the
  region uses them). A Core test per language pins one example.
- Channel numbers: `number.formatted(.number.grouping(.never).locale(locale))`,
  so "1001" never becomes "1,001" and Arabic shows Arabic-Indic digits. The
  tvOS number pad shows the same digits and maps keys to values, not to
  characters (localization/numbers-use-the-region-s-digits-and-separators).
- Times and dates: `Date.FormatStyle` with the locale, the calendar and the
  guide's time zone, as `GuideDays` already does for weekday chips. No
  `DateFormatter` with a fixed `dateFormat` string remains outside the XMLTV
  and Xtream parsers, which read machine formats.
- "Today", "Tomorrow" and "Now" become catalog entries. Weekday names come
  from the format style.
- Durations: `Duration.UnitsFormatStyle` (`.units(allowed: [.hours, .minutes], width: .abbreviated)`)
  for runtimes and time left, and plural entries for phrases such as
  "starts in %lld minutes".
- Byte counts keep `.byteCount(style: .file)` with the locale.

### Languages and variants

| Language | Catalog code | Why this variant |
|---|---|---|
| English | `en` | Development language and fallback |
| Swedish | `sv` | |
| German | `de` | Also serves Austria and Switzerland |
| Spanish | `es` | One neutral Spanish for Spain and Latin America; the system falls back from `es-419` and `es-MX` to `es` |
| French | `fr` | Also serves Canada and Belgium |
| Portuguese | `pt-BR` | Brazil has about twenty times Portugal's population, and the system is expected to fall back from `pt-PT` to `pt-BR` when the app has no `pt-PT` table |
| Arabic | `ar` | Modern Standard Arabic; digits follow the user's region |

Options considered for Portuguese: `pt-PT`, both, or a bare `pt`. Both
doubles the review work for one language. A bare `pt` table leaves it
unclear which variant the text is written in, and reviewers from the two
countries disagree on spelling. `pt-BR` with fallback is chosen; a `pt-PT` table can be added later as a catalog edit.
The fallback is confirmed on a simulator set to Portuguese (Portugal) in
the Portuguese PR.

### Translation and review

1. The model translates each catalog entry, including every plural form and
   the Siri phrases, and sets each string's state to `needs_review`.
2. The language PR adds the language to the project and the Core and app
   tests for that language's plural and number examples.
3. A native speaker reviews the exported `.xcloc` for that language, the
   German or Arabic preview PNGs from CI, and a debug build on a simulator.
   Each reviewed string moves to `translated`.
4. `Config/reviewed-languages` lists the languages whose review is done, one
   code per line, empty at first. A run-script phase in the Release
   configuration, `scripts/strip-unreviewed-languages.sh`, deletes every
   `<code>.lproj` under the built app, its embedded bundles and the Top Shelf
   extension whose code is not listed, before signing. Debug builds keep every
   language so reviewers can see them
   (localization/every-language-is-complete-before-release).

Options considered for the gate: keep translations out of main until review
(rejected, it blocks the RTL work on the Arabic text), and strip any language
with a `needs_review` string (rejected, one new string after review would
drop a whole language from a release). Later changes add their strings
machine translated as `needs_review`; the release checklist reviews those
before each release.

### Checks

- `scripts/check-translations.sh`, run from `scripts/fast-checks.sh` and in
  the lint workflow: reads every `.xcstrings` file as JSON and fails when a
  key has no string unit, or an incomplete plural set, for a language in the
  project's region list, or when a key is marked `stale`. It names the key,
  the file and the language. It needs no Xcode.
- In the "Build apps" CI job, after the iOS build:
  `xcodebuild -exportLocalizations` for the iOS and tvOS schemes, then a
  script that fails when the export has a string missing from the catalogs.
  This catches a literal added in code without a catalog sync, which the
  JSON check cannot see.
- `scripts/check-rules.sh` gains:
  - "localization: copy in views and components is not a plain String
    constant", matching `static let <name> = "<Capitalized words>` and
    `: String = "<Capitalized words>` in `Apps/Shared/Views` and
    `Apps/Shared/Components`, except `Apps/Shared/Debug` and `#Preview`
    fixture files named `*Fixtures.swift`.
  - "localization: directional symbols use backward and forward", failing on
    `chevron.left`, `chevron.right`, `arrow.left` and `arrow.right` in `Apps`,
    since `chevron.backward` and `chevron.forward` mirror on their own.
  - "localization: no fixed date format", failing on `dateFormat =` outside
    the parsers.

A complete check for hardcoded copy is not feasible: a `String` variable
passed to `Text` is legal for source data and identical in syntax to copy.
The rule catches the common shape (copy stored in a `String` constant) and
the export check catches literals that skipped the catalog. The rest relies
on the Arabic and German previews, where untranslated English stands out.

### Right-to-left

Research on guide and media direction:
- Apple's HIG (Right to left, Controls) says to flip controls that show
  progress from one value to another, such as sliders and progress
  indicators, and to reverse numerals that show a counting direction while
  never reversing the digits in a number. Back and next controls flip.
- Material Design's bidirectionality page says media playback controls and
  the media progress indicator are not mirrored, because they follow the
  direction of the tape. VLC's Android player and the Windows Media Player
  control bar keep left-to-right.
- Browser engines (WebKit, Blink, Gecko) reverse range and progress
  controls in right-to-left text.

Options considered for the guide's time axis:
1. Keep time running left to right inside a mirrored screen, as Material
   advises for media. The channel column would sit at the right with time
   flowing away from it toward the right edge, or the column would stay at
   the left in an otherwise mirrored screen.
2. Mirror it: channel column at the right, time running to the left.

Chosen: option 2. Antenna is an Apple-platform app and follows the HIG. The
channel row's progress bar flips under the same HIG rule, and a row that
fills from the right next to a guide that runs to the right would disagree
on the same screen. The scrubber flips for the same reason. Transport glyphs
do not: the play triangle keeps pointing right, and skip back and forward
swap sides with the layout. The Arabic reviewer confirms the guide and
scrubber direction on the RTL previews; if they object, only the guide and
scrubber code paths change, and the specs' RTL requirements are amended.

Implementation rules:
- Use `leading` and `trailing` everywhere. Place guide blocks with leading
  padding inside a leading-aligned stack instead of `.offset(x:)` or
  `.position(x:)`, which do not mirror. Core's guide geometry stays in
  leading-edge points.
- Drag gestures on the scrubber and the timeshift bar convert
  `translation.width` through `layoutDirection`, so dragging toward the
  trailing edge always moves forward.
- `onMoveCommand` handlers on tvOS map `.left` and `.right` to "earlier" and
  "later" through `layoutDirection`. The focus engine itself is spatial, so
  plain focus movement needs no change, and default focus lands top-leading,
  which is top-right in Arabic.
- Directional symbols use `.backward` and `.forward` names. `gobackward.15`
  and `goforward.30` keep their glyphs and move with the layout.
- Logos, posters, artwork and the picture are never flipped. Nothing uses
  `.flipsForRightToLeftLayoutDirection(true)` except chevrons drawn as
  shapes.
- `.textCase(.uppercase)` on badges stays; it does nothing to Arabic.

The design-system reference gains a "Right to left" section with these
rules when the RTL group lands, and a note on the boards listed in Context.

### Previews

CI renders every `#Preview` (about 207 today). This change adds about 16:

- Arabic, right to left (10): Live list on iPhone, Live on iPad, channel
  overlay on Apple TV, zap bar with timeshift, guide grid on Apple TV,
  guide on iPhone, player strip on iPhone with timeshift, onboarding
  checklist, paywall on iPhone, Guide sources on iPhone.
- German (6): paywall on iPhone and Apple TV, onboarding step 2, Settings
  detail, Guide sources on Apple TV, player error on Apple TV.

Each sets `.environment(\.locale, ...)` and, for Arabic,
`.environment(\.layoutDirection, .rightToLeft)` through one modifier in
`Apps/Shared/Debug`, `.previewLanguage(.arabic)` or `.previewLanguage(.german)`,
with the same fixtures as the English preview. Names end in ", Arabic" or
", German".

Options considered: an Arabic and German variant of every preview
(rejected, it triples the PNG count to about 600 for little extra signal),
and Xcode's pseudolanguages (rejected, they are launch options for a
running app, not something a preview can set; German is the realistic
long-text check).

### UI tests

- A shared launch helper in `Apps/UITests` and `Apps/TVUITests` adds
  `-AppleLanguages (en) -AppleLocale en_US` to every test's launch
  arguments. The three classes that set it today switch to the helper.
- `LocalizationRTLUITests` on iPhone launches with `-AppleLanguages (ar)
  -AppleLocale ar_SA` and the Live fixture. It checks by identifier and
  frame that the channel number sits left of the channel name, after it in
  reading order as on the English row, that the first group chip is the
  rightmost, and that the skip back button is right of play.
- `LocalizationRTLTVUITests` on Apple TV opens the guide in Arabic, checks
  the channel column is right of the now programme, presses left and checks
  focus moved to the next programme by identifier.
- Both run in the nightly suite and locally for the RTL PR, per the UI
  tests policy.

### App Store metadata and the website

App Store metadata (subtitle, description, keywords, what's new, localized
screenshots, in-app purchase display names) is a follow-up change that
builds on `add-app-screenshots-ci`, since the screenshot run can take
`-AppleLanguages` per language. It ships per language after that language's
review. The website under `Web/` stays English: it carries legal text that
would need legal review per language, and the app links to it in one place.

## Risks / Trade-offs

- [A translated sentence breaks a UI test] → UI tests match identifiers and
  run pinned to English; the RTL tests check frames, not text.
- [Bidi isolates change Core test strings] → `Words` adds them only around
  source-text arguments; English tests compare with a test helper that
  strips U+2068 and U+2069, and one test asserts they are present.
- [Machine translation reads wrong to a native speaker] → nothing ships in
  a release until review; reviewers see real screens in the previews.
- [Strings added by parallel changes skip the catalog] → the export check
  in CI fails the PR; the change that adds a string adds its six
  translations as `needs_review`.
- [Arabic text runs taller than Latin and clips in fixed-height rows] →
  the Arabic previews show it; rows use minimum heights, not fixed ones,
  where the board allows.
- [German labels overflow tvOS buttons] → the German previews show it; a
  label wraps to two lines before it truncates.
- [Stripping `.lproj` folders in Release misses a nested bundle] → the
  script lists what it removed in the build log, and the release checklist
  opens the archive and checks the language list.

## Migration Plan

No data migration. Nothing in SwiftData or UserDefaults stores app copy;
built-in group names are derived at display time. Rollback is a revert of
the language PR, or removing a code from `Config/reviewed-languages`.

## Findings while building

PR 1, catalog setup:
- `xcodebuild build` never writes extracted strings into a catalog.
  `xcodebuild -exportLocalizations` does: it rewrites the catalogs in place
  and puts the same copies under the export's `Source Contents`. So
  `scripts/sync-strings.sh` exports and writes those catalogs back through
  `scripts/translations.py sync`, dropping stale keys and marking keys with
  no words (`%@ · %@`) and the bundle names as not translated. With
  `--check` it puts the committed catalogs back and fails when code holds a
  string they lack; the Build apps job runs that. One export builds every
  target, iOS, macOS and tvOS, so one scheme covers both apps and the Top
  Shelf extension. Strings inside `#Preview` blocks are not extracted.
- The export also writes an `InfoPlist.xcstrings` for the Top Shelf
  extension holding only the bundle names. It is left out of the repo, as
  decided above; the check fails if that catalog gains any other key.
- The languages the checks require live in `Config/languages`, one code per
  line, next to `Config/reviewed-languages`. A language PR adds its code
  there. XcodeGen has no `knownRegions` option, and the built app lists a
  language once its `.lproj` exists, which the catalog compiler writes.
- The strip phase cannot run under user script sandboxing: it must list and
  delete folders inside the built product, which a sandboxed script cannot
  read. `ENABLE_USER_SCRIPT_SANDBOXING` is off for the two app targets and
  the Top Shelf extension. The phase runs in each of the three, since the
  extension is signed before the app embeds it.
- The rule against copy in `String` constants has 25 hits on main. It warns
  in PR 1 and fails from PR 2, which moves that copy into the catalog.
- `XCUIApplication.launchInEnglish()` in `Apps/UITests/LaunchInEnglish.swift`
  is the launch helper, shared with the Apple TV UI tests and both journey
  targets. A rule in `scripts/check-rules.sh` fails on a plain `launch()` in
  any UI test folder.

PR 2, app strings:
- `Text(LocalizedStringResource)` follows `.environment(\.locale)`. Checked
  on the iPhone simulator (set to Swedish) with a temporary `ar` value for
  "Settings" and `ImageRenderer`: the resource under an `ar` environment
  drew the same pixels as the Arabic text, and under `en` the same as
  "Settings". So components keep the resource and hand it to `Text`; the
  `String(localized:)` fallback is not needed. A resource with its
  `locale` set resolves that language through `String(localized:)`, which
  is what the app's `Words` does.
- `LocalizedStringResource` is `Equatable`, `Sendable` and `Codable` but not
  `Hashable`.
- Text AntennaCore builds reaches a component parameter that also takes app
  literals as `.verbatim(text)`, a `"%@"` entry that is never translated,
  until PR 3 gives Core its own catalog.
- `LiveModel+Text` holds no words of its own: its sentences come from
  Core's `LiveNowText` (PR 3). It takes the view's locale for the times it
  writes. `GuideText` became a struct over a locale with `Words`.
- An `Int` interpolated into a catalog entry becomes `%lld` and is
  formatted with the locale, so a count of 1240 in app copy now reads
  "1,240" in English where it read "1240". Core's counts already grouped.
- Sentences the app joined from pieces (the Live failure banner, the
  delete-source message, the sign-in lines) are now one entry per shape,
  with the same English.
- Preview fixtures that feed a copy parameter outside a `#Preview` block
  are extracted like app copy, so fixture numbers and sample data go in as
  `.verbatim(...)`.
- Left for PR 3: built-in group names (`CatalogueGroup.label` feeds
  `Catalogue.label(of:)` as a `String` everywhere), Core's `ShelfStatus`
  titles, and `SourceLoader.LoadError.errorDescription`, which
  `LocalizedError` keeps a `String` and which resolves with the process
  language rather than the view's locale.

PR 3, AntennaCore strings:
- An explicit locale picks the package's table. Checked with a scratch
  package holding `sv` and `ar` entries: "12 500 kanaler" under `sv_SE`
  and the Arabic dual under `ar_SA`, with the English one and other forms
  under `en_US`. The `.lproj` fallback in `Words` is not needed.
- The catalog compiles only under Swift Build. SwiftPM's native build
  system (the default of Swift 6.3 on the CI image, and of the Command
  Line Tools) copies `Localizable.xcstrings` into the bundle as it is, so
  plural entries resolve to the bare key ("1 channels"). Swift Build, the
  default from Swift 6.4, compiles it. CI, `scripts/fast-checks.sh` and the
  commands in CLAUDE.md pass `--build-system swiftbuild`. Main CI failed on
  this for the Core PR and the fix landed right after.
- `LocalizedStringResource.bundle` cannot be set, so `Words` takes a
  `String.LocalizationValue` and builds the resource with the locale and
  `Bundle.module`. Xcode extracts those literals from the package, and the
  export in `scripts/sync-strings.sh` writes Core's catalog with the app's,
  so the existing sync and check cover it.
- English plural forms are catalog variations on the `%lld` that precedes
  the noun, so "1 channel" and "2 channels" are one entry. Sentences with
  two counts use substitutions.
- Numbers that name something rather than count it (season and episode
  numbers, HTTP status codes, a place in a list) go into a sentence as text
  without grouping, so "Season 2024" stays as it is.
- Isolates go around source text only where directions can mix: in a
  right-to-left language, or when the text holds a right-to-left letter.
  English sentences with Latin names keep their characters, so Core tests
  and UI tests that match labels need no stripping. This replaces the
  strip helper named under Risks.
- Two English words with two meanings get explicit keys: `command.back`
  for the skip-back key command ("Back" is also the remote's button), and
  `offer.days`, `offer.weeks`, `offer.months` and `offer.years`, whose one
  form leaves out the number ("First week free").
- Static copy on enums became `static func name(_ locale:)`, copy on
  structs that hold a locale became instance members, and functions gained
  a `locale:` parameter. Every default is `.autoupdatingCurrent`, which is
  the environment locale in the running app.
- Built-in group names (`CatalogueGroup.label(_:)`) moved into Core; the
  app's `label` calls it. No record stores them: groups are rebuilt from
  channels and rules on every load.
- `TrackName` defaulted to `en_US`; it now defaults to the current locale,
  so language names follow the app's language.
- Task 3.6 is left open. Every helper defaults to the current locale,
  which is what the running app shows, so only previews that set another
  locale see a difference. The views behind the German and Arabic previews
  pass `@Environment(\.locale)` in the PRs that add those previews
  (tasks 6.2 and 11.4), and 3.6 is ticked with the last of them.
- Sentences that fall back to a phrase when a name is missing ("This
  channel is already a favorite") keep the phrase as a `%@` argument, so
  a language that inflects it may need a review edit.

PR 4, numbers, dates and durations:
- `ChannelNumber.text(_:)` writes a number in the locale's digits with no
  grouping, and `ChannelNumberText` shows it in every channel row, pill,
  guide row and panel. `ChannelNumber.digit(_:)` reads a digit in any
  script, so number entry from a keyboard accepts Arabic-Indic digits and
  tunes the same channel. The number box and the passcode keys show the
  typed digits in the locale's digits; the values stay "0" to "9".
- Apple TV has no on-screen pad for channel numbers; digits come from a
  keyboard or an IR remote. The passcode pad is the only on-screen digit
  pad, and its keys send the same values in every language.
- The `DateFormatter` templates in `SearchText` and `ReminderText` became
  `Date.FormatStyle` with the locale, calendar and guide time zone. A
  locale with `@hours=h12` gives German a 12-hour clock, which is how a
  user's 24-hour switch reaches `Locale.autoupdatingCurrent`.
- Durations stay catalog entries ("%lld min left", "%lld h %lld min")
  rather than `Duration.UnitsFormatStyle`: the format style writes "1 hr,
  30 min" in English, which would change the agreed copy. Each language
  writes its own abbreviations in the catalog, and the Spanish and German
  duration tests land with those languages (tasks 6.3 and 7.2).

PR 5, Swedish:
- The export's `Source Contents` catalogs hold English only, while the
  catalogs in the repo, which the export rewrites in place, keep every
  language. `scripts/translations.py sync` now carries each key's other
  languages over from the repo catalog, so a sync no longer drops a
  translation.
- A language is added by its code in `Config/languages` and its entries in
  the catalogs. XcodeGen lists it in `knownRegions` on its own once a
  catalog holds it, and the build writes `sv.lproj` into the app, the
  Apple TV app and the Core bundle.
- Translations go in as `needs_review` from a machine first pass, Siri
  phrases included. Source text stays as it arrives: the Live list on an
  iPhone simulator set to Swedish shows "Alla kanaler", "Tablå" and "Läser in
  tablån…" around English channel and programme names.
- Language tests live in `LanguageTests.swift` in AntennaCore, one set of
  examples per language.

Swedish review:
- sv reviewed by a model reviewer in place of a native speaker (owner's
  decision 2026-11-19).
- The first pass wrote "on its own" word for word as "av sig själv"; it is
  "automatiskt" now. Phrases
  built on the -ing form ("den spelande kanalen") became "kanalen som
  spelas". "Watched" on an episode is "Sett", since "avsnitt" is neuter.

PR 6, German:
- `.previewLanguage(.german)` and `.previewLanguage(.arabic)` live in
  `Apps/Shared/Debug/PreviewLanguage.swift`. They set the locale and the
  reading direction; a preview that shows Core text builds that text with
  `PreviewLanguage.german.locale` too, since its fixtures are made outside
  the view.
- The six German previews: "Paywall, iPhone, German", "Paywall, Apple TV,
  German", "Form, iPhone, Xtream, German" (onboarding step 2), "Source rows,
  German", "Guide sources rows, Apple TV, German" and "Error, Apple TV,
  German". Settings detail on iPhone has no component preview: the screen
  owns its SwiftData queries. Its German check is the source rows, whose
  status lines are the detail page's longest copy.
- The paywall, its product rows and the Apple TV player error now take
  `@Environment(\.locale)` for every Core text they show (part of task 3.6).
- The paywall linked "Terms of Use" and "Privacy Policy" by finding the
  English words in the legal line, and the Apple TV paywall cut the English
  sentence off to add the addresses. Both broke in any other language. The
  link words and the renewal sentence are now their own Core entries
  (`legal.terms`, `legal.privacy`, `legal.renewal`), and the Apple TV labels
  "Terms: %@." and "Privacy: %@." are app entries. A translation of
  `legal` must contain the two link words as the translator wrote them.
- The German previews rendered on the iPhone simulator show no truncated
  copy. They caught one English leftover, the guide row's "Retry now",
  which now takes the environment locale.

PR 7, Spanish:
- One neutral Spanish with "tú", Spain's "Ajustes" and Apple's Spanish
  names ("En familia", "Tiempo de uso"). Catch-up is "A la carta".
- An iPhone simulator set to Spanish (Mexico), `es-MX` with region `es_MX`,
  shows the `es` text: "Todos los canales", "En directo", "Ajustes". A Core
  test pins the same fallback, with Mexico's "12,500" grouping.

Spanish review:
- es reviewed by a model reviewer in place of a native speaker (owner's
  decision 2026-11-19).
- The first pass leaned on Spain: "mando", "pulsa", "caducado", "la tele",
  "en directo". These are now "control remoto", "presiona", "vencido",
  "en vivo". "Ajustes", "En familia" and "Tiempo de uso" stay, as in the
  PR 7 decision. A stream is a "transmisión"; "emisión" is kept only for
  broadcasting ("En emisión" for on now).
- "On its own" had become "solo" or "sola"; it is "automáticamente" now.
  "Apple Account" is "cuenta de Apple". The Xtream account status no longer
  sits inside a sentence: "Estado de la cuenta: %@.".
- A free trial reads "Gratis durante %@", and the one form of each offer
  period carries its number ("1 semana"). Spanish "Primer"/"Primera"
  agrees with the unit's gender, which one template could not do.

PR 8, French:
- "vous" throughout, Apple's French names ("Réglages", "Partage familial",
  "Temps d'écran") and "Replay" for catch-up.
- Device names arrive as an argument ("cet %@"), so "cet iPhone" reads
  right and "cet Mac" does not. The reviewer decides between rewording
  those sentences and a variation per device.
- "First %@ free" became "Essai gratuit : %@, puis…", since the period
  noun ("semaine", "mois") changes the adjective's gender.

German review:
- de reviewed by a model reviewer in place of a native speaker (owner's
  decision 2026-11-19).
- "On its own" was "von selbst" in eight entries; it is "automatisch" now.
- A device placeholder can be "Mac", which is masculine, so "dieses %@"
  became "dein %@", and "auf diesem %@" stays. "Unlock your %@" is
  reworded so the placeholder sits in the nominative.
- The intro offer fills "%@" with a bare unit for one ("week"), which
  German cannot put after "Die ersten". The one forms carry their article
  in the accusative ("eine Woche", "einen Monat"), and the three offer
  lines are built around that: "Gratis für eine Woche", "für einen Monat",
  "für jeweils einen Monat, 3 Monate lang".
- The provider's account status sits after "Kontostatus:", not inside
  the sentence. Catch-up is "Mediathek", so the library is "Bibliothek".
  The tab is "Programm", and longer copy says "Programmführer".

PR 9, Portuguese (Brazil):
- The fallback holds. An iPhone simulator launched with `-AppleLanguages
  (pt-PT) -AppleLocale pt_PT` shows the `pt-BR` text ("Todos os canais",
  "Ao vivo", "Ajustes"), and a Core test resolves `pt_PT` to the same
  table. The catalog code is `pt-BR`, so the built app holds
  `pt-BR.lproj`.
- "você", Apple's Brazilian names ("Ajustes", "Chaves do iCloud",
  "Compartilhamento Familiar", "Conta Apple"). Catch-up is "Reprise".

French review:
- fr reviewed by a model reviewer in place of a native speaker (owner's
  decision 2026-11-19).
- The device sentences now say "votre %@", which reads right for iPhone,
  iPad and Mac. "On its own" had gone in as "tout seul"; it is
  "automatiquement" now.
- French has a space before `:` `?` `!` `;` and inside « », and the first
  pass used a plain one, so a line could break before the mark. Every one
  is a no-break space now.
- French counts 0 as singular, and some English entries have no plural
  because English picks "1 channel" in code. The French entries for those
  counts carry their own plural forms ("0 chaîne", "1 série", "1 autre").
  "%@ channels", where the count arrives as text, still reads "1 chaînes".
- The time left reads "Encore 26 min", so "min" needs no agreement.

Portuguese (Brazil) review:
- pt-BR reviewed by a model reviewer in place of a native speaker (owner's
  decision 2026-11-19).
- "On its own" was "sozinho" or "sozinha" in eight entries; it is
  "automaticamente" now.
- "On" and "Off" were "Sim" and "Não", which read wrong as a subtitle
  track name. They are "Ativado" and "Desativado", as in iOS.
- The intro offer one forms carry the number ("1 semana", "1 mês"), so
  "Grátis por 1 semana" and "R$ 4,90 a cada 1 mês durante 3 meses" both
  read. A bare "semana" after "Teste grátis:" did not.
- The provider's account status sits after "Status da conta:", not inside
  the sentence. Picture in Picture is "Imagem no Imagem".
- Every device name is masculine in Portuguese ("o Mac", "o Apple TV"), so
  "este %@" and "neste %@" stay.

PR 10, Arabic text:
- Modern Standard Arabic, with Apple's Arabic names where they exist
  ("الإعدادات", "سلسلة مفاتيح iCloud", "المشاركة العائلية"). Catch-up is
  "إعادة المشاهدة". Product names (Apple TV, AirPlay, Xtream, Jellyfin,
  Channels DVR, M3U, FFmpeg) stay in Latin letters.
- Plural entries fill all six forms. Zero, few, many and other carry the
  number; one and two write the word alone ("قناة واحدة", "قناتان"), as
  Arabic counts. Few takes the plural noun ("٣ قنوات"), many and other the
  singular ("١١ قناة", "١١ يومًا").
- App entries that count with a bare `%lld` and no plural variation in
  English ("%lld channels", "%lld sources added") are written as a label
  and the number ("القنوات: %lld"), which needs no agreement. The Arabic
  reviewer can give them their own plural forms instead, as the French
  review did.
- "Swipe it right" in the empty favorites hint is "to the left" in Arabic:
  the swipe action sits on the leading edge, which is the right side in a
  right-to-left layout, so the row slides left to show it.
- Under `ar_SA` counts and channel numbers use Arabic-Indic digits and
  "٬" for grouping ("١٢٬٥٠٠"). `LanguageTests` pins one example of each
  plural form, the digits and a Latin channel name isolated inside an
  Arabic sentence.

Arabic review:
- ar reviewed by a model reviewer in place of a native speaker (owner's
  decision 2026-11-19). The strings are `translated`, but `ar` stays out
  of `Config/reviewed-languages` until the right-to-left layout (section
  11) and its boards land. Task 12.7 adds it then.
- Counts the app writes with a bare `%lld` now carry all six Arabic forms
  ("%lld channels", "%lld channels without guide", "%lld sources added",
  "Try again in %lld seconds", Core's "Back %lld Seconds" and "CATCH-UP
  %lldD"), so a skip reads "رجوع ١٠ ثوانٍ", not "١٠ ثانية". Entries with
  two counts keep the label form.
- A count that arrives as text ("%@ channels") cannot agree, so it reads
  "قنوات عددها %@" ("channels numbering %@"). It had been "قنوات %@",
  "the channels of %@".
- "%@ will not remind you" had the programme as the subject; it reads
  "you will not get a reminder for %@" now. The provider's account status
  sits after "حالة الحساب:". "Later: " keeps its space.
- "Catch-up 7 days" and "Guide 7 days" put the count after a colon, so the
  dual stays nominative ("الدليل: يومان"). "Recently watched" was a
  word-for-word phrase and is "شوهد مؤخرًا"; time left reads "تبقّى".
- Every device name takes "هذا" after it ("على Mac هذا"), which agrees
  for iPhone, iPad, Mac and Apple TV. Counts follow the locale's digits;
  only fixed figures in the copy (10, 15, 30 seconds, 16 MB) are written
  in Western digits.

PR 11, right to left:
- The four `*-RTL` boards (task 11.1) and the RTL notes (task 11.6) came in
  a follow-up PR. The boards copy the English boards' markup with
  `dir="rtl"`, Arabic copy from the catalogs, Arabic-Indic digits, the
  12-hour clock `ar_SA` formats, no letter spacing, and provider text in
  `<bdi>`. They were checked against the screenshots `LocalizationRTLUITests`
  attaches on an iPhone 17 simulator. Where the app and the spec disagree,
  the boards draw the spec: the zap bar's LIVE badge reads مباشر with its
  red dot, the guide's started-earlier arrow points right, and the iPhone
  now-playing line reads from the right with its Latin parts isolated.
- The RTL note is a comment at the top of the 15 boards the reference
  lists under "Right to left": the four guide boards, the three Live
  boards, the six player and zap bar boards, `TV-Shell-Menu` and
  `TV-Movies-Rows`. The five German-copy boards in Context are about
  length, not direction, and get no note.
- The premise under Right-to-left was wrong: SwiftUI mirrors `.offset(x:)`,
  `.position`, `Path` and alignment guides on its own. Checked with
  `ImageRenderer`: a 10 pt block offset 80 pt in a 100 pt frame draws at
  x 80 in English and x 10 in Arabic, and the same for `.position` and a
  `Path`. The guide grid, the iPhone guide strips, the progress bars and
  the scrubbers already ran from the right, so task 11.2's rebuild on
  leading padding was not needed. The Arabic guide previews and both RTL UI
  tests confirm the axis.
- Input is where it broke. A touch location, a drag translation, a
  double-tap half, a Siri Remote click, swipe or hold, and `onMoveCommand`
  report the physical side. On iPhone a drag on the Arabic scrubber moved
  the wrong way and a double tap on the right half skipped forward. The
  helpers in `Apps/Shared/Components/ReadingDirection.swift` convert the
  side, and every scrubber drag, double-tap skip, banner swipe, edge swipe
  back, tvOS guide move, zap-bar left and right, title click and slide, and
  timeshift scan hold goes through them. The edge swipe back on the iPhone
  Movies, Series and Search pages is one shared modifier now,
  `edgeSwipeBack`.
- Keyboard skip keys and the Mac menu keep left arrow for back and right
  for forward in every language: Core's `KeyCommand` table fixes them and
  the menu bar shows them. The iPad and Mac guide's left and right arrows
  move to what is drawn on that side.
- Letter spacing on uppercase labels pulled Arabic letters apart and wrapped
  the iPhone LIVE button onto two lines. The 40 `.tracking` and `.kerning`
  calls are `.letterSpacing(_:)`, which drops the spacing in a
  right-to-left layout, and the LIVE label stays on one line.
- The middle dot "·" reads as the Arabic-Indic zero "٠" next to Arabic
  digits ("قنوات بلا دليل · ٢" looked like "٢٠"). The Arabic catalog
  entries use "•" instead. About 20 places in Core and the app still join
  parts with " · " in code; the Arabic reviewer decides whether those need
  a per-language separator.
- Guide sources wrote channel numbers with `ChannelNumber.description`,
  Latin digits in every language. They use `text(locale)` now.
- The start-over glyph (`backward.end.fill`) keeps pointing left in Arabic,
  as a transport glyph. The reviewer may want it to point at the start of
  the bar, which is on the right.
- The ten Arabic previews: "Channel rows, iPhone, Arabic", "Channel rows,
  iPad, Arabic", "Channel overlay, a group selected, Arabic", "Zap bar,
  paused 12 minutes behind, Arabic", "Guide grid, a programme on now,
  Arabic", "Guide rows, Arabic", "Timeshift controls, iPhone, paused 12
  minutes behind, Arabic", "Checklist, iPhone, two sources, Arabic",
  "Paywall, iPhone, Arabic" and "Guide sources rows, iPhone, Arabic".
  Their fixtures are the English previews', so fixture text such as group
  names and badges stays English; Core text in them takes
  `PreviewLanguage.arabic.locale`. Task 3.6 is ticked with them.
- `LocalizationRTLUITests` (iPhone) and `LocalizationRTLTVUITests` (Apple
  TV) launch with `-AppleLanguages (ar) -AppleLocale ar_SA` and attach a
  screenshot of each screen they pass. Apple TV's first focus in Movies is
  the banner's Play button, at the right; the spec's "rightmost poster" is
  read as the first focusable element of the first row.
- `TitleUITests.testResumeAMovieAndComeBackToItsPage` fails on a simulator
  whose system language is Arabic, though the app launches in English: the
  poster's context menu is system UI. It passes on an English simulator.
  Run the English UI tests on an English simulator.

Catalog check on CI:
- From 5a6e8bae on, the Build apps job failed at "Catalogs hold every
  string in code" with five keys marked stale, while the same check passed
  locally. CI's image runs Xcode 26.6; the local machine runs Xcode 27.2.
  All five keys sat in a `switch` expression returning
  `LocalizedStringResource?` (`ShelfStates.detail`, `LiveStatus.detail`,
  `SetupFromTV.existing` and `tvDetail`), and in each the first literal was
  extracted and the later ones were not. The same shape written with
  `return` statements (`ChannelOverlayModel.emptyText`) extracted every
  literal. The four switches use `return` now. Xcode 26.6 is not on the
  local machine, so the next CI run is the proof.

Sweep after the reviews:
- The delete-source message said "3 favorites" in English in every
  language. Xcode's string extraction skips a literal whose declared type
  is an optional resource when it sits in a ternary or a `switch` next to
  another literal (`let x: LocalizedStringResource? = n == 1 ? "1 favorite"
  : "\(n) favorites"`). The key never reached the export, so
  `scripts/sync-strings.sh --check`, which compares the export with the
  catalogs, had nothing to compare. Checked with `swift-frontend
  -emit-localized-strings` (Xcode 27.2) on a scratch file: the same
  literal returned from a function, optional or not, is extracted. This is
  the local cousin of the Xcode 26.6 `switch` gap above. A rule in
  `scripts/check-rules.sh` now fails on any declaration typed
  `LocalizedStringResource?`, `String.LocalizationValue?` or
  `LocalizedStringKey?`, and each count is a function that returns a
  non-optional resource with `return` statements, the shape both Xcode
  versions extract. The `switch` gap itself has no rule: a grep cannot
  tell a copy `switch` from the 300 symbol-name ones, so CI's check on
  Xcode 26.6 stays the guard.
- A pass over interpolated literals that match no catalog key found three
  more strings that were English in every language: the guide's "<title>,
  details" announcement (`AccessibilityNotification.Announcement` takes a
  `String`), AntennaCore's spoken scores ("TMDB user score 74 percent",
  "rated 7.4 out of 10") and the player's spoken position ("12 minutes of
  1 hour"). They go through `Words` now. The "7.4" itself still has a
  period in every language.
- Counts that arrived as text ("%@ channels", "on %@ channels", "of guide
  · %@ channels", "of catch-up on %@ channels") take the `Int` now, so
  each is a `%lld` entry with plural forms in every language, all six in
  Arabic, and English one forms for the three onboarding captions.
- English read "$1.99 for month" for a one-month offer paid up front,
  since the one form is the bare unit that "First month free" needs. The
  two price lines now say "for the first <period>": "$1.99 for the first
  month", "$0.99 per month for the first 3 months".
- French and Swedish one forms of the offer periods carry the number, as
  Spanish and Portuguese do: "Essai gratuit : 1 semaine", "pendant 1
  mois", and "par période de 1 mois pendant 3 mois" for pay as you go.
  Swedish "Första vecka gratis" lacked the definite form; it is "Gratis i
  1 vecka", and pay as you go reads "per period om 1 månad i 3 månader".
  German keeps its article forms. Arabic keeps the bare noun, which reads
  after "أول", "لمدة" and "لكل".
- Five Swedish entries were still `needs_review`: the paywall's two link
  words, the renewal sentence and the Apple TV "Terms:" and "Privacy:"
  labels. They read right and are `translated` now. "integritetspolicy"
  stays lowercase, since the legal sentence holds it mid-sentence and the
  link is found by the exact words. English entries marked `new` are the
  copies with numbered arguments that Xcode writes for the source
  language; the sync rewrites them, so they stay.
- Portuguese (Brazil): Apple's Brazilian iPhone User Guide calls Picture
  in Picture "PIP" ("Multitarefa com PIP no iPhone", "Inicie o PIP",
  support.apple.com/pt-br/guide/iphone/iphcc3587b5d). "Imagem no Imagem"
  is gone: the control is "PIP" and the status "Reproduzindo em PIP". The
  Apple TV guide was not checked; the term is assumed to be the same there.
- Portuguese (Brazil) catch-up is "Replay", as in French, in every entry.
  "Reprise" reads as a rerun in Brazil.
- The 35 Arabic entries that PR 11 moved to "•" and back to
  `needs_review` read right and are `translated`, with the new "of guide
  • %lld channels" forms written the same way.
- `OverlayChannelList`'s `==` read the main-actor `multiView` from a
  nonisolated function. Its `Equatable` conformance is main-actor isolated
  now (`@MainActor Equatable`), which `.equatable()` accepts in a view
  body. The tvOS build also warned on `doomed` in `TimeshiftStore`, which
  the cleanup closure now captures by value.
- The separators built in code go through one catalog entry,
  `separator.detail`: " · " in every language and " • " in Arabic.
  `DetailSeparator.text(locale)` and `joinedAsDetail(locale)` in
  AntennaCore build every detail line that was joined or interpolated with
  " · ": 25 sites in Core (source status, guide and search lines,
  reminders, Top Shelf, title facts, stream line, intents) and 12 in the
  app, among them the guide panel's eyebrow, whose untranslatable "%@ %@ ·
  %@" entry is gone. Views with an environment locale pass it; models
  without one use the current locale, which is the running app's
  language. Catalog entries that hold a dot inside a sentence keep their
  own, as PR 11 wrote them.

Live badge in other languages:
- The Apple TV zap bar and info panel picked the LIVE badge by comparing
  its text with "LIVE", and the zap bar dropped LIVE for CATCH-UP the same
  way. Swedish and German write "LIVE", so they drew correctly by luck.
  Spanish ("EN VIVO"), French, Portuguese and Arabic got an outlined quality
  badge with no red dot and no behind state, and during catch-up CATCH-UP
  sat next to it instead of replacing it.
- `ZapBarText.badges` returns `ZapBarBadge` values now: a kind (`live`,
  `catchUp`, `quality`) that picks the drawing and a text that is only
  shown. Core puts CATCH-UP in LIVE's place, so the view no longer filters.
- Two rules in `scripts/check-rules.sh` fail on code that compares text
  with a capitalized English literal in views, components and the
  platform folders, and on Core code that compares a `Words` result. File
  and wire names (the "Inbox" folder in `ImportModel`) are allowed.

Arabic boards against the app:
- The guide's started-earlier mark was the text "◂", which keeps pointing
  left in Arabic. The Apple TV grid and the iPad and Mac board draw
  `arrowtriangle.backward.fill` now, which points right in a right-to-left
  layout, as `TV-Guide-RTL` draws it. A rule in `scripts/check-rules.sh`
  fails on an arrow typed inside `Text`.
- The iPhone now-playing line ("104 Sport One · 20:00 – 22:00 · Next: …")
  was joined in code with the channel name bare. SwiftUI picks a line's
  direction from its first strong letter, so a Latin name first made the
  whole Arabic line run left to right. `LiveNowText` passes the name
  through `Words.source`, and `Words.line` joins the parts with the
  language's separator and starts a right-to-left line with U+200F, so it
  reads from the right whatever comes first. The iPad and Mac details'
  meta line goes through the same path. The Apple TV guide's picture
  caption had the same fault and Latin digits ("1 Channel a1" in Arabic);
  it and the iPhone line share `ChannelIdentityText` now.
- Foundation already isolates a `%@` argument when it resolves an Arabic
  entry, so "Next: %@" with `Words.source` inside it holds the title in two
  pairs of isolates. Nested isolates render the same; the extra pair is
  left alone, since every `Words` call site does it.
- PR 11 kept the behind-live LIVE button on one line, but the LIVE badge
  at the live edge had no line limit. On the iPhone timeshift strip the
  second row holds skip back, play, skip forward, previous channel, the
  tracks button, Picture in Picture and full screen, 308 pt of 44 pt
  targets plus LIVE, more than a 402 pt screen holds with 4 pt gaps. The
  row squeezed the LIVE text into a column and the programme bar to 0 pt,
  in English too. The badge text is fixed-size and the compact row has no
  gaps (each target keeps its 44 pt frame and its glyph sits inside it),
  which leaves the bar 28 pt on an iPhone 17. A 390 pt iPhone gets about
  16 pt. The board draws neither previous channel nor the tracks button;
  if the bar has to be longer, Picture in Picture is the candidate to move
  out of the compact row.
- The delta's Arabic channel row named the Apple TV order (number, logo,
  name) for every platform. The iPhone, iPad and Mac row puts the number
  after the name, as `iPhone-RTL` draws it and the English row does. The
  scenario names both orders now.
- The Arabic previews wrote 24-hour times in Arabic-Indic digits
  ("٢١:٣٤"), which `ar_SA` never shows: it writes "٩:٣٤ م".
  `PreviewLanguage.time(_:_:)` formats a fixed time in UTC with the
  preview's locale and the app's `.shortened` style, and the zap bar,
  guide grid, guide rows and timeshift strip previews use it.

## Open Questions

- Who reviews each language. The review tasks stay open until a reviewer is named.
- Whether the Arabic reviewer accepts the mirrored guide and scrubber (see Right-to-left). The fallback is local to two code paths.
- Whether Siri accepts every translated phrase. Apple rejects phrases it cannot match at build time; the language PR adjusts wording if the build warns.
