# Design

## Context

See proposal.md for why. The audit ran on 2026-11-13 against main at `6a33ee8b`, on the Apple TV 4K (4th generation) and iPhone 17 simulators, with the Debug launch hooks (`-ui-screenshots full|empty`, `-ui-testing-onboarding`, `-ui-testing-shell`, `-ui-testing-shelf titles`, `-ui-testing-profiles`, `-antenna.entitlement locked`). The screenshots were not committed; the file names below are the ones the audit used, so a later run with the same hooks can reproduce them.

Counts over `Apps/` on that commit:

| Pattern | Count |
|---------|-------|
| `.font(.system(size:` | 464 |
| `.font(.<text style>)` | 67 |
| custom `ButtonStyle` types | 30 |
| `.buttonStyle(.plain)` | 78 |
| `.buttonStyle(.card)`, `.borderedProminent`, `.glass`, `.glassEffect`, materials | 0 |
| distinct `cornerRadius` values | 14 (1, 2, 4, 5, 6, 8, 9, 10, 12, 14, 16, 18, 20, 22) |
| `Palette.` uses | 866 |

The root cause is the design-system rule "Every screen has a board before its change is proposed", whose scenario "Reading a measurement" sends implementers to the board's inline pixel sizes. Every board size became a fixed font size and every board fill became a custom button style. This change keeps the boards as the source of layout and maps their type sizes to text styles.

### Audit findings, ranked

Ranked by how much each hurts the first impression on a real Apple TV, then iPhone.

| # | Screen | Finding | Screenshot |
|---|--------|---------|------------|
| 1 | Apple TV, Settings > Add a source | The sheet is the system's centered card, about 420 pt wide, but holds `OnboardingForm.Television` laid out for 1,700 pt. Fields, the title, the QR card and Connect are cropped at both edges. "Back" floats in a pill at the top. This is the screen the owner reported. | `tv-settings-addsource-kinds.png` |
| 2 | Apple TV, Settings over the Guide | Settings has no background. The guide grid, its "Loading guide…" blocks and the now line show through and under the Settings rows. | `tv-settings.png`, `tv-settings-down3.png`, `tv-settings-down7.png` |
| 3 | Apple TV, Settings | Focused Profiles row is a white platter with white text: the label and "Add a profile" disappear. Rows set `foregroundStyle(Palette.text)`, which overrides the system's focused color. | `tv-settings-addsource-focused.png` |
| 4 | Apple TV, Settings and source details | "Sources & Settings" and "Home" titles are drawn under the custom tab bar; Save collides with the clock. | `tv-settings.png`, `tv-source-details-home.png` |
| 5 | Apple TV, Settings > Preferences | Four segmented pickers with no labels ("Live / Guide / Movies", "2 / 3 / 4 hours", "Every 6 / 12 / 24 hours", "Changes channel / Shows the zap bar"). The viewer cannot tell what each one sets. | `tv-source-details-home-down4.png`, `tv-settings-down7.png` |
| 6 | Apple TV, add-source form (onboarding) | Labels are hand-drawn uppercase captions above system capsule fields whose fill is nearly the ground color, so empty fields are almost invisible. Three shapes side by side: capsule fields, a 14 pt button, a 20 pt card. No Cancel or Back on screen. The Keychain line is 20 pt. | `tv-onboarding-form-xtream-down1.png`, `tv-onboarding-form-m3u-connect-focused.png` |
| 7 | Apple TV, source details | Text fields nested inside list rows give a capsule inside a capsule; the file path runs off the row. | `tv-source-details-home.png` |
| 8 | Apple TV, Movies, Series, episodes | Posters and episode rows show focus as a 5 pt white ring with a 1.04 scale, no lift, no tilt. Apple's own apps lift and tilt posters. The hero eyebrow "RECENTLY ADDED · ACTION" is accent blue and overlaps the Antenna mark and the tab bar. | `tv-movies-row-focus.png`, `tv-series-episodes.png` |
| 9 | Apple TV, "No channels yet" | Title at 29 pt (body size) with two muted lines and a lone Retry. No symbol, no way to Settings. The player error screen next to it has a symbol and a better hierarchy, so the two states disagree. | `tv-shell-empty-no-channels.png`, `tv-player-error.png` |
| 10 | Apple TV, kind picker | The five cards run to 54 pt from each edge, inside the 80 pt safe area, and the Channels DVR text is cut off with an ellipsis. | `tv-onboarding-kinds-focus-xtream.png` |
| 11 | Apple TV, captions | Legal text on the paywall, the summary's caption and the Keychain line are 18 to 20 pt. Apple's tvOS minimum is 23 pt. | `tv-paywall.png`, `tv-onboarding-summary.png` |
| 12 | Apple TV, Search | The system search field and keyboard start right under the custom tab bar with no gap. | `tv-search-results.png` |
| 13 | iPhone, add-source sheet | A custom segmented kind picker truncates "Xtream login" and "Channels DVR". Fields are custom rows, not the `Form` that source details uses for the same fields. "Back" where a sheet uses Cancel. Connect is a white slab pinned to the bottom, not the prominent button. | `phone-settings-addsource-xtream.png`, `phone-source-details-home.png` |
| 14 | iPhone, Live empty and error | "Select a channel" placeholder in the player area and "Could not load channels" with Retry below it: two states on one screen, neither with the shared layout. | `phone-shell-empty.png` |
| 15 | iPhone, Movies | Custom Movies/Series switch and genre chips are flat fills on the art, no glass; Play, Info and + use three radii. Eyebrow in accent. | `phone-movies.png` |
| 16 | Every platform | The welcome mark tile (`OnboardingStyle.markTile`) and the logo placeholders add more blues next to the accent. | `tv-onboarding-welcome.png` |

