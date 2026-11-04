# 0007. Export every SwiftUI preview as a PNG from CI

- Status: Proposed
- Date: 2026-11-04
- Related specs: none

## Context

Every screen has a board in `docs/design/` and reviewers are asked to compare
the implementation against it. Today the only way to see the implementation
is to build and run on a simulator, which this project's main development
machine cannot do (no Xcode locally, CI is the toolchain). Xcode has no
built-in image comparison; UI tests can attach screenshots but never diff
them. Committed reference images need a machine that can record them.

## Decision

Add an iOS unit test target `AntennaTests`, hosted by the Antenna app, that
links the `SnapshottingTests` product of EmergeTools/SnapshotPreviews. One
`SnapshotTest` subclass renders every `#Preview` in the app. CI runs it with
`TEST_RUNNER_SNAPSHOTS_EXPORT_DIR` set and uploads the PNGs as a workflow
artifact on every PR. No reference images are committed and nothing fails
on a visual change; the artifact is for the reviewer's eyes.

Previews are the test surface, so a screen's preview must be deterministic:
fixture data, no network, no live clock, an in-memory `ModelContainer`.

## Options considered

1. **swift-snapshot-testing with committed PNGs.** The standard library, but
   references must be recorded on a machine with Xcode, which we do not have.
   Still the right tool once comparisons are wanted; it can be added later.
2. **XCUITest screenshots as attachments.** No dependency, but one screenshot
   per hand-written test instead of one per preview, and attachments are
   buried in the result bundle rather than downloadable as images.
3. **A hosted visual-diff service.** Comparison without local recording, but a
   paid account and an upload step for a project with five screens.

## Consequences

- Good: a reviewer can download the artifact and lay the PNG next to the board.
- Good: writing a preview is the whole cost of adding a screen to the set.
- Bad: nothing fails automatically. A regression needs a human to look.
- Bad: one more package in the build graph, and a simulator test run on
  every PR adds a few minutes to CI.
- Follow-ups: a tvOS test target so Apple TV screens are rendered too;
  swift-snapshot-testing once a screen's design has settled.
