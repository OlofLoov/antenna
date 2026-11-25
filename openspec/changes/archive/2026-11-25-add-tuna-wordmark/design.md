# Design

## Context

See proposal.md for why. What exists on 2026-11-24:

- `AntennaMark` (`Apps/Shared/Components/AntennaMark.swift`) draws the old
  icon's mast and waves in the profile's accent on a dark tile. Only the
  welcome screen uses it, at 112 pt on iPhone and 160 pt on Apple TV. The
  same file holds `AppIconTile`, the icon pictures in Settings, Appearance.
- The paywall shows the SF Symbol `antenna.radiowaves.left.and.right` on a
  blue tile (`Paywall.mark`, `Paywall.markTile`), and so does the launch
  splash. The Apple TV paywall puts the symbol and "Antuna" in its top left
  corner. The iPad and Mac sidebar heads its column with the same symbol and
  the word "Antuna".
- `design/icon/` holds `mast.svg` and `waves.svg` (the Icon Composer layers),
  `tv-back`, `tv-middle`, `tv-front` and the two Top Shelf images, all with
  the mark in `#5BB8FF`. `scripts/render-icons.sh` copies and renders them
  and writes six alternates (Mono, Light, Teal, Amber, Pink, Violet) by
  swapping that color. `AppIconChoice` in AntennaCore lists the alternates
  with a mark and a ground color, and `AppIconTests` checks the files.
- The site's header is the word "Antuna" in bold text, and the favicon is the
  old mast and waves.
- The owner's artwork: every path, pivot and color of the mark, the three
  still SVGs and a web prototype of the motions in CSS keyframes. Its
  numbers are copied into AntennaCore below, unchanged.

Boards, under `openspec/specs/design-system/boards/`:
- New: `Brand-Mark.dc.html`. The wordmark on dark and light, the a on its
  own, the standard icon and the six alternates, the Apple TV icon's three
  layers, Top Shelf, the launch splash, and key frames of Hello, Tuning and
  Got it with their timings and Reduce Motion forms.
- Updated: `iPhone-Onboard-1` and `TV-Onboard-1` (the wordmark above the
  title); `iPhone-Loading`, `iPad-Loading` and `TV-Shell-Loading` (the mark
  above the sources); every `iPhone-Paywall*`, `iPad-Paywall*` and
  `TV-Paywall*` board (the a in place of the symbol tile, the wordmark in
  the Apple TV corner); every iPad board with the sidebar (the wordmark in
  place of the symbol and word); `iPhone-Settings-Appearance`,
  `iPad-Settings-Appearance` (the icon pictures); `TV-TopShelf-Empty`; and
  the `Web-*` boards (the header).
- Not drawn: motion itself. The board shows frames and timings; the
  prototype in the owner's reference is the motion source, and the numbers
  in decision 2 are its port.

Design-system requirements that apply: "The Antuna mark", "The mark's
colors", "The mark moves at three moments", "Reduce Motion stills the mark" (new), "One accent color per
profile" (modified for the tips), "Nothing shows before the paywall" (the
splash shows only the mark), "Loading shows real progress per step" (the
mark sits above the rows and never stands in for them), "Apple TV content
stays in the safe area", "Text meets contrast minimums" (the mark is not
text; its letters on the ground are 17.6:1).

## Goals / Non-Goals

**Goals:**
- One source for the shapes and one for the timings, shared by every
  platform, testable without a screen.
- The play triangle and the mouth cut through, so the mark works on any
  ground.
- Previews and tests that show any frame without a clock.

**Non-Goals:**
- Motion over video, sound, haptics.
- A general SVG or animation engine. The parser reads the commands the
  owner's paths use and nothing more.

## Decisions

### 1. Geometry as data in AntennaCore

The owner's path strings are copied verbatim into `MarkGeometry`
(`Packages/AntennaCore/Sources/AntennaCore/Brand/MarkGeometry.swift`) in SVG
user units: baseline at y 0, the word in the box x -6 to 754 and y -192 to 6
with antennae, the a alone in x 575 to 775. `MarkPath.elements(_:)` parses
absolute `M L H V C Q A Z` into move, line, quad, cubic and close elements,
turning each arc into cubics, so the app needs no SVG code. The app maps
those elements to a SwiftUI `Path` in one function.

Options considered:
- **Hand-written `Path` calls in the app.** No parser, but the shapes would
  drift from the artwork with every retype, and nothing could check them
  outside a simulator.
