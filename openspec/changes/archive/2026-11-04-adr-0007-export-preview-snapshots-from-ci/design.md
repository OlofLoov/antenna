# Design: export every SwiftUI preview as a PNG from CI

## Context

Each screen has a board under `openspec/specs/design-system/boards/`, and the
design-system requirement "Every screen has a board before its change is
proposed" makes the board the reference a reviewer checks against. The main
development machine has no Xcode, so it cannot build or run the app on a
simulator. CI is the only toolchain. Xcode cannot compare images, UI tests
attach screenshots without diffing them, and committed reference images need
a machine that can record them.

## Goals / Non-Goals

**Goals:**

- Every PR gives the reviewer a PNG of every SwiftUI preview to lay next to
  the board.
- Adding a screen to the set costs only writing its preview.

**Non-Goals:**

- Automatic visual regression failures.
- Committed reference images.
- Apple TV screens, for now (see follow-ups).

## Decisions

**Render previews in CI and export them.** An iOS unit test target
`AntennaTests`, hosted by the Antenna app, links the `SnapshottingTests`
product of EmergeTools/SnapshotPreviews. One `SnapshotTest` subclass renders
every `#Preview`. CI sets `TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` and uploads the
PNGs as a workflow artifact on every PR.

**Previews must be deterministic.** Previews are the test surface, so each
uses fixture data, no network, no live clock and an in-memory
`ModelContainer`.

Options considered:

1. swift-snapshot-testing with committed PNGs. The standard library, but
   references must be recorded on a machine with Xcode, which the project
   lacks. It stays the right tool once comparisons are wanted, and it can be
   added later.
2. XCUITest screenshots as attachments. No dependency, but one screenshot
   per hand-written test instead of one per preview, and attachments are
   buried in the result bundle rather than downloadable as images.
3. A hosted visual-diff service. Comparison without local recording, but a
   paid account and an upload step for a project with five screens.

## Risks / Trade-offs

- Nothing fails automatically. A regression needs a human to look.
- One more package in the build graph, and the simulator test run adds a few
  minutes to CI on every PR.
- Follow-up: a tvOS test target so Apple TV screens are rendered too.
- Follow-up: swift-snapshot-testing once a screen's design has settled.
