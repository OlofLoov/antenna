# Design

## Context

See proposal.md for why. What exists on 2026-11-25:

- `TypeScale` (`Apps/Shared/Components/TypeScale.swift`) lists each
  platform's text styles with their default point sizes, and
  `Font.boardStyle(_:weight:design:)` turns a board's size into the nearest
  style. No call site passes `design:`; every font in the app is plain SF Pro.
- Most headings use `boardStyle`. A few shared components use a text style
  directly: the welcome headline (`.largeTitle` on iPhone, `.title2` on
  Apple TV), the Apple TV onboarding headlines (`.title2`), "You're set" on
  iPhone (`.title`), the passcode prompt (`.title`) and the iPad and Mac
  Live TV group title (`.title`).
- Screens such as Settings, Groups and the add-source sheets title
  themselves with `.navigationTitle`, which the system draws.
- The site sets `-apple-system, system-ui, 'Helvetica Neue', sans-serif` on
  `body`, and `check-site.js` fails a build that has an `@font-face`.
- The wordmark (`add-tuna-wordmark`) is drawn as round monoline strokes.

Boards, under `openspec/specs/design-system/boards/`: every board whose
display heading the app draws gets
`font-family: ui-rounded, -apple-system, system-ui, 'Helvetica Neue', sans-serif`
on that heading, 113 headings on 78 boards. That covers:

- Paywall: every `iPhone-Paywall*`, `iPad-Paywall*` and `TV-Paywall*` board
  (the headline, and the two prices on Apple TV).
- Onboarding: `iPhone-Onboard-1`, `iPhone-Onboard-3*`, `TV-Onboard-1`,
  `TV-Onboard-2`, `TV-Onboard-5*`, `TV-Onboard-Help`.
- Movies and Series: the screen title and the hero title on every
  `iPhone-Movies*`, `iPad-Movies*`, `TV-Movies*`, `*-Series`,
  `TV-Shell-TabView-Movies` and `TV-Hints-Movies` board.
- Title and person pages: `*-Title*`, `*-Person`.
- Profiles: the "Who's watching?" and "Manage profiles" headings on
  `iPhone-Profiles`, `TV-Profiles` and `TV-Profiles-Manage`.
- The iPad and Mac Live TV group title on `iPad`, `iPad-Banner`,
  `iPad-Collapsed`, `iPad-Focus`, `iPad-Live-*`, `iPad-Menus-Go`,
  `iPad-MultiView*`, `iPad-NothingSelected`, `iPad-Player*` and
  `Mac-Menus-Playback`.
- The site: h1 and h2 on every `Web-*` board.

Left plain on purpose: navigation titles on the iPad Settings, Groups, Guide
sources and Import boards and the Sources & Settings title behind
`iPad-Onboard-2`; profile initials, which `ProfileBadge` draws at a fixed
size; glyphs such as the Settings gear and the empty shell's antenna; the
Top Shelf tiles.

Design-system requirements that apply: "Display headings are rounded" (new),
"Type uses text styles" (modified), "Text stays above the platform caption
floor", "Layouts mirror in right-to-left languages", "Copy fits in every
language", "Nothing fake and nothing bundled".

## Goals / Non-Goals

**Goals:**
- One place decides which sizes are rounded, and a test pins it.
- No call site can make body text rounded or a display heading plain.
- Dynamic Type, right-to-left layout and Arabic behave as before.

**Non-Goals:**
- Navigation bar titles.
- A rounded face on browsers that have none.
- Any change of size, weight or spacing.

## Decisions

### 1. The top two steps of each platform are rounded

Rounded: Large Title (34) and Title 1 (28) on iPhone, iPad and Mac; Title 1
(76) and Title 2 (57) on Apple TV. Everything below is plain.

The reference's type table already pairs the platforms row by row: 76 with
34, 57 with 28, 48 with 22. The top two rows are where the boards put
headlines and screen titles: the paywall at 34 and 64, the hero titles at 28
to 40 and 56 to 76, "Who's watching?" at 28 and 56. Below them, titles sit
inside lists and panels: the programme under the iPad Live TV title (Title
2), the guide's details (22), Settings section heads (Title 3). Rounding
those would bring rounded letters into the lists.

