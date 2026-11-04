---
name: implement
description: Implement a merged spec from docs/specs end to end. Checks the spec is Accepted and unblocked, cuts the work into the fewest small shippable PRs, writes the code and one test per acceptance criterion, sets the spec to Implemented in the last diff, runs the impl-reviewer agent and hands each PR to the pr skill. Use when the user says "implement spec NNNN", "build 0013", "start on the catalogue spec", or names a spec id with code work in mind.
---

# Implementing a spec

Goal: the fewest small PRs that make every acceptance criterion of spec
NNNN true, prove each one with a test named after it, and set the spec to
Implemented in the last diff. A spec that fits one small PR ships as one.
One that does not ships as a stack, each PR built on the one before it.

Status is a claim the diff backs. Nothing tracks it on the side: no job
file, no tracker agent. `scripts/check-specs.sh` runs in CI and fails any
spec that says Implemented without a test citing every criterion. When the
last PR merges, the spec header already says Implemented.

## 1. Check the spec is ready

Read `docs/specs/NNNN-*.md`. Stop and report in
one message if any of these hold. Do not start a partial implementation.

- Status is not Accepted. A Draft has reviewer findings to resolve first,
  which is a docs PR, not this skill. If the user tells you to implement the
  Draft as written, your first commit sets Status to Accepted.
- A "Blocked on" line names something that does not exist yet, such as an
  ADR or another spec.
- "Depends on ADRs" names an ADR that is not Accepted in `docs/adr/README.md`.
- "Builds on specs" names a spec that is not Implemented. Say which one.
- The Design section has a non-empty "Not drawn" list. Those states get
  drawn on the canvas and the section updated before code. No board, no code.

## 2. Read before writing

The spec. Every ADR it names. `docs/conventions.md`. If the spec has a
Design section, `docs/design/README.md` and every board it lists. The specs
it builds on, for type and identifier names. The files the spec touches.

## 3. Plan the proof

Before any code, write a coverage table to the scratchpad with one row per
criterion: AC id, layer from the spec's test plan, test name, file. At least
one test per criterion. Names follow `docs/conventions.md`:
`@Test("NNNN/AC-3 short name")` in swift-testing, a `// NNNN/AC-3` comment on
an XCUITest. Rows whose layer is `device` go under "Not covered and why" in
the PR body with the reason the spec gives.

A criterion you cannot see how to test is a spec problem. Stop and report it
instead of writing a test that cannot fail.

## 4. Cut the stack

Add a PR column to the table. A group of criteria is one PR when all of
these hold:

- Main is shippable after it merges on its own: builds green, tests green,
  no screen the user can reach that is half wired. A model with no UI yet
  is fine. A button that does nothing is not.
- The criteria belong together for a reviewer. Usually that is one layer
  (core models and parsing, then app wiring, then UI) or one design board.
- A reviewer can read it in one sitting. Past about 400 changed lines,
  fixtures excluded, look for a seam. Past 800 there is one.

A spec that fits one group is a stack of one. Otherwise write the stack to
the scratchpad: position, branch, criteria, and what main can do once it
merges. Each PR builds on the previous one, so order them by dependency,
core before Apps. Rebase-merge keeps every commit, so a slice that is not
shippable on its own cannot hide behind a later one.

## 5. Branch

```sh
git fetch origin
git checkout -b feat/NNNN-slug origin/main
```

The slug is the spec file's slug. In a stack the branches are
`feat/NNNN-slug-1`, `feat/NNNN-slug-2` and so on, and slice k branches from
slice k-1, not from main, created with `gh stack init` and `gh stack add`
as the `pr` skill's "Stacks" section says. Work one ahead: open slice k+1
while k is in review, but do not start k+2 until k has merged.

## 6. Build

- AntennaCore first, with its tests, then Apps. All parsing and protocol
  logic stays in the package (ADR-0005).
- Accessibility identifiers use the board's prefix (DR-11).
- Stay inside Scope. When the spec needs something it does not say, do not
  invent it. Add the question under Open questions in its own
  `docs(spec)` commit. If the answer would change a criterion, stop and
  report.
- Stay inside the slice. A criterion from a later slice that turns out to
  be needed now means the cut was wrong: move it into this slice and
  update the stack plan, do not half-implement it.
- Commits follow `docs/conventions.md`: Conventional Commits, footer
  `Spec: NNNN`, spec edits in their own commit before the code. Every commit
  lands on main as is, so no WIP or fixup commits.
- Run `swift test --package-path Packages/AntennaCore` after each core
  change. If the local toolchain cannot run it, say so and rely on CI.

## 7. Claim the status

The last PR of the stack sets `- Status: Implemented` in the spec header.
Every other PR sets `- Status: In progress (AC-a..AC-b in this PR)`. The
header is the only place status lives; there is no index row to update.

```sh
bash scripts/check-specs.sh
```

Fix until it prints `ok`.

## 8. Review

Run the `impl-reviewer` agent with the spec id and the diff range:
`main...HEAD` for a stack of one or the first slice, `<previous slice
branch>...HEAD` after that. READY WITH FIXES: apply the fixes and rerun
check-specs. NOT READY: fix, run it once more; if still NOT READY, stop and
give the user its findings.

## 9. Open the PR

Hand off to the `pr` skill with the slice's position in the stack and the
branch it builds on. The PR body's "Criteria covered" table is this slice's
rows from step 3 with the final test names. Title `feat(scope): <what>`.

In a stack, go back to step 5 for the next slice once this PR is open.
When the previous slice merges, run `gh stack sync`; the `pr` skill's
"Stacks" section has the rest. After the last PR merges there is nothing
left to do for this spec.
