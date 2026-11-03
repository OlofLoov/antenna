---
name: adr
description: Record an architecture decision in docs/adr using the MADR template. Use when a discussion lands on a choice that is hard to reverse (data model, playback path, sync, dependency, build setup) or the user says "ADR" or "record this decision".
---

# Writing an ADR

1. Read `docs/adr/README.md` for the next number and to check whether an
   existing ADR already covers or conflicts with this decision.
2. Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-slug.md`. Slug is the
   title in kebab-case, imperative mood.
3. Fill it from the conversation. Context states the forces, not the history
   of the chat. Decision is phrased so a reviewer can tell whether a PR
   follows it. Options considered lists at least two real alternatives with
   one line each on why not.
4. Consequences must include at least one Bad. If you cannot find one, the
   decision is not recorded honestly.
5. Status is Proposed unless the user has said the decision is final.
6. Add a row to the table in `docs/adr/README.md`.
7. If this supersedes an earlier ADR, change that one's status line to
   `Superseded by NNNN` and nothing else in it.
8. If a spec triggered the decision, add the ADR number to that spec's
   "Depends on ADRs" line.
9. Hand off to the `pr` skill. A standalone ADR gets branch
   `docs/adr-NNNN-slug` and commit `docs(adr): NNNN <title>`. An ADR written
   during feature work goes in its own commit on the feature branch, ahead
   of the code.
