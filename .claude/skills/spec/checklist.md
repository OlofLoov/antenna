# Spec self-review

Run this on the draft before the `spec-reviewer` agent sees it. A spec says
what the feature does and why, at the level a user or a caller can observe.
How it is built (types, layout, identifiers, timings, small edge cases) goes
in the implementation plan, which the `implement` skill writes and has
reviewed. The detailed checks for that live in
`.claude/skills/implement/plan-checklist.md`.

First run `bash scripts/lint-spec.sh`. It catches the mechanical half:
status word, Given/When/Then per criterion, test plan rows, board files.

## Header

- Status is the bare lifecycle word. Review history goes in the PR body.
- "Blocked on" names only what stops acceptance. A decision owed later is a
  "Follow-up ADR" line that says what this spec assumes meanwhile.
- "Builds on specs" names specs, not their criteria. Another spec's code
  that has not shipped belongs here, not in "Blocked on"; the `implement`
  skill gates each slice on it.
- "Needs from other specs" names each revision another spec must make
  (a card in 0006's form, a row on 0023's screen), so the owner sees the
  knock-on work.
- "Depends on ADRs" lists every ADR the Scope relies on.
- "User stories" names at least one story from
  `docs/product/user-stories.md`.

## Readable by a person

- The Summary alone tells a non-developer what the feature is, who it is
  for and what it leaves out.
- Criterion titles say what the user gets, not what a test checks.
- A term a non-developer would not know (XMLTV, HLS, Xtream) is explained in
  a few words the first time.

## Size

- 5 to 12 criteria. More than 12 usually means implementation detail crept
  in, or the feature is two specs.
- Past about 150 lines, cut.

## Each criterion

- One Given, one When, one Then. Two scenarios are two criteria.
- The Then is behaviour someone can observe: what the user sees or can do,
  or what a caller gets back. A test can fail it.
- No type names, signatures, identifiers, point sizes, colours or
  millisecond budgets, unless the number is a promise to the user (for
  example "the guide covers 7 days").
- No criterion cites another spec's criterion. Say "as in 0013" if needed.

## Platforms

- Each criterion holds on every platform in the header, or names the ones it
  covers. Where tvOS differs, say what the user can do there, not how focus
  moves.

## Design

- A spec with a screen names its boards and the design rules that apply.
- No layout, sizes or states copied from the boards. The plan reads them.

## Edge cases and scope

- The edge cases a user would notice are listed: offline, slow or huge
  source, malformed data, missing credential, a sync change while open.
- Out of scope is a list.
- Every open question either changes a criterion (answer it before
  Accepted) or can be decided in the plan (say so).
