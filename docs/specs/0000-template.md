# NNNN. Feature title

- Status: Draft
- Date: YYYY-MM-DD
- Depends on ADRs: 0001, 0002
- Builds on specs: 0013, 0014
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-n, US-m (from `docs/product/user-stories.md`)

## Summary

Three to five plain sentences for someone who has never seen the code: who
this is for, what they can do once it ships, and what it deliberately does
not do. A reader who stops here knows what the feature is.

## Design

Boards: `docs/design/boards/<Board>.dc.html`, one per platform the spec covers (list them with `scripts/spec-index.sh --boards`). Write "none, no UI" for a core-only spec.
Design rules that apply: DR-n, DR-n (from `docs/design/README.md` section 5).

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

What the user cannot do today and why it matters. Three sentences.

## Scope

In:
- ...

Out (explicitly):
- ...

## User flow

Numbered steps from the user's point of view, per platform where they differ. Keep it short.

## Acceptance criteria

5 to 12 criteria. Each is behaviour a user or a caller can observe, testable on its own, with a stable id. Titles say what the user gets. Do not renumber; a removed criterion goes under Dropped.

### AC-1 Short name
Given ...
When ...
Then ...

### AC-2 Short name
Given ...
When ...
Then ...

## Edge cases

Only the ones a user would notice: offline, slow or huge source, malformed data, credential missing, sync change while open. The implementation plan decides the rest.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core / integration / ui / device |

## Open questions

- ...

## Notes for the plan

Optional. Facts the implementation plan must not lose: a signature agreed with another spec, a security rule, a number the owner chose. The only section where technical detail belongs.
