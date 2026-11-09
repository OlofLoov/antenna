# Proposal

## Why

Today the only pictures CI makes are the Preview snapshots: one screen or
component at a time, on fixture data, outside the running app. Nobody can see
what the app looks like when it actually runs, with navigation, focus, the tab
bar and real layout on an iPhone, an iPad and an Apple TV. Reviewers have to
build and run the app locally to check a change, and locally there is no Xcode.

After this change, every pull request has screenshots of the running app on
each platform, taken by walking through the main screens in the simulator, so
the developer and any reviewer can open the PR and see the app as a user
would. The walk-through is also the first end-to-end test harness: the same
journeys that take screenshots can later assert behavior.

## What Changes

- A new UI test target per platform walks scripted journeys through the
  running app and attaches a full-screen screenshot at each named step.
- The journeys start the app on seeded data through a launch argument, the
  way the existing `-ui-testing-shell` and `-ui-testing-favorites` UI tests
  already do: sources and channels from fixtures, an in-memory store, and no
  network.
- A new CI job runs the journeys on an iPhone, an iPad and an Apple TV
  simulator, exports the screenshots from the result bundle with Apple's
  `xcresulttool`, names them `<device>/<journey>/<nn>-<step>.png`, and uploads
  them as one workflow artifact on each PR.
- The job fails only when a journey cannot reach a step (the app crashed or a
  screen never appeared). A visual difference never fails it, the same rule
  the Preview snapshots follow.

Out of scope:

- Comparing screenshots against committed reference images, failing on a
  visual change, or identical pictures across runs.
- Playing real video in the journeys. The simulator in CI cannot play
  progressive HTTP files, so the player is shown with the recording engine the
  shell scenarios already use.
- Mac screenshots, and screenshots on physical devices.
- App Store marketing screenshots.
- Assertions beyond "the step was reached". Turning journeys into full
  end-to-end tests is follow-up work.

## Capabilities

### New Capabilities

None. This changes CI and test tooling only. No user-facing behavior changes,
so the change sets `skip_specs: true`. When journeys start asserting behavior,
those tests cite the capability they prove, as every test does.

### Modified Capabilities

None.

## Impact

- `.github/workflows/ci.yml`: a new `App screenshots` job on one `macos-26`
  runner, next to `UI tests`, `tvOS tests` and `Preview snapshots`.
- `project.yml`: new test targets `AntennaJourneys` and `AntennaTVJourneys`.
- `Apps/Shared/Debug/`: a screenshot scenario seeded from fixtures, built like
  `UITestingShell` and `UITestingStore`.
- `docs/conventions.md` and `CLAUDE.md`: how to add a journey step and where to
  find the artifact.
- Depends on the tvOS shell scenarios (`tvos-shell`) and the favorites
  scenario, which already exist on main.
- Not blocked. Adds one simulator job per PR, about 15 to 20 minutes, running
  alongside the others.
