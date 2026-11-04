# Implementation plan checklist

The spec says what the feature does. The plan says how: it turns each
criterion into code and tests, and settles the detail the spec leaves out.
The `plan-reviewer` agent reviews a plan against this list. Most items came
from spec reviews of 0006 to 0016, where they cost several rounds each.

## Coverage

- Every criterion has a row: approach, layer, test name, file, and needs
  (other specs' work it uses, per step 1 of the skill).
- Each test can fail its criterion. A criterion you cannot see how to test
  is a spec problem; say so.
- Nothing in the plan is outside the spec's Scope.

## Interfaces (core)

- Every public type and function has parameter and return types.
- No SwiftData, SwiftUI or UIKit type in AntennaCore (ADR-0005). The app maps
  records to core values.
- Conformances are stated (`Sendable`, `Hashable`, `Identifiable` with the
  id type) where views key on them.
- A value that embeds a credential or stream URL is named, with where it may
  and may not be persisted (ADR-0003).
- Errors are typed domain errors; no raw `NSError` or `DecodingError`
  escapes a public API.

## Rules the spec left open

- Every numeric rule has its boundaries: rounding, zero and negative, ties,
  duplicates, empty input, values out of range.
- Each decision the spec does not make is listed with the choice and one
  line of reason. These go in the PR body for the owner to see.

## Platforms

- tvOS: initial focus on each screen, what Menu does, what play/pause does
  over an overlay, swipes past the ends, which element holds focus when
  none is drawn.
- Compact width: which controls are absent and where the function lives.
- "Screen" vs "window", tap vs click vs select, size classes.

## States the app always has

Covered by a test or a stated decision where they apply:

- empty store on first launch, zero channels, nothing tuned yet
- offline at launch and mid-stream, a slow source, tens of thousands of rows
- credential not yet synced from iCloud Keychain, and never synced on tvOS
- malformed or empty data, an HTML login page answered with 200
- a sync change arriving while the screen is open
- app suspended mid-task, Reduce Motion, a VoiceOver label for each row

## Design (screens)

- Layout, sizes and states come from the boards' inline styles; the plan
  names the board for each view.
- Every state the plan builds is on a board. A state with no board is drawn
  first, or listed as "Not drawn" with the text style it uses; whole-screen
  states (a grid, a loading skeleton, a sheet) need a board.
- Every DR the spec lists holds, or the plan names the deviation and why.
- Accessibility identifiers use the board's prefix (DR-11), one per element
  a test touches. Tests never match on display text.
- Views follow `.claude/skills/swiftui-composition/SKILL.md` (ADR-0008).

## Slicing

- The PR cut follows step 4 of the `implement` skill. Each slice leaves main
  shippable.