Options considered:
- **By style name: Large Title and Title 1 everywhere.** Apple TV has no
  Large Title in its scale, and its headlines are Title 2 (57). The Apple TV
  paywall, welcome and onboarding headlines would stay plain while the
  iPhone ones turn rounded.
- **Every size at least 1.6 times body.** Pulls in Apple TV's Title 3 (48)
  but not iPhone's Title 2 (22), so the platforms split differently, and the
  cut-off moves whenever body does.
- **Title 3 and up.** Rounds Settings section heads and the guide panel.
  Rejected for drifting toward cute, which the owner ruled out.
- **The top two rows of each scale.** Chosen. It matches the table and the
  boards, and the cut-off reads off the scale without a number to tune.

### 2. The step carries the design

`TypeScale.Step` gets `design: Font.Design?`, set to `.rounded` on the four
steps above and `nil` elsewhere. `TypeScale.step(for:in:)` returns the
nearest step, `TypeScale.style(for:in:)` keeps its meaning on top of it, and
`TypeScale.design(of:in:)` gives the design of a text style. `boardStyle`
loses its unused `design:` parameter:

```swift
static func boardStyle(_ size: CGFloat, weight: Font.Weight? = nil) -> Font
static func boardStyle(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font
```

The second overload serves the shared components that ask for a text style
directly, so `.title2` on Apple TV and `.title` on iPhone come out the same
way the scale says. It is a text style, so Dynamic Type keeps working; the
system's rounded design falls back to the system font for scripts it does
not cover, such as Arabic.

Call sites that move to `boardStyle`: `OnboardingWelcome` (both),
`OnboardingKinds.Television`, `OnboardingHelp.Television`,
`OnboardingSummary.Television`, `OnboardingChecklist` (both),
`PasscodePad.Prompt` and `.Waiting`, the `BrowseRegular` heading, and the
`HeroScrim` and `CoverBackdrop` previews. Glyph fonts (`ProfileCornerLabel`,
the keypad digits, the iPhone in `OnboardingFormParts`) and Title 3 and
Title 2 text on iPhone stay as they are.

`scripts/check-rules.sh` gains a check named after the requirement: no
`design:` argument, `.fontDesign(` or `Font.custom` outside `TypeScale.swift`.

Options considered:
- **`.fontDesign(.rounded)` at each heading.** Every new heading has to
  remember it, and nothing catches one that does not.
- **A separate `Font.display(...)` helper.** Same problem with a nicer
  name.
- **`.fontDesign(.rounded)` at the root.** Rounds every row and button.

### 3. Navigation titles stay as the system draws them

SwiftUI has no font setting for `.navigationTitle`. Rounding it means
`UINavigationBar.appearance()` with a rounded `UIFontDescriptor` on iOS, a
different path on tvOS and nothing comparable on macOS, plus re-applying it
whenever the system resets the bar. That is the kind of UIKit appearance
hack the owner asked to avoid, so system titles keep the system face.

### 4. The site uses the system's rounded face

`site.css` sets
`font-family: ui-rounded, -apple-system, system-ui, 'Helvetica Neue', sans-serif`
on `h1, h2`. `ui-rounded` is SF Pro Rounded in Safari on Apple devices; other
browsers skip it and use the body stack. The body stack does not change. No
`@font-face`, so `check-site.js` keeps passing and nothing loads.

Options considered:
- **A web font for every browser.** Breaks the site's no-fonts rule.
- **Round only the home page hero.** The h2 section heads would then differ
  from the app, where screen titles are rounded too.

## Risks / Trade-offs

- [A heading at a display size that is really a field or a number, such as a
  price] → Rounded on purpose; prices on the Apple TV paywall are drawn
  rounded on the boards.
- [A component meant for Apple TV is shown on iPhone at a TV size] → It
  would come out rounded. No such use exists today; the platform split in
  each component decides.
- [A future board puts body text at 28 pt on iPhone] → It would be rounded.
  The board review catches it, and the reference says which sizes round.

## Migration Plan

None. Fonts are not stored.
