---
name: implement
description: Implement a merged spec from docs/specs end to end. Checks the spec is Accepted and unblocked, writes an implementation plan and has the plan-reviewer agent review it, cuts the work into the fewest small shippable PRs, writes the code and one test per acceptance criterion, sets the spec to Implemented in the last diff, runs the impl-reviewer agent and hands each PR to the pr skill. Use when the user says "implement spec NNNN", "build 0013", "start on the catalogue spec", or names a spec id with code work in mind.
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
- A criterion you are about to build needs another spec's work that has
  not merged. See "What gates a slice" below. Say which criterion needs
  which.
- The Design section has a non-empty "Not drawn" list. Those states get
  drawn on the canvas and the section updated before code. No board, no code.

### What gates a slice

"Builds on specs" says where to read, not what must ship first. What gates
a slice is the work its own criteria use: another spec's criteria they
cite (`0013/AC-6a`), and the types, identifiers or behaviour they call
that another spec defines. For each criterion in the slice, list those
needs in the coverage table (step 3). A need is met when that criterion
is merged: its spec says Implemented, or In progress with the criterion
on its `- Progress:` line. A spec under "Builds on" that no criterion in
the slice uses does not gate the slice.

UI specs build on each other in both directions (0007 and 0015, 0010 and
0011), so whole-spec gating would deadlock them. Cut by criterion instead.
Ship first the criteria whose needs are met, from whichever spec has
them. A later slice picks up a criterion once what it needs has merged.
Stop only when every criterion left in the spec waits on something
unmerged, and say what each one waits on.

## 2. Read before writing

The spec. Every ADR it names. `docs/conventions.md`. If the spec has a
Design section, `docs/design/README.md` and every board it lists. For any
view work, `.claude/skills/swiftui-composition/SKILL.md` (ADR-0008): it
says which folder a view goes in and what a component may not do. The specs
it builds on, for type and identifier names. The files the spec touches.

## 3. Plan, then have the plan reviewed

The spec says what to build. Before any code, write the plan that says how,
to `plan-NNNN.md` in the scratchpad. It settles the detail the spec leaves
open:

- **Approach:** the types, functions and files, with signatures for public
  API, and which existing code changes.
- **Screens:** for each view, the board it follows, the states it draws,
  and its accessibility identifiers (DR-11 prefixes). Sizes come from the
  boards' inline styles.
- **Decisions:** each rule the spec does not make (ties, empty input,
  errors, tvOS focus and Menu, compact width), with the choice and one line
  of reason.
- **Coverage table:** one row per criterion with its approach, layer, test
  name, file, and needs (per step 1). At least one test per criterion.
  Names follow `docs/conventions.md`: `@Test("NNNN/AC-3 short name")` in
  swift-testing, a `// NNNN/AC-3` comment on an XCUITest. `device` rows go
  under "Not covered and why" in the PR body with the spec's reason.
- **Slices:** the PR cut from step 4.

`plan-checklist.md` in this directory lists what a plan must cover.

Then have it reviewed. Run the `plan-reviewer` agent with the spec id and
the plan path. Also run `arch-reviewer` when the plan adds a dependency, a
target, a SwiftData model change, a network client or anything under
`scripts/check-arch.sh`'s paths. Apply APPROVE WITH CHANGES findings and go
on. On REWORK, revise and run the reviewer once more; a second REWORK stops
here and goes to the user with the findings.

A criterion you cannot see how to test, or a decision that would change
what a criterion promises, is a spec problem. Stop and report it instead of
deciding it in the plan.

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

Criteria whose needs are unmet stay out of the stack. When the stack ends
with criteria still waiting, its last PR leaves the spec `In progress`
with a `- Progress:` line, and names what each remaining criterion waits
on in the PR body. Rerun this skill on the spec once those needs merge.

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

The PR that merges the spec's last criterion sets `- Status: Implemented`
in the spec header and deletes the `- Progress:` line. Every other PR sets a bare
`- Status: In progress` and, on the line below it, the criteria merged so
far:

```markdown
- Status: In progress
- Progress: AC-1 to AC-6 (#61), AC-7 to AC-11 in this PR
```

Status takes one word only; `scripts/lint-spec.sh` fails anything after
it. The header is the only place status lives; there is no index row to
update.

```sh
bash scripts/check-specs.sh
```

Fix until it prints `ok`.

## 8. Review

Run the `impl-reviewer` agent with the spec id, the plan path and the diff
range:
`main...HEAD` for a stack of one or the first slice, `<previous slice
branch>...HEAD` after that. READY WITH FIXES: apply the fixes and rerun
check-specs. NOT READY: fix, run it once more; if still NOT READY, stop and
give the user its findings.

## 9. Open the PR

Hand off to the `pr` skill with the slice's position in the stack and the
branch it builds on. The PR body's "Criteria covered" table is this slice's
rows from step 3 with the final test names. The body also carries a "Plan"
section: the approach and decisions from the reviewed plan, trimmed to this
slice, so the owner sees every choice the spec did not make. Title
`feat(scope): <what>`.

In a stack, go back to step 5 for the next slice once this PR is open.
When the previous slice merges, run `gh stack sync`; the `pr` skill's
"Stacks" section has the rest. After the last PR merges there is nothing
left to do for this spec.
