# Design

## Context

See proposal.md for why. What exists on 2026-11-13:

- No asset catalog and no icon anywhere in the repo. `project.yml` sets no app icon build setting on any target.
- Inside the app the mark is the SF Symbol `antenna.radiowaves.left.and.right`, on the tvOS tab bar, the iPad and Mac sidebar, onboarding and the paywall. Apple's SF Symbols license does not allow a symbol in an app icon.
- Xcode 27.2 with Icon Composer is installed. `ictool` ships inside Icon Composer (`Icon Composer.app/Contents/Executables/ictool`), not on the `xcrun` path, where `ictool` is the asset catalog tool.
- No SVG rasterizer is installed (`rsvg-convert` and ImageMagick are missing, the Homebrew `inkscape` shim points at a removed cask). AppKit's `NSImage` reads SVG, so a Swift script can render one.

Boards, under `openspec/specs/design-system/boards/`:
- New: `App-Icon-Concepts.dc.html`. Three concepts, each at 1024 px (drawn at 512), in Default, Dark, Tinted and Clear, on a Home Screen stand-in at 60, 40 and 29 pt, and in a Mac list at 16 pt and 16 px and in the Dock. Below them the Apple TV layers for concept A, the composed icon unfocused and focused, and the Top Shelf Image.
- Not drawn: the Mac icon on macOS 26 versus 27 rendering, which `ictool --design-generation` can preview once the file exists.

Design-system requirements that apply: "One accent color" (modified here so the icon may use the accent), "Nothing fake and nothing bundled" (no third-party mark), "Text meets contrast minimums" does not apply because the icon has no text.

## Goals / Non-Goals

**Goals:**
- A TestFlight build shows an icon on every platform, from sources that one command regenerates.
- The owner can swap the concept later by replacing two SVG files for iPhone, iPad and Mac and three for Apple TV, then running the script.

**Non-Goals:**
- Alternate icons, a separate Mac icon, replacing the in-app SF Symbol.

## Decisions

### 1. Concept: A, mast and waves

Options considered, all in the accent `#5BB8FF` on the ground `#0B0E13`, no text:
- **A. Mast and waves (chosen).** A vertical mast with a round node and two arcs on each side. It is the same idea as the in-app radio-waves mark, so the icon and the app read as one product, but the geometry is drawn from scratch. The node and inner arcs survive at 16 px. It splits into three Apple TV layers (ground, waves, mast) without inventing extra parts.
- **B. Play in waves.** A rounded play triangle with two arcs to its right. Says video and broadcast, but a play triangle is the mark of most video apps, and with the arcs it reads as a speaker volume symbol.
- **C. Tower A.** A lattice tower whose legs and crossbar form an A, with arcs from the top. Distinctive at 1024, but the crossbar and outer arcs merge below 40 pt, and an A is a letter, close to the no-text rule.

### 2. iPhone, iPad and Mac: one Icon Composer file

Options considered:
- **Icon Composer `.icon` (chosen).** One file covers iOS, iPadOS and macOS and the system renders Default, Dark, Tinted and Clear from it, with Liquid Glass on 26 and later. The deployment target is 26.0, so no fallback images for older releases are needed. The layers are plain SVG files inside the bundle, so swapping the concept means replacing them.
- **Asset catalog `AppIcon.appiconset`.** Needs separate Any, Dark and Tinted PNGs and a full Mac size set, and gets no glass. Xcode 26 and later uses an `.icon` file over an app icon set when both exist.

Layout: `Apps/Mobile/AppIcon.icon/` with `icon.json` and `Assets/waves.svg`, `Assets/mast.svg`. The ground is the document's solid fill, `#0B0E13` by default and black in the dark appearance. Two groups, waves behind mast, each with glass on. The Antenna target sets `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. `Apps/Mobile` is only in the Antenna target, so the TV app never sees the file.

### 3. Apple TV: an asset catalog with a brand assets set

Apple's documentation for Icon Composer lists iOS, iPadOS, macOS and watchOS, and says tvOS and visionOS "still use an `AppIcon` asset catalog". The Icon Composer document format in Xcode 27.2 has `shared` (iOS and macOS) and `watchOS` platforms only. So the TV app gets `Apps/TV/Assets.xcassets/App Icon & Top Shelf Image.brandassets` with:
- `App Icon.imagestack`: Back, Middle, Front layers, 400 by 240 at 1x and 2x.
- `App Icon - App Store.imagestack`: the same three layers at 1280 by 768.
- `Top Shelf Image.imageset`: 1920 by 720 at 1x and 2x.
- `Top Shelf Image Wide.imageset`: 2320 by 720 at 1x and 2x.

The AntennaTV target sets `ASSETCATALOG_COMPILER_APPICON_NAME: App Icon & Top Shelf Image`. The Top Shelf extension needs no icon of its own.

The Back layer is opaque (ground with a soft glow), Middle and Front are transparent PNGs. The static Top Shelf Image shows only when the extension lists nothing.

### 4. Sources and rendering

SVG sources live in `design/icon/`: `waves.svg` and `mast.svg` at 1024 for the Icon Composer file, and `tv-back.svg`, `tv-middle.svg`, `tv-front.svg` at 1280 by 768, `topshelf.svg` at 1920 by 720 and `topshelf-wide.svg` at 2320 by 720 for Apple TV. `scripts/render-icons.sh` copies the two square SVGs into the `.icon` bundle, renders every Apple TV PNG at its sizes with `scripts/render-svg.swift` (AppKit `NSImage`), and exports preview PNGs of the `.icon` with Icon Composer's `ictool` into `design/icon/previews/` for the board. The PNGs are committed so a build needs no rendering step.

Options considered for rendering: `rsvg-convert` and Inkscape (not installed, and one more tool for every machine), `qlmanage` (thumbnails only, square, no exact size), a Swift script on AppKit (chosen; ships with macOS).

### 5. The check

A test in AntennaCore, next to `ReleaseTests`, reads the repo and fails when an SVG source, the `.icon` bundle, a brand assets entry or a rendered PNG is missing, when a PNG has the wrong size, or when `project.yml` does not name the icon on both apps. It cites `app-release/every-app-shows-its-icon`.

## Risks / Trade-offs

- The `icon.json` keys come from the file format Icon Composer writes, which Apple does not document. Opening the file in Icon Composer and saving it again rewrites it in whatever form the current version uses; the test only checks that the file and its layers exist.
- XcodeGen may treat the `.icon` folder as a plain folder and add its contents one by one. If it does, the Antenna target lists the bundle with an explicit file type in `project.yml`.
