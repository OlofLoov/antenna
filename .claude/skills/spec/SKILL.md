---
name: spec
description: Write or refine a feature spec in docs/specs with Given/When/Then acceptance criteria. Use when the user wants to start a feature, says "spec", "write a spec for", or describes a feature without one. Produces the spec only, never code.
---

# Writing a spec

Goal: a short `docs/specs/NNNN-slug.md` that says what a feature does and
why, with 5 to 12 acceptance criteria a test can cite. It stays at the level
a user or a caller can observe. How it is built (types, layout, sizes,
identifiers, timings, small edge cases) is settled later in the
implementation plan that the `implement` skill writes and has reviewed.

Write specs just in time: for the next features to be built, not a backlog.

## Steps

1. Run `scripts/spec-index.sh --next` for the number. It counts open
   `docs/spec-NNNN-*` branches, so two specs written at once do not collide.
   Read `docs/adr/README.md` for decisions the feature must respect. Read `docs/specs/0000-template.md`.
   For anything with a screen, check that a board exists in
   `docs/design/boards/`. No board means the design is not settled: say so
   and stop; the board comes first. You do not need to measure it.
2. Interview before writing. Ask the user, in one message, only the questions
   whose answers change the criteria. Typical ones for this app:
   - Which platforms, and does tvOS differ in what the user can do?
   - What happens offline, when the source is slow, when the store is empty,
     when a credential has not synced, and when a sync change arrives while
     the screen is open?
   - What is explicitly out of scope?
   - Does it touch SwiftData schema or credentials? If yes, an ADR is likely.
   - Does a decision still have to be made (an ADR not yet written)? Then the
     spec states what it assumes meanwhile and the header carries a
     "Follow-up ADR" line, not a "Blocked on" line.
3. Write the spec from the template. Rules:
   - 5 to 12 criteria, each one Given/When/Then with a stable `AC-n` id.
   - A criterion names behaviour a user or caller can observe. No type
     names, identifiers, sizes, colours or timing budgets unless the number
     is a promise to the user.
   - Cite other specs by number, never their criteria.
   - If a criterion cannot be tested at core, integration or UI level, mark
     its layer `device` and say why.
   - Out-of-scope is a list, not a sentence.
   - The Design section names the boards and the DR ids that apply, nothing
     more.
4. Fill the test plan table with a layer per criterion. Test names come
   later, in the plan.
5. Set `- Status: Draft` in the header. There is no index row to add:
   `scripts/spec-index.sh` reads the header.
6. Self-review. Run `bash scripts/lint-spec.sh` and fix every error. Then go
   through `checklist.md` in this directory and fix what it names.
7. Run the `spec-reviewer` agent once and apply its edits. Run it again only
   if the verdict was REWORK. Do not add detail it did not ask for.
8. Hand off to the `pr` skill: branch `docs/spec-NNNN-slug`, commit
   `docs(spec): add NNNN <title>`, open the PR. The spec is reviewed and
   merged before any implementation starts. Do not write code or tests in
   this skill.

## Refining an existing spec

When asked to refine, read the spec and the reviewer's findings, change only
what the findings require, never renumber criteria, and append removed
criteria under a "Dropped" heading with a reason. Run `scripts/lint-spec.sh`
and the checklist again before handing back; a finding applied badly is the
next round's finding.

## Trimming an older draft

Drafts written before specs went to behaviour level (0017 onwards) carry
layout, types and edge-case detail. Trim one when it is picked up for
implementation, as its own `docs(spec)` PR before the plan:

- Keep criteria that describe behaviour, with their ids.
- Cut detail out of the surviving criteria: identifiers, sizes, type names,
  timing budgets. Note anything worth keeping under "Notes for the plan".
- Criteria that were only detail go under "Dropped" with the reason "moved
  to the implementation plan". Ids are never reused.
- Aim for 5 to 12 live criteria, then run `spec-reviewer` once.
