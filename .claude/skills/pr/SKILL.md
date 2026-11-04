---
name: pr
description: Commit the current work with a conventional message and open a pull request, on its own or as one slice of a stack. Use whenever implementation work is finished, including an ADR or spec with no code, or the user says "commit", "PR", "ship it", "open a pull request". Every change reaches main through this skill.
---

# Commit and open a PR

Nothing lands on main directly. A git hook and a Claude Code hook both
refuse it. This skill is the only path. Main is rebase-merged, so every
commit on the branch lands on main exactly as pushed.

## 1. Branch

If on `main`, create a branch first. Naming:

| Change | Branch |
|--------|--------|
| Feature from spec NNNN | `feat/NNNN-slug` |
| Slice k of a stacked feature | `feat/NNNN-slug-k`, from slice k-1 |
| Bug fix | `fix/slug` or `fix/NNNN-slug` |
| ADR only | `docs/adr-NNNN-slug` |
| Spec only | `docs/spec-NNNN-slug` |
| CI, tooling, skills | `chore/slug` or `ci/slug` |

## 2. Verify

- `swift test --package-path Packages/AntennaCore` must pass. Paste the
  failing output and stop if it does not.
- `bash scripts/check-specs.sh` must print `ok`. It fails when a spec says
  Implemented without a test citing every criterion, or when the spec header
  and the README row disagree.
- If Apps/ changed, the iOS build must pass (see the `sim` skill).
- If a spec exists for this work, run the `impl-reviewer` agent and fix
  READY WITH FIXES items before continuing. NOT READY stops here.

## 3. Commit

Conventional Commits, enforced by `scripts/lint-commit.sh`:

```
<type>(<scope>): <subject>        # <= 72 chars, imperative, no trailing period

<body: what and why, not how>

Spec: NNNN          # when applicable
ADR: NNNN           # when created or changed
```

Types: feat, fix, docs, refactor, test, build, ci, chore, perf, style, revert.
Scopes: core, app, tv, mobile, adr, spec, ci, build, docs.

One logical change per commit. Specs and ADRs that accompany a feature go in
their own commit before the code. No WIP, fixup or "address review"
commits: fold them into the commit they fix before pushing. Run
`git diff --cached` and read it before committing. Never `--no-verify`.

## 4. Push and open

```sh
git push -u origin <branch>
gh pr create --title "<same conventional header as the main commit>" --body-file <tmp>
```

The body follows `.github/pull_request_template.md`. Fill every section.
For a docs-only PR the criteria table says "n/a, no code" and the smoke
section is deleted. Put the spec and ADR links in the body.

If `gh` is not authenticated, print the branch name and the body and tell
the user to run `gh auth login`.

## 5. Report

Give the PR URL and the one-line result of each verification step.

## Stacks

A feature too big for one small PR ships as a stack. The `implement` skill
decides the cut; this skill opens and maintains the PRs. Each slice's branch
starts from the previous slice, and its base on GitHub is that branch.

Opening slice k:

```sh
gh pr create --base feat/NNNN-slug-<k-1> --title "..." --body-file <tmp>
```

The body's first line is `Stack: k of n, builds on #<PR of slice k-1>.`
Slice 1 has base `main` and says `Stack: 1 of n.` The criteria table lists
only this slice's rows. Every slice but the last sets the spec to
`In progress`; only the last says Implemented.

When slice k-1 merges, GitHub deletes its branch and retargets slice k to
main. Rebase slice k so it no longer carries the merged commits, then
confirm the base:

```sh
git fetch origin
git rebase --onto origin/main feat/NNNN-slug-<k-1> feat/NNNN-slug-<k>
git push --force-with-lease
gh pr view --json baseRefName
```

The local branch of slice k-1 is the rebase boundary, so keep it until this
is done. When review changes slice k-1 while slice k is open, fix k-1,
then rebase k onto the new k-1 with the same `--onto` form and force-push.
Never force-push a branch that someone else has commits on.
