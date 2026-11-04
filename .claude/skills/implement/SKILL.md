---
name: implement
description: Implement a merged spec from docs/specs end to end. Checks the spec is Accepted and unblocked, branches, writes the code and one test per acceptance criterion, sets the spec to Implemented in the same diff, runs the impl-reviewer agent and hands off to the pr skill. Use when the user says "implement spec NNNN", "build 0013", "start on the catalogue spec", or names a spec id with code work in mind.
---

# Implementing a spec

Goal: one PR on `feat/NNNN-slug` that makes every acceptance criterion of
spec NNNN true, proves each one with a test named after it, and sets the
spec to Implemented in the same diff.

Status is a claim the diff backs. Nothing tracks it on the side: no job
file, no tracker agent. `scripts/check-specs.sh` runs in CI and fails any
spec that says Implemented without a test citing every criterion. When the
PR merges, the index is already right.

## 1. Check the spec is ready

Read `docs/specs/NNNN-*.md` and `docs/specs/README.md`. Stop and report in
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

## 2. Branch

```sh
git fetch origin
git checkout -b feat/NNNN-slug origin/main
```

The slug is the spec file's slug.

## 3. Read before writing

The spec. Every ADR it names. `docs/conventions.md`. If the spec has a
Design section, `docs/design/README.md` and every board it lists. The specs
it builds on, for type and identifier names. The files the spec touches.

## 4. Plan the proof

Before any code, write a coverage table to the scratchpad with one row per
criterion: AC id, layer from the spec's test plan, test name, file. At least
one test per criterion. Names follow `docs/conventions.md`:
`@Test("NNNN/AC-3 short name")` in swift-testing, a `// NNNN/AC-3` comment on
an XCUITest. Rows whose layer is `device` go under "Not covered and why" in
the PR body with the reason the spec gives.

A criterion you cannot see how to test is a spec problem. Stop and report it
instead of writing a test that cannot fail.

## 5. Build

- AntennaCore first, with its tests, then Apps. All parsing and protocol
  logic stays in the package (ADR-0005).
- Accessibility identifiers use the board's prefix (DR-11).
- Stay inside Scope. When the spec needs something it does not say, do not
  invent it. Add the question under Open questions in its own
  `docs(spec)` commit. If the answer would change a criterion, stop and
  report.
- Commits follow `docs/conventions.md`: Conventional Commits, footer
  `Spec: NNNN`, spec edits in their own commit before the code.
- Run `swift test --package-path Packages/AntennaCore` after each core
  change. If the local toolchain cannot run it, say so and rely on CI.

## 6. Claim the status

Set `- Status: Implemented` in the spec header and in its README row. When
the user has asked to split a spec over several PRs, every PR but the last
sets `In progress (AC-a..AC-b in this PR)` instead, and only the last one
says Implemented.

```sh
bash scripts/check-specs.sh
```

Fix until it prints `ok`.

## 7. Review

Run the `impl-reviewer` agent with the spec id and `main...HEAD`.
READY WITH FIXES: apply the fixes and rerun check-specs. NOT READY: fix,
run it once more; if still NOT READY, stop and give the user its findings.

## 8. Open the PR

Hand off to the `pr` skill. The PR body's "Criteria covered" table is the
table from step 4 with the final test names. Title `feat(scope): <what>`.
After merge there is nothing left to do for this spec.
