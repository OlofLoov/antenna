---
name: pr
description: Commit the current work with a conventional message and open a pull request, on its own or as one slice of a stack. Use whenever implementation work is finished, including a change proposal with no code, or the user says "commit", "PR", "ship it", "open a pull request". Every change reaches main through this skill.
---

# Commit and open a PR

Nothing lands on main directly. A git hook and a Claude Code hook both
refuse it. This skill is the only path. Main is rebase-merged, so every
commit on the branch lands on main exactly as pushed.

## 1. Branch

If on `main`, create a branch first. Naming:

| Change | Branch |
|--------|--------|
| Work on OpenSpec change `<name>` | `feat/<name>` |
| Slice k of a stacked change | `feat/<name>-k`, from slice k-1 |
| Bug fix | `fix/slug` |
| A change proposal only, no code | `docs/<name>` |
| CI, tooling, skills | `chore/slug` or `ci/slug` |

## 2. Verify

- `swift test --package-path Packages/AntennaCore` must pass. Paste the
  failing output and stop if it does not.
- `openspec validate --all --strict` and `bash scripts/check-spec-refs.sh`
  must pass. The second fails when a test cites a requirement that is not
  in `openspec/specs/`.
- `swift format lint --strict --recursive --parallel Apps Packages` and
  `scripts/check-rules.sh` must pass. Run `swiftlint lint --strict` too when
  it is installed; CI runs all three.
- If Apps/ changed, the iOS build must pass (see the `sim` skill).
- If the work belongs to an OpenSpec change, run `/opsx:verify <name>` and
  fix what it reports before continuing. When the work adds a dependency,
  target or architecture decision, update `docs/architecture/` with the
  `drawio` skill and record the decision in the change's `design.md`.

## 3. Commit

Conventional Commits, enforced by `scripts/lint-commit.sh`:

```
<type>(<scope>): <subject>        # <= 72 chars, imperative, no trailing period

<body: what and why, not how>

Change: <name>      # the OpenSpec change this implements, when there is one
```

Types: feat, fix, docs, refactor, test, build, ci, chore, perf, style, revert.
Scopes: core, app, tv, mobile, spec, ci, build, docs.

One logical change per commit. Proposal and spec edits that accompany a
feature go in their own commit before the code. Archiving the change
(`/opsx:archive`) goes in the last commit of its last PR. No WIP, fixup or "address review"
commits: fold them into the commit they fix before pushing. Run
`git diff --cached` and read it before committing. Never `--no-verify`.

## 4. Push and open

```sh
git push -u origin <branch>
gh pr create --title "<same conventional header as the main commit>" --body-file <tmp>
```

The body follows `.github/pull_request_template.md`. Fill every section.
For a docs-only PR the requirements table says "n/a, no code" and the smoke
section is deleted. Link the change folder in the body.

If `gh` is not authenticated, print the branch name and the body and tell
the user to run `gh auth login`.

## 5. Report

Give the PR URL and the one-line result of each verification step.

## Stacks

A change too big for one small PR ships as a stack. Its `tasks.md` groups
decide the cut; this skill opens and maintains it with GitHub stacked PRs
through the `gh stack` extension (`gh extension install github/gh-stack`).
GitHub then shows the PRs as one stack, chains their bases, retargets them
as slices merge, and can merge the stack in one operation.

Slice 1 starts the stack, each later slice is added on top:

```sh
gh stack init feat/NNNN-slug-1        # from main
gh stack add feat/NNNN-slug-<k>       # from slice k-1, after its commits
gh stack submit --auto                # push every branch, open missing PRs
```

Then set each new PR's title and body with `gh pr edit <n> --title "..."
--body-file <tmp>`, since `--auto` writes placeholder titles. The requirements
table lists only that slice's rows. Each slice ticks its tasks in the
change's `tasks.md`; only the last slice archives the change.

Branches made without `gh stack` (by hand or by another tool) become a
stack with `gh stack link <bottom> ... <top>`, using branch names or PR
numbers in order. It reuses open PRs and creates the missing ones.

Keeping it current:

- Review changed a lower slice: commit on that branch, then `gh stack
  rebase` and `gh stack push`. It cascades the rebase up the stack.
- A slice merged, or main moved: `gh stack sync` fetches, rebases the
  rest onto the new base and force-pushes with lease.
- Merging: `gh stack merge` merges everything up to the chosen PR at
  once, or nothing if any of them cannot merge.

Never force-push a branch that someone else has commits on.
