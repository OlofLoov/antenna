# Proposal: export every SwiftUI preview as a PNG from CI (adr-0007)

## Why

Recorded as Proposed; the owner has not accepted it yet.

Every screen has a board in the design system
(`openspec/specs/design-system/boards/`), and reviewers are asked to compare
the implementation against it. Today the only way to see the implementation
is to build and run on a simulator, which the project's main development
machine cannot do. It has no Xcode, and CI is the toolchain. Xcode has no
built-in image comparison. UI tests can attach screenshots but never diff
them, and committed reference images need a machine that can record them.

No spec was related when it was proposed.

## What Changes

- A new iOS unit test target `AntennaTests`, hosted by the Antenna app,
  links the `SnapshottingTests` product of EmergeTools/SnapshotPreviews.
- One `SnapshotTest` subclass renders every `#Preview` in the app.
- CI runs it with `TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` set and uploads the
  PNGs as a workflow artifact on every PR.
- No reference images are committed and nothing fails on a visual change.
  The artifact is for the reviewer's eyes.
- Previews become the test surface, so a screen's preview must be
  deterministic, with fixture data, no network, no live clock and an
  in-memory `ModelContainer`.

## Capabilities

### New Capabilities

None. This is an architecture decision with no requirement of its own.

### Modified Capabilities

None.

## Impact

- A reviewer can download the artifact and lay the PNG next to the board.
- Writing a preview is the whole cost of adding a screen to the set.
- Nothing fails automatically. A regression needs a human to look.
- One more package in the build graph, and a simulator test run on every PR
  adds a few minutes to CI.
- Follow-ups: a tvOS test target so Apple TV screens are rendered too, and
  swift-snapshot-testing once a screen's design has settled.
