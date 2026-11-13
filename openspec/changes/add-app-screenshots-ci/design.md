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

The walk-throughs were written and run against local iPhone, iPad and Apple TV
simulators; CI runs them on its own simulators.

## Goals / Non-Goals

**Goals:**

- Full-screen PNGs of the running app on iPhone, iPad and Apple TV, every
  night and on any PR that asks for them, downloadable from the run, named so
  they sort in walk-through order.
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
does. `Journey.launch(_:)` restarts the app with other arguments and keeps the
step numbers, so one walk-through can show several launch states.

| Platform | Test | Steps | Boards |
|---|---|---|---|
| iPhone, iPad | `firstRun` | welcome, add source | `iPhone-Onboard-1`, `iPhone-Onboard-2-M3U` |
| iPhone, iPad | `browse` | live, guide, search, settings | `iPhone-Guide`, `iPad-Guide`, `iPhone-Search`, `iPad-Search`, `iPhone-Settings`, `iPad-Settings` |
| Apple TV | `firstRun` | welcome | `TV-Onboard-1` |
| Apple TV | `shell` | live with the zap bar, menu, focused tab, guide, guide with menu, settings | `TV-ZapBar`, `TV-Shell-Menu`, `TV-Shell-FocusedTab`, `TV-Guide`, `TV-Shell-Guide-Menu`, `TV-Settings` |
| Apple TV | `shellStates` | loading, empty, empty with menu | `TV-Shell-Loading`, `TV-Shell-Empty`, `TV-Shell-Empty-Menu` |

Changes from the first plan, decided while building them:

- The iOS `-ui-screenshots empty` launch shows onboarding, so `firstRun`
  shows the welcome and add-source screens, not an empty channel list and
  settings. The app has had no empty channel list since onboarding landed.
- Favorites is no longer a tab on iPhone or iPad, so `browse` shows Search
  instead.
- `shellStates` launches with `-ui-testing-shell loading` and `empty`. The
  screenshot seed loads its playlist from a local file at once, so it has no
  loading state, and seeding a second copy of those scenarios would only
  duplicate `UITestingShell`.
- Tab buttons on iPhone and iPad carry no identifier, so the walk-throughs
  tap them by label, as `AntennaUITests` does. The iPad guide is the regular
  layout, anchored on `guide.toolbar`; the iPhone one on `guide.root`.
- On Apple TV, Settings slides in over the guide. The settings step waits
  until focus leaves the bar and the page's frame stops moving, so the
  picture does not catch the slide halfway.

Screens that are drawn but not walked yet (player, multi-view, movies,
series, title pages) get steps in the PRs that touch them.

### 4. Its own workflow, on demand

`.github/workflows/screenshots.yml`, one job `App screenshots` on one
`macos-26` runner:

1. Pick the first iPhone Pro, iPad Pro 13-inch and Apple TV 4K simulators the
   runner lists, so a runner image update does not break the job.
2. Boot the iPhone and iPad and pin their status bar with `xcrun simctl
   status_bar override` (9:41, full battery and signal), the usual
   screenshot convention.
3. `xcodebuild test -scheme Antenna -only-testing:AntennaJourneys` with both
   iOS destinations. xcodebuild runs them side by side.
4. The same for `AntennaTV` on the Apple TV, even when the iOS step failed.
5. `scripts/export-screenshots.sh` runs `xcrun xcresulttool export
   attachments` on each result bundle and copies each step from its
   `manifest.json` to `<device>/<test>/<nn>-<step>.png`.
6. Upload one artifact `app-screenshots`, kept 14 days, and the result
   bundles when a walk-through failed.

Triggers, as the owner decided after the first plan: every night at 04:00
UTC, by hand (`workflow_dispatch`), and on a pull request carrying the
`screenshots` label, again on each push while the label stays. Not on every
pull request.

Considered:

- Every pull request and push to main, as first planned. The job holds a
  `macos-26` runner for 15 to 20 minutes, and GitHub runs at most 5 macOS
  jobs at once on the Free and Pro plans. Most PRs change no screen, so the
  owner chose to run it when someone wants the pictures.
- A job inside `ci.yml` with an `if:` on the label. `ci.yml` runs on every
  PR and push; a separate workflow keeps the schedule and the label trigger
  out of it, the same way `ui-tests.yml` does.
- A matrix of three runners. More runners queue behind the CI jobs; one
  runner keeps the total about the same.

Not a required check.

## Risks / Trade-offs

- **Job length.** One runner does iPhone, iPad and Apple TV, about 15 to 20
  minutes. It runs only on demand and at night, and blocks nothing.
- **tvOS focus flakes.** `ShellUITests.testPickerTuneShowsLive` has timed out
  on focus. The walk-throughs run with `-retry-tests-on-failure
  -test-iterations 2` so one flake does not cost the pictures.
- **Seeded app paths.** The scenario replaces dependencies, so a bug in the
  real wiring can hide behind it. It is Debug-only, like the existing UI
  testing scenarios, and the real wiring keeps its own tests.
- **Simulator differences.** Fonts and layout match a device; video and some
  materials do not.
- **Stale pictures.** A PR without the label gets no screenshots. The nightly
  run on main shows what merged.