What works and stays: the iPhone tab bar and toolbars already get Liquid Glass from the system; source details on iPhone is a proper grouped `Form`; the paywall's two product cards read clearly; the channel overlay and guide grid follow the TiviMate layout the owner asked for; the player error screen on Apple TV is the right shape for every empty state.

Side finding outside this change: opening the second source's details in an unsigned simulator build crashed in `CloudKitIdentity.isSignedIn()` (`CKContainer(identifier:)` without the iCloud entitlement, from `SourceLoginCard`'s task). It needs its own fix.

### Apple guidance used

- Liquid Glass is for "the navigation layer that floats above the content"; "Don't use Liquid Glass in the content layer"; never stack glass on glass ([Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/), [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)).
- Built with the 26 SDK, tab bars, toolbars and sheets adopt glass on their own; tint glass only to convey meaning ([Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)). `.glass` and `.glassProminent` exist on iOS, macOS and tvOS 26 ([glassProminent](https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glassprominent)).
- On tvOS, "image views and buttons adopt Liquid Glass when they gain focus" ([Materials](https://developer.apple.com/design/human-interface-guidelines/materials)). "Rely on system-provided focus effects" ([Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)). `.buttonStyle(.card)` applies a motion effect on focus ([CardButtonStyle](https://developer.apple.com/documentation/swiftui/cardbuttonstyle)); `.hoverEffect(.highlight)` gives the lift, specular highlight and parallax on tvOS 17 and later ([HoverEffect.highlight](https://developer.apple.com/documentation/swiftui/hovereffect/highlight)).
- tvOS safe area: 60 pt top and bottom, 80 pt at the sides, with room for focused items to grow ([Layout](https://developer.apple.com/design/human-interface-guidelines/layout)).
- tvOS text: default 29 pt, minimum 23 pt; text styles Title 1 76, Title 2 57, Title 3 48, Headline 38, Subtitle 1 38, Callout 31, Body 29, Caption 1 25, Caption 2 23 ([Typography](https://developer.apple.com/design/human-interface-guidelines/typography)).
- tvOS: minimize text entry ([Text fields](https://developer.apple.com/design/human-interface-guidelines/text-fields)); people expect the dismiss button in the content ([Modality](https://developer.apple.com/design/human-interface-guidelines/modality)); the TV app and Settings use a split view with one third and two thirds ([Split views](https://developer.apple.com/design/human-interface-guidelines/split-views)).
- iOS 26 sheets are inset with a glass background at partial height; remove `presentationBackground` overrides ([WWDC25 323](https://developer.apple.com/videos/play/wwdc2025/323/)). Hit targets at least 44 by 44; capsules for standalone buttons ([Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)). Concentric shapes take the container's radius minus padding ([WWDC25 356](https://developer.apple.com/videos/play/wwdc2025/356/)).
- Use system colors and materials, and no in-app appearance setting ([Color](https://developer.apple.com/design/human-interface-guidelines/color), [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)).
- Third-party apps: Channels for Apple TV pairs a full grid guide with an On Now view ([Channels 2.0](https://getchannels.com/2016/10/11/channels-2-0-apple-tv/)); Infuse 8 keeps a minimal look with an opt-in details view ([Infuse 8](https://firecore.com/blog/infuse-8-now-available)). No primary source describes TiviMate's styling; the reference file keeps it as the layout model only.

### Boards

Under `openspec/specs/design-system/boards/`:

- New: `TV-Refresh-AddSource.dc.html` (the add-source form as a two-column page: title, line and QR card on the left, the grouped field rows, footer and Connect and Cancel on the right), `TV-Refresh-AddSource-Kinds.dc.html` (the five kinds inside the safe area with card focus and Cancel), `TV-Refresh-Settings.dc.html` (opaque split view, rows with values, Preferences as value rows), `TV-Refresh-Shell-Empty.dc.html` (the shared empty layout with Open Settings and Try again), `iPhone-Refresh-AddSource.dc.html` (the sheet as a grouped `Form` with Cancel and Connect in the toolbar and Type as a menu row).
- Replaced when their screen ships: `TV-Onboard-2`, `TV-Onboard-3` and its `-M3U`, `-Connecting`, `-XtreamLink` and `-QR*` states, `TV-Settings`, `TV-Shell-Empty`, `iPhone-Onboard-2` and its states. The PR that ships a family renames the `*-Refresh-*` board over the old one and redraws the old board's other states in the new style.
- Follows without a new board: every other screen. Its PR applies the rules to the screen's existing board and updates that board's type comments to text style names.
- Not drawn: the add-source error line (caption 1 in the live-dot color under the footer on Apple TV, footnote on iPhone), the connecting state (Connect shows a progress view and the rows dim), iPad and Mac add-source (the iPhone sheet centered at the system's form size), Apple TV source details (the `TV-Refresh-Settings` rows with the field rows from `TV-Refresh-AddSource`), the Preferences choice list (a system list with a checkmark), and the iPhone Live empty state (the `TV-Refresh-Shell-Empty` layout at iPhone text styles). Each is drawn before its PR opens.
- Drawn in PR 3: `TV-Settings-Details` (Apple TV source details) and `TV-Settings-Preferences-Choices` (the choice list). `TV-Refresh-Settings` became `TV-Settings`, and `TV-Settings-Preferences`, `TV-Settings-SignIn-QR` and `TV-Settings-Delete` are redrawn on the split page. `TV-Settings-Lookups` belongs to `add-title-metadata` and follows `TV-Settings-Preferences` when that change ships.

Journey steps added in PR 1, with the board each compares with:

| Test | Step | Board |
|------|------|-------|
| `TVJourneys.testFirstRun` | `kinds`, `add-source-xtream` | `TV-Refresh-AddSource-Kinds`, `TV-Refresh-AddSource` |
| `TVJourneys.testSettingsAddSource` | `settings-add-source` (Settings opens on the form, with no kinds page) | `TV-Refresh-AddSource` |
| `TVJourneys.testSourceDetails` | `settings`, `source-details` | `TV-Settings`, `TV-Settings-Details` |
| `TVJourneys.testSettingsPreferences` (PR 3) | `settings-preferences`, `guide-window-choices` | `TV-Settings-Preferences`, `TV-Settings-Preferences-Choices` |
| `TVJourneys.testMoviesFocus` | `movies-row-focus` | `TV-Movies` |
| `TVJourneys.testShellStates` (already there) | `empty` | `TV-Refresh-Shell-Empty` |
| `AppJourneys.testSettingsAddSource` | `settings-add-source`, `settings-add-source-xtream`, `source-details` | `iPhone-Refresh-AddSource` |
| `AppJourneys.testLiveEmpty` | `live-empty` | `TV-Refresh-Shell-Empty` at iPhone text styles |
| `AppJourneys.testMoviesDiscover` | `movies` | `iPhone-Movies` |

Design-system requirements that apply: all ten added here, the three modified here, "Text meets contrast minimums", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Live video keeps playing under overlays" and "Visual changes update the boards in the same change".

## Goals / Non-Goals

**Goals:**
- The Apple TV app looks and moves like a tvOS 26 app: system focus with motion, glass navigation, system sheets and forms, the tvOS type scale, the safe area.
- One set of rules a reviewer can check from a screenshot or a grep.
- The TiviMate live layout and the content-first Movies and Series stay.

**Non-Goals:**
- A new visual identity, light mode, or new screens.
- Pixel parity with the old boards.

## Decisions

### 1. How far to go toward the system look

Options considered:
- **A. Adopt the system wholesale.** System `TabView` on tvOS, `List` and `Form` everywhere, `.card` and `.borderless` for every tile, no app-drawn rows. Cheapest to keep up and the closest to Apple's apps. But the channel overlay, zap bar and guide grid have no system equivalent, and the owner chose the TiviMate layout for live TV on purpose.
- **B. Keep the custom look and fix the bugs.** Fix the cropped sheet, the missing backdrop and the white-on-white rows, and leave the custom styles. Smallest diff. Leaves the 464 fixed sizes, the missing focus motion and the 14 radii, which are what makes the app read as "iffy" even where nothing is broken.
- **C. System components for everything that has one, the TiviMate layout for live TV built from system parts.** Settings, forms, sheets, onboarding, the paywall's buttons, posters and episode rows move to system styles. The overlay, zap bar, guide grid and multi-view keep their app-drawn layout but use text styles, the reference materials, the shared focus card with the highlight hover effect for motion, and glass only for controls floating over video.

Decision: **C**. It answers the owner's complaint on every screen that has a system counterpart, and keeps the live TV layout the owner asked for. The cost is that the app-drawn parts need one shared focus component instead of eleven private styles; the reference lists them so the exception cannot grow quietly.

### 2. Boards keep the layout, the reference maps type

The boards stay the source for layout, spacing and color. Their type sizes map to text styles through a table in the reference (below). An implementer reads "29px" on a tvOS board and writes `.font(.body)`. Sizes that fall between styles round to the nearest style; a board that needs a size no style gives is a finding for the board, not a fixed size in code.

Reference additions, folded into `reference.md` at archive:

| tvOS size | Text style | iOS size | Text style |
|-----------|------------|----------|------------|
| 76 | `.title` (Title 1) | 34 | `.largeTitle` |
| 57 | `.title2` | 28 | `.title` |
| 48 | `.title3` | 22 | `.title2` |
| 38 | `.headline` | 20 | `.title3` |
| 31 | `.callout` | 17 | `.headline` / `.body` |
| 29 | `.body` | 16 | `.callout` |
| 25 | `.caption` | 15 | `.subheadline` |
| 23 | `.caption2` | 13 | `.footnote` |
| | | 12 | `.caption` |

iPad and Mac use the iOS column; the Mac's smaller sizes come from the system.

Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64, 80. Radii: small 8 (badges, logo tiles), medium 12 on touch platforms and 16 on tvOS (fields, small cards), large 20 on tvOS and 26 on touch platforms (cards, grouped sections, panels), capsule (buttons, chips, the tab bar). Anything inside a rounded container uses `ConcentricRectangle`.

Materials: content-layer panels over video on Apple TV (overlay, zap bar, guide PiP frame) use `.regularMaterial` over the existing scrim tint, so the picture shows as color, not detail. Floating controls over video use glass. Form and Settings screens on touch platforms use the system grouped background; content screens keep Ground.

Exception list for app-drawn controls (requirement "Controls use system styles"): guide programme blocks, channel overlay rows and groups, zap bar sections, multi-view tiles, passcode digits. They share one `FocusCard` modifier: light fill, dark text, the focus shadow, `.hoverEffect(.highlight)`.

### 3. Add a source on Apple TV becomes a full-screen cover

Options considered:
- **Keep the sheet and shrink the form to fit it.** The tvOS sheet is a narrow centered card. The QR card and the fields will not fit side by side, and stacking them pushes Connect off screen.
- **Push the form onto Settings' navigation stack.** Native, but onboarding uses the same form with no stack under it, and Menu would leave half-typed fields.
- **A full-screen cover with the system backdrop.** Room for the two columns on `TV-Refresh-AddSource`, the same view in onboarding and in Settings, Menu closes it, and the system dims what is behind.

Decision: full-screen cover on Apple TV, sheet on iPhone, iPad and Mac. The cover's content paints no background; the system backdrop shows. The kind picker is its first page, the form its second, inside one `NavigationStack`, so Menu goes back a page before it closes.

### 4. Fields on Apple TV are list rows

The tvOS `TextField` inside a `Form` draws a row with its label and value and opens the full-screen keyboard on select, as in the system Settings app. The custom uppercase label over a capsule field goes. The QR card stays on the left, since typing on the remote is what the household setter-upper hates most.

Found in PR 3 on the tvOS 27.2 simulator: a `TextField` in a `Form` draws its own capsule inside the row's platter and shows no label once it has a value, with `.plain` style too. So the row is `FieldRow` in `Apps/Shared/Components/Form/`: a list button with `LabeledContent` (label left, value or prompt right) over a hidden `UITextField` that becomes first responder on select, which is what makes tvOS open its full-screen keyboard titled with the label. Menu closes the keyboard and keeps what was typed, as `TextField` does. The considered alternatives were an alert holding a `TextField` (two extra presses before the keyboard) and the label outside a capsule field (the focused look covers the value only). The add-source form can use the same `FieldRow`.

A choice is `ChoiceRow` in the same folder: a navigation link with the label and value that pushes the settings split page with one list button per value and a checkmark on the current one. `Picker` with `.navigationLink` style pushed an empty list from Settings on that simulator, so the app draws the list.

### 5. The accent becomes the tint

Options considered:
- **Keep the accent off every control.** The iPhone Connect button stays white, toggles stay system green, and the app has two looks for one action.
- **Set the accent as the app's tint.** Prominent buttons, switches and selected picker values on iPhone, iPad and Mac draw in the one accent. On Apple TV the focus platter stays light, so nothing changes there.

Decision: the tint. It is still one accent color; the rule now names system tint as an allowed use and bans the accent on eyebrows, which the app does today.

Corrected in PR 3. On Apple TV a tinted list button draws its label in the accent at rest and keeps it on the focused light platter, so Settings rows, alert buttons and source details actions read blue on white. The tint now applies on iPhone, iPad and Mac only, and Apple TV keeps the system's labels, white at rest and dark on focus.

### 6. Raise the Apple TV caption floor to 23 pt

Apple's tvOS minimum is 23 pt. The old 18 pt floor came from the boards. Every caption on Apple TV moves to `.caption2` (23) or `.caption` (25). The citation stays `design-system/text-stays-above-the-platform-caption-floor`.

### 7. Check it in CI

`scripts/check-rules.sh` gains two greps: `.font(.system(size:` outside an allow list of files (glyph-only views, number entry, guide time labels), and `: ButtonStyle` outside the exception components. Both start as warnings listing the files left, and become failures in the Verify PR once the count is zero.

## Risks / Trade-offs

- [Every preview changes] → each PR covers one screen family so the preview PNG diff stays reviewable.
- [Text styles grow with Dynamic Type on iPhone and break fixed-height rows] → rows lose fixed heights in the same PR; the PR checks the largest accessibility size on the screens it touches.
- [The highlight hover effect on large guide blocks may tilt too much] → the guide keeps the focus card without the hover effect if it looks wrong on device; that is a named deviation in the guide's PR.
- [UI tests that look for `onboarding.back` in a sheet] → the cover keeps every identifier; Cancel takes `onboarding.back`.

## Migration Plan

None. No stored data changes.

## Open Questions

1. **Apple TV tab bar: keep the custom bar or move to the system `TabView`?** The system bar is Liquid Glass, 68 pt, 46 pt from the top, and hides on scroll, as in the TV app. It has no slot for the Antenna mark or the clock, and the `tvos-shell` capability's Menu behavior would need rework. Recommendation: move to the system bar with Settings as its last tab and the clock drawn by the page, in a later change after PRs 1 to 6 land. Until then the custom bar gets glass and the backdrop rule.
2. **Light platter or glass focus on Apple TV buttons?** tvOS 26 offers `.glass` buttons that stay glass when focused. Recommendation: bordered and glass prominent for primary actions, so the focused primary action keeps the light platter the app already teaches.
3. **Settings on Apple TV: split view or a single column?** Recommendation: split view as on `TV-Refresh-Settings`, as Apple's own Settings does, with the lead column showing the focused row's footer.
4. **The welcome mark tile's navy.** Recommendation: draw the mark on the app icon's own artwork instead, so the only blue on screen is the accent.
