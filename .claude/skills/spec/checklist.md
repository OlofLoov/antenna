# Spec self-review

Run this on the draft before the `spec-reviewer` agent sees it. Every line is
a class of finding the reviewer raised on three or more of specs 0006 to 0016
after two rounds. Fix, do not note.

First run `bash scripts/lint-spec.sh`. It catches the mechanical half: status
word, Given/When/Then per criterion, test plan rows, cross-references, board
files, missing Not drawn line. Then go through the rest by hand.

## Header

- Status is the bare lifecycle word. Review history goes in the PR body.
- "Blocked on" names only what stops acceptance. A dependency that already
  exists in the tree is not a blocker. A decision owed later is a
  "Follow-up ADR" line that says what this spec assumes meanwhile and which
  criteria change if the ADR decides otherwise.
- "Builds on" lists every spec a criterion cites. Specs in open PRs are named
  as not in the tree.
- "Depends on ADRs" lists every ADR a criterion or the Scope relies on.

## Each criterion

- One Given, one When, one Then, one assertion. Two scenarios are two
  criteria (AC-9a, AC-9b), each with its own test plan row.
- The Given contains every fixture the Then asserts on. A Then that mentions
  a programme, row, source or value has it in the Given.
- The Then is observable. Name the accessibility identifier, the core return
  value, the recorded call or the record in the container. Never display text
  as the only handle, never a colour or a type size (those are the
  impl-reviewer's board comparison).
- A branch the Given cannot reach is deleted or given its own Given.
- Every numeric rule states its boundaries: rounding direction, zero and
  negative, equal keys (tie order), duplicates, an empty list, a value above
  the range you expected.
- A cited criterion in another spec exists and says what you claim.
- A string the user sees is quoted exactly once, in the criterion that owns
  it, and matches the board.

## Interfaces (core specs)

- Every signature has parameter types and a return type.
- No SwiftData, SwiftUI or UIKit type appears in an AntennaCore protocol
  (ADR-0005). The app maps records to core values and the spec says so.
- Conformances are stated once (`Sendable`, `Hashable`, `Identifiable` with
  the id type) when a UI spec keys views on them.
- A value that embeds a credential or stream URL is named, and the criteria
  say where it may and may not be persisted (ADR-0003).

## Platforms

- Each criterion holds on every platform in the header, or names the ones it
  applies to. Walk every board per platform and compare labels, counts,
  control presence and layout against the Then.
- "Screen" vs "window", tap vs click vs select, size classes: say which.
- tvOS: initial focus on each screen and step, what Menu does on each, what
  play/pause does while an overlay is up, swipes past the first and last
  element, which element holds focus when the screen draws no control.
- Compact width: which controls are absent and where the function lives
  instead.

## States the app always has

Check that a criterion or an edge case covers each one that applies:

- empty store on first launch, zero channels, no channel ever tuned
- offline at launch, offline mid-stream, slow source, a source in the tens of
  thousands of rows
- credential not yet synced from iCloud Keychain, and the tvOS case where it
  never syncs
- malformed or empty data, an HTML login page as a 200
- a sync change arriving while the screen is open (favorite, source, group)
- app suspended mid-task, Reduce Motion, VoiceOver label for each row

## Design section

- Every board the spec covers is named in its Design section and exists.
  Every `.dc.html` this spec adds under `docs/design/boards/` is named
  there by file name; `scripts/check-specs.sh` fails on a board no spec
  names.
- "Not drawn" lists every state a criterion names that no board draws, with
  the text style it uses. "Not drawn: nothing" is written only after walking
  the criteria against the boards. Whole-screen states (a grid, a loading
  skeleton, a sheet) need a board, not a sentence.
- Every DR listed either holds on the boards or has a named deviation. Measure
  the boards: sizes, radii, shadows, tints, type floors, scrim opacity.
- Boards carry no element the spec says does not ship. Board identifier
  comments match the identifier list.
- A composite board (states that never appear together) says so in the spec
  and in a comment on the board.

## Identifiers and test plan

- Every identifier used in a criterion is in the identifier list and every
  listed identifier is used by a criterion.
- One row per criterion. Layer is `device` only when no fake or stub can
  reach the behaviour, and the row says why.
- A test the plan names can fail the criterion it sits next to.
