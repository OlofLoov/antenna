# Specs

One file per feature, named `NNNN-slug.md` with a four-digit number. Status
lifecycle: Draft → Accepted → In progress → Implemented → Superseded.

A spec is Accepted when the `spec-reviewer` agent has passed it and every
acceptance criterion is testable. It is Implemented when a PR has merged with
a test per criterion. The implementing PR sets the `- Status:` line in the
spec header itself. In progress is for a spec shipping as a stack of PRs;
every PR but the last uses it, with a `- Progress:` line under Status that
names the criteria merged so far. Status itself is always one bare word.

## No index file

The status line in each spec is the only record. This folder has no table
to keep in step, because a table that every spec PR appends a row to
conflicts with every other open spec PR. Print the index when you need it:

```sh
scripts/spec-index.sh           # id, title, status
scripts/spec-index.sh --boards  # each design board and the specs naming it
scripts/spec-index.sh --next    # next free number, open spec branches included
```

Take a new number from `--next`. It counts `docs/spec-NNNN-*` branches on
origin as well as merged files, so two spec PRs open at once do not both
claim the same number.

`scripts/check-specs.sh` runs in CI and in the `pr` skill. It fails when a
spec has no known status, when a spec marked Implemented has a criterion
with no Swift test citing `NNNN/AC-n`, when a Design section names a board
file that does not exist, or when a board is named by no spec. Criteria
whose test-plan layer is `device` are exempt. The `implement` skill runs
this loop.

`scripts/lint-spec.sh` checks structure: a bare status word, Given/When/Then
per criterion, a test plan row per criterion, cross-references that resolve,
board files that exist. It runs in CI and is step 6 of the `spec` skill,
together with the self-review checklist in `.claude/skills/spec/checklist.md`.

Template: [0000-template.md](0000-template.md). Create new ones with the `spec` skill.
