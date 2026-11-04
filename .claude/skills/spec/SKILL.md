---
name: spec
description: Write or refine a feature spec in docs/specs with Given/When/Then acceptance criteria. Use when the user wants to start a feature, says "spec", "write a spec for", or describes a feature without one. Produces the spec only, never code.
---

# Writing a spec

Goal: a `docs/specs/NNNN-slug.md` file whose acceptance criteria a test can
cite and a reviewer can check without talking to the author.

## Steps

1. Read `docs/specs/README.md` for the next number and `docs/adr/README.md`
   for decisions the feature must respect. Read `docs/specs/0000-template.md`.
   For anything with a screen, read `docs/design/README.md` and the board
   file for that screen. No board means the design is not settled: say so
   and stop; the board comes first.
2. Interview before writing. Ask the user, in one message, only the questions
   whose answers change the criteria. Typical ones for this app:
   - Which platforms, and does tvOS differ (focus, no keyboard, remote)?
   - What happens offline or when the source is slow?
   - What is explicitly out of scope?
   - Does it touch SwiftData schema or credentials? If yes, an ADR is likely.
3. Write the spec from the template. Rules:
   - Every criterion is one Given/When/Then with a stable `AC-n` id.
   - A criterion names observable behaviour, not implementation.
   - If a criterion cannot be tested at core, integration or UI level, mark
     its layer `device` and say why.
   - Out-of-scope is a list, not a sentence.
   - The Design section names every board the spec covers and the DR ids
     that apply. Sizes and states in criteria come from the board's inline
     styles, not from memory.
4. Fill the test plan table with a layer per criterion.
5. Add a row to the table in `docs/specs/README.md` with status Draft.
6. Run the `spec-reviewer` agent on the file and apply its edits. Repeat
   once if the verdict was REWORK.
7. Hand off to the `pr` skill: branch `docs/spec-NNNN-slug`, commit
   `docs(spec): add NNNN <title>`, open the PR. The spec is reviewed and
   merged before any implementation starts. Do not write code or tests in
   this skill.

## Refining an existing spec

When asked to refine, read the spec and the reviewer's findings, change only
what the findings require, never renumber criteria, and append removed
criteria under a "Dropped" heading with a reason.