- **Bundled SVG or PDF assets.** The system draws SVG in an `Image`, but not
  per part, so nothing could move.
- **The path strings in AntennaCore, parsed (chosen).** Tests compare the
  parsed shapes with the artwork's numbers (bounds, the hinge, the pivots),
  and a future artwork tweak is a string swap.

### 2. Motion as keyframe tables in AntennaCore

`MarkMotion.pose(_ moment:, at seconds:, reduceMotion:)` returns a
`MarkPose`: every part's draw progress, scale, offset, angle and opacity at
that instant. Each part has a track of keyframes (offset in the motion,
value, the easing into the next key), with the prototype's delay, length,
fill and repeat. `CubicBezier` solves the CSS timing curves (`ease`,
`ease-in`, `ease-out`, `ease-in-out` and the prototype's custom curves) the
way a browser does.

The tracks are the prototype's final rules, where later CSS rules override
earlier ones (`--k` is 1):

| Part | Hello (3.2 s, once) | Tuning (loops) | Got it (1.2 s, once) |
|------|---------------------|----------------|----------------------|
| Letter i | draws over 0.55 s from 0.09 × i s, curve (.5,0,.3,1), fades in over the first 4% | still | still |
| Head and tail | scale 0 to 1 at 0.5 s over 0.45 s, curve (.3,1.5,.5,1) | still | tail skews 0, -20°, 12°, -3°, 0 at 0, 25, 55, 80, 100% of 0.7 s from 0.15 s, ease-out, about its left middle |
| Play triangle | scale 0 until 26%, 1.15 at 32%, 1 from 36 to 62%, moved (-21,-21) at scale 0 from 70 to 86%, back at 1 from 95%, of 3.2 s, ease-in-out | moves to (-21,-21) at scale 0 over 0.35 s, ease-in | at the eye, scale 0 until 52%, home at 1.12 at 80%, 1 from 90%, of 1.2 s |
| Eye | scale 0 until 66%, 1.15 at 72%, 1 from 75 to 86%, 0 from 90%; one blink (y to 0.1 and back) over 0.24 s at 2.45 s | pops in over 0.3 s at 0.25 s, curve (.3,1.6,.5,1); looks (-3,-1) at 30%, (3,-1) at 60% of 2.4 s; blinks at 86% of 2.4 s | 1 until 50%, 0 from 60%; squints to (1.15, 0.4) from 12 to 40% of 1.2 s |
| Mouth | opens to 3 at 40%, 1.5 at 70% of 0.5 s from 1.55 s | opens to 2.1 at 50% of 2.4 s | gulps 3.4, 1, 1.8, 1 at 30, 55, 75, 100% of 0.6 s from 0.1 s, ease-out |
| Sticks | draw over 0.25 s from 1.05 s (left) and 1.12 s (right), ease-out | lean left -14° at 30%, 9° at 65%; right -9° and 14°; of 2.4 s, ease-in-out | still |
| Tips | pop 0 to 1 over 0.35 s from 1.25 s and 1.32 s, curve (.3,1.8,.5,1) | rings grow 1 to 2.6 and fade 0.7 to 0 over 1.2 s, the right one 0.6 s later, ease-out | hop 9 units up at 45% of 0.45 s, from 0.3 s and 0.38 s, curve (.3,0,.4,1) |

Reduce Motion: Hello is the still pose fading 0 to 1 over 0.4 s, Got it the
still pose fading 0.5 to 1 over 0.4 s, Tuning the still pose with the tips'
opacity easing 1, 0.35, 1 over 2.4 s, looping. `MarkMotion.duration` is 3.2,
1.2 and nil (loops) without Reduce Motion, 0.4, 0.4 and nil with it.

Options considered:
- **SwiftUI `keyframeAnimator` per part.** Close to the CSS, but the timings
  would sit in view code where AntennaCore tests cannot reach them, and a
  preview cannot hold a frame without a clock.
- **A Lottie file or a rendered video.** A new dependency or a large asset
  per platform and color, and Reduce Motion would need a second file.
- **Tables in AntennaCore, evaluated per frame (chosen).** Tests check that
  each motion ends on the still pose, that Tuning repeats every 2.4 s and
  that Reduce Motion moves nothing; previews pass a fixed time.

### 3. Drawing with one Canvas

`BrandMark.Drawing` (`Apps/Shared/Components/Brand/`) draws a `MarkPose` in
a `Canvas` scaled from the artwork's box to the view: the letters stroked at
38 with round caps and trimmed to their draw progress, then the a in its own
layer, where the head and tail fill in the ink and the play triangle (with a
6-unit round stroke for its soft corners), the mouth wedge and the eye are
drawn with `.destinationOut`. The layer is cut, not painted, so the page shows
through on any ground. The sticks, rings and tips draw on top.

`BrandMark.Word` and `BrandMark.Letter` are the two arrangements (the word
with antennae, and the a alone). Each takes a `MarkMoment`, a `BrandMark.Ink`
(`.onDark`, `.onLight`, or an icon's colors) and a `BrandMark.Clock`
(`.live`, or `.frozen(seconds)` for previews). A live clock drives a
`TimelineView(.animation)` from the moment the view first shows that moment,
and pauses once a one-shot motion ends. The start is kept in `@State`, so a
screen that comes back from a sheet or a pushed page does not replay Hello.
Changing the moment starts the new one from its first frame.

Reduce Motion comes from `accessibilityReduceMotion` and is passed to
`MarkMotion.pose`.

Each mark is one accessibility element, an image named "Antuna", with the
caller's identifier and its moment as the value (`hello`, `tuning`, `gotIt`,
`still`), which UI tests read.

Options considered:
- **Shapes with `.mask` and `.blendMode` modifiers.** Works, but a dozen
  views per frame instead of one draw call, and each needs its own
  transform anchor.
- **Even-odd paths with the hole inside.** The triangle's tip reaches into
  the tail, where even-odd would leave it filled.
- **One Canvas with a cut-out layer (chosen).**

### 4. Where each motion plays

| Moment | Where | Mark | Identifier |
|--------|-------|------|------------|
| Hello | Welcome screen, iPhone, iPad and Mac (`OnboardingWelcome.Phone`), 220 pt wide | Word | `onboarding.mark` |
| Hello | Welcome screen, Apple TV (`OnboardingWelcome.Television`), 520 pt wide | Word | `onboarding.mark` |
| Tuning | Launch splash, every platform (`LaunchSplash`), 120 pt tall | Letter | `paywall.splashMark` |
| Tuning | Loading screen at launch, Apple TV (`ShellLoading.Screen`), 360 pt wide above the panel | Word | `shell.loadingMark` |
| Tuning | Loading list, iPhone, iPad and Mac (`Browse.LoadingList`), 72 pt tall above the rows | Letter | `browse.loadingMark` |
| Got it | Paywall after a restore, iPhone, iPad and Mac (`Paywall.Touch`), 96 pt tall in place of the symbol tile; still in the other phases | Letter | `paywall.mark` |
| Got it | Paywall after a restore, Apple TV (`Paywall.Television`), the wordmark 44 pt tall in the top left corner in place of the symbol and word; still in the other phases | Word | `paywall.mark` |
| Still | iPad and Mac sidebar head (`Browse.Sidebar`), 28 pt tall in place of the symbol and word | Word | none, the sidebar is hidden from accessibility |

Not changed: `Browse.NothingSelected`, `LiveNoSources` and the empty states,
which use the slashed antenna symbol for "no signal" and are not the brand.
The player's buffering ring and the guide's placeholders.

Options considered for Got it: after the loading screens (the channel list
would wait 1.2 s on every launch); after a purchase (the paywall closes at
once, `paywall-and-entitlement/a-buyer-goes-straight-in`); after a manual
refresh in Settings (the row's own check already says so, and a mark in a
settings list is decoration). The restored paywall is the one screen that
both confirms and waits for the user, so Got it plays there.
There Got it starts from the still mark, not from Tuning, since restoring
shows no mark of its own: its first frame shows the eye at once, and the
rest plays as drawn.

### 5. The tips stay teal on every profile

The owner set the mark's colors. The alternative was tips in the profile's
accent, as `AntennaMark` drew its mast. That makes the brand change color
with every profile and turns the default (Blue) into the mark's color on a
new install, which is not the artwork. The tips are brand, like the app
icon, so "One accent color per profile" names the mark as its one
exception. Changing this later is a color swap in `BrandMark.Ink.onDark`.

### 6. Icons

`design/icon/` after this change:

| File | What |
|------|------|
| `glow.svg` | The 1024 ground: radial gradient from #1A2A44 at (512, 256), radius 725, to #0B0E13 |
| `letter.svg` | The a's head and tail with the play triangle and mouth cut by a mask, and both sticks, in #F2F4F8 |
| `tips.svg` | The two tips in #4FD1C5 |
| `tv-back.svg`, `tv-middle.svg`, `tv-front.svg` | The glow; the head and tail; the sticks and tips |
| `topshelf.svg`, `topshelf-wide.svg` | The wordmark on the glow |

The mark sits as in the owner's icon artwork:
`translate(120 134) scale(1.05) translate(-675 59)` on a 240 tile, scaled to
each canvas.

The Icon Composer file has three groups, top to bottom: tips and letter with
glass, and the glow without glass, hidden in the dark and tinted
appearances so the system's own dark and tinted grounds show. Icon Composer
does not support radial fills, so the glow is a layer; a layer with
`hidden-specializations` exported as expected with `ictool` on 2026-11-24.
The solid fill stays #0B0E13 under it, and black in dark mode.

`AppIconChoice` drops `mark` for `ink` and `tip`, and keeps `ground`:

| Choice | Alternate name | Ink | Tips | Ground |
|--------|----------------|-----|------|--------|
| standard | none | #F2F4F8 | #4FD1C5 | #0B0E13 with glow |
| mono | `AppIcon-Mono` | #F2F4F8 | #F2F4F8 | #0B0E13 |
| light | `AppIcon-Light` | #0B0E13 | #119C8F | #F2F4F8 |
| blue | `AppIcon-Blue` | #F2F4F8 | #5BB8FF | #0B0E13 |
| amber | `AppIcon-Amber` | #F2F4F8 | #FFB454 | #0B0E13 |
| pink | `AppIcon-Pink` | #F2F4F8 | #F472B6 | #0B0E13 |
| violet | `AppIcon-Violet` | #F2F4F8 | #C084FC | #0B0E13 |

`AppIcon-Teal` is gone, since the standard icon is teal. A device that set it
falls back to the standard icon and `AppIconChoice(alternateName:)` reads it
as standard. Only test builds ever shipped it. `render-icons.sh` writes each
alternate by swapping the ink and tip colors in `letter.svg`, `tips.svg` and
the Apple TV layers, as it swapped one color before. `AppIconTile` draws
`BrandMark.Letter` in the choice's colors on its ground.

Options considered: keep Teal as an alternate identical to the standard icon
(a duplicate in the picker); recolor the standard icon's letter instead of
the tips (the owner's artwork has light letters).

### 7. The website

The header's text link becomes an inline SVG wordmark inside the link, with
`aria-label="Antuna"` on the link and the SVG hidden from screen readers.
Its letters and tips take `var(--text)` and a new `--tip` color from
`site.css` (#4FD1C5 dark, #119C8F light), and the triangle and mouth are cut
with an SVG mask, so the page color shows through in both modes. The SVG is
in the component's markup, so it adds no request and no image to the
budget, and it has no `style` attribute. `static/favicon.svg` becomes the
app icon.

Options considered: two `<img>` files in a `<picture>` with a
`prefers-color-scheme` source (two requests, and `check-site.js` would count
both against the image budget); a single `<img>` (cannot follow the page's
colors).

### 8. Identifiers and files

- AntennaCore `Brand/`: `MarkGeometry`, `MarkPath` (`Element`, `Point`),
  `MarkMoment` (`still`, `hello`, `tuning`, `gotIt`), `MarkPose`,
  `MarkMotion`, `CubicBezier`. Tests: `MarkGeometryTests`,
  `MarkMotionTests`, `AppIconTests` updated.
- Apps `Components/Brand/`: `BrandMark.swift` (`Word`, `Letter`, `Drawing`,
  `Ink`, `Clock`), `AppIconTile.swift`. `AntennaMark.swift` is deleted.
  `Paywall.mark` and `Paywall.markTile` are deleted.
- Accessibility identifiers: decision 4's table.

## Risks / Trade-offs

- [A `TimelineView` redraws at the display's rate while a mark moves] →
  Hello and Got it pause their timeline when they end; Tuning shows only
  while something loads, and the Canvas draws about 20 paths.
- [The mark's teal next to a Blue profile's controls] → The two colors
  never share a control; the mark is the brand and is named as the
  exception.
- [Users who picked the Teal alternate on a test build see the standard
  icon] → It is teal; no released build had it.
