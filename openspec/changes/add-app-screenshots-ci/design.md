# Design

## Context

CI already runs three simulator jobs on `macos-26`: `Preview snapshots`
(renders every `#Preview` to PNG), `UI tests` (`AntennaUITests`, iPhone) and
`tvOS tests` (`AntennaTVTests` and `AntennaTVUITests`). The UI tests start the
app with launch arguments that swap in seeded state, compiled into Debug only:

- `-ui-testing-shell <scenario>` (`Apps/Shared/Debug/UITestingShell.swift`):
  the tvOS shell on an in-memory store, two scripted sources and a recording
  engine. Scenarios `channels`, `failing`, `loading`, `empty`.
- `-ui-testing-favorites 2,0,1` (`Apps/Shared/Debug/UITestingStore.swift`):
  an in-memory store holding favorites only.

Nothing seeds the iPhone and iPad screens with sources and channels, so
`ChannelsView`, `GuideView` and `SettingsView` can only be shown empty today.

The local machine has no Xcode, so everything here is built and checked in CI.

## Goals / Non-Goals

**Goals:**

- Full-screen PNGs of the running app on iPhone, iPad and Apple TV for every
  PR, downloadable from the run, named so they sort in walk-through order.
- Use the common setup: XCUITest screenshots as attachments, exported from the
  result bundle with Apple's own tool. No new dependencies.
- Walk-throughs that can later grow assertions and become end-to-end tests.

**Non-Goals:**

- Reference images, pixel diffs, failing on a visual change, or identical
  pictures across runs. A screen that shows the current time shows the time
  the job ran.
- fastlane snapshot. It does the same thing through Ruby and fastlane, which
  the repo does not use.
- Dark mode, larger text and other locales. Each is a later addition.
- Real video. The CI simulator cannot play progressive HTTP files, and the
  shell already shows the player through a recording engine.
- Mac.

## Decisions

### 1. Separate test targets

`AntennaJourneys` (iOS) and `AntennaTVJourneys` (tvOS), both
`bundle.ui-testing`, sources in `Apps/Journeys/` and `Apps/TVJourneys/`, added
to the `Antenna` and `AntennaTV` schemes' test action.

Considered: adding screenshot steps to `AntennaUITests` and
`AntennaTVUITests`. Those tests each prove one requirement and cite it; mixing
walk-throughs in blurs what a failure means, and the screenshot job would rerun
them. A separate target runs on its own with `-only-testing`.

### 2. Seed data through a launch argument

A Debug-only launch argument `-ui-screenshots full|empty` in
`Apps/Shared/Debug/UITestingScreenshots.swift`, following the existing
`UITestingStore` pattern: an in-memory `ModelContainer` and scripted sources
instead of the network.

- `full`: an M3U source "Home" with 12 channels in News, Sport and Movies,
  4 of them favorites, and an Xtream source "Provider". The tvOS shell uses
  the same data. Channels without a logo show the existing placeholder.
- `empty`: no sources, the first screen a new user sees.

Considered: reusing `-ui-testing-shell`. Its three channels suit the tvOS
assertions but are too few to judge a layout, and changing them would disturb
those tests.

### 3. Walk-throughs

A walk-through is one XCTest method. A shared `snap("<step>", anchor:)`
helper waits up to 10 seconds for an element with that accessibility
identifier, then attaches `XCUIScreen.main.screenshot()` named `<nn>-<step>`
with `lifetime = .keepAlways`. A missing anchor fails the test; nothing else
does.

First walk-throughs:

| Platform | Test | Steps | Boards |
|---|---|---|---|
| iPhone, iPad | `firstRun` | channels empty, settings empty | `iPhone-Onboard-3-Empty`, `iPad-Empty` |
| iPhone, iPad | `browse` | channels list, guide, favorites, settings | `iPhone-Guide`, `iPad-Guide`, `iPhone-Settings`, `iPad-Settings` |
| Apple TV | `shell` | live full screen, menu bar, focused tab, guide, settings | `TV-Shell-Menu`, `TV-Shell-FocusedTab`, `TV-Shell-Guide-Menu`, `TV-Guide`, `TV-Settings` |
| Apple TV | `shellStates` | loading, empty, empty with menu | `TV-Shell-Loading`, `TV-Shell-Empty`, `TV-Shell-Empty-Menu` |

The boards say which picture a reviewer compares each step with. Screens that
are drawn but not built yet (player, zap bar, movies, search) get steps in the
PRs that build them.

### 4. One CI job

A job `App screenshots` in `.github/workflows/ci.yml`, one `macos-26` runner:

1. Pin the iOS status bar with `xcrun simctl status_bar override` (9:41, full
   battery and signal), the usual screenshot convention.
2. `xcodebuild test -scheme Antenna -only-testing:AntennaJourneys` with two
   `-destination` flags, an iPhone and an iPad. xcodebuild runs them side by
   side.
3. The same for `AntennaTV` on an Apple TV 4K.
4. `scripts/export-screenshots.sh` runs `xcrun xcresulttool export
   attachments` on each result bundle and renames the files from its
   `manifest.json` to `<device>/<test>/<nn>-<step>.png`.
5. Upload one artifact `app-screenshots`, kept 14 days.

Device names come from the runner's simulator list, picking the newest iPhone,
iPad Pro and Apple TV 4K, so a runner image update does not break the job.

Considered: a matrix of three runners. GitHub runs at most 5 macOS jobs at once
on the Free and Pro plans and CI already has 5, so extra runners queue. One
runner keeps the PR's total wait about the same.

Runs on every pull request and on pushes to main. Not a required check.

## Risks / Trade-offs

- **Job length.** One runner does iPhone, iPad and Apple TV, about 15 to 20
  minutes. It runs alongside the other jobs and blocks nothing.
- **tvOS focus flakes.** `ShellUITests.testPickerTuneShowsLive` has timed out
  on focus. The walk-throughs run with `-retry-tests-on-failure
  -test-iterations 2` so one flake does not cost the pictures.
- **Seeded app paths.** The scenario replaces dependencies, so a bug in the
  real wiring can hide behind it. It is Debug-only, like the existing UI
  testing scenarios, and the real wiring keeps its own tests.
- **Simulator differences.** Fonts and layout match a device; video and some
  materials do not.
