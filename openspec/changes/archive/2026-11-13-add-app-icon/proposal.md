# Proposal

## Why

Antenna has no app icon and no asset catalog. iPhone, iPad and Mac show the blank system placeholder, Apple TV shows a gray tile, and App Store Connect refuses an upload without an icon, so no TestFlight build can reach a device.

> As a living-room viewer, I want to find Antenna on the Apple TV Home Screen by its icon, not by reading the name under a gray tile.

> As an on-the-go viewer, I want Antenna's icon to match my Home Screen when I switch to dark or tinted icons.

After this change every app shows the Antenna mark, a mast with two waves on each side in the accent blue on the dark ground, on the Home Screen, in the Dock, in Settings, in Spotlight and on the App Store. The Apple TV icon moves in layers under the Siri Remote.

## What Changes

- A concepts board with three icon concepts, each at full size, at Home Screen, Spotlight, Settings and Mac list sizes, and in default, dark, tinted and clear. Concept A, mast and waves, is recommended and built.
- iPhone, iPad and Mac: one Icon Composer file whose layers are SVG files in the repo. The system makes the dark, tinted and clear versions from it.
- Apple TV: an asset catalog with the layered Home Screen icon (back, middle, front), the App Store icon, and the Top Shelf Image and Top Shelf Image Wide, rendered from SVG sources by one script.
- A test that fails when an icon source or the project wiring is missing.
- The design-system rule on the accent allows the app icon.

Out of scope:
- Alternate icons the user can pick.
- A Mac-only icon; the Mac uses the same Icon Composer file.
- Replacing the radio-waves SF Symbol inside the app with the new mark.
- App Store screenshots and the website.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-release`: every app ships with its icon, in each appearance the platform offers.
- `design-system`: the accent may appear on the app icon.

## Impact

- `project.yml`: the Antenna target gets the Icon Composer file and the AntennaTV target gets an asset catalog, each named in its app icon build setting.
- New files: the Icon Composer bundle under `Apps/Mobile/`, the asset catalog under `Apps/TV/`, SVG sources under `design/icon/`, `scripts/render-icons.sh`, and a test in AntennaCore that reads them.
- Board: new `App-Icon-Concepts.dc.html`.
- Blocks the first TestFlight upload. Depends on nothing else.
