# NNNN. Feature title

- Status: Draft
- Date: YYYY-MM-DD
- Depends on ADRs: 0001, 0002
- Platforms: iOS, iPadOS, macOS, tvOS

## Design

Boards: `docs/design/boards/<Board>.dc.html`, one per platform the spec covers (list them with `scripts/spec-index.sh --boards`). Write "none, no UI" for a core-only spec.
Design rules that apply: DR-n, DR-n (from `docs/design/README.md` section 5).
Deviations: none, or one sentence per DR that the boards break and why.
States on the boards: focused, selected, empty, loading, error, as drawn.
Not drawn: nothing, or each state a criterion names that no board draws, with the text style it uses. Whole-screen states need a board.
Identifiers: `prefix.element`, one per element a criterion names.

## Problem

What the user cannot do today and why it matters. Three sentences.

## Scope

In:
- ...

Out (explicitly):
- ...

## User flow

Numbered steps from the user's point of view, per platform where they differ.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Short name
Given ...
When ...
Then ...

### AC-2 Short name
Given ...
When ...
Then ...

## Edge cases and failure modes

- Offline, slow source, malformed data, credential missing, sync lag.

## Test plan

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core / integration / ui / device | name or TBD |

## Open questions

- ...
