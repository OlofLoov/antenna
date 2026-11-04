---
name: pr
description: Commit the current work with a conventional message and open a pull request. Use whenever implementation work is finished, including an ADR or spec with no code, or the user says "commit", "PR", "ship it", "open a pull request". Every change reaches main through this skill.
---

# Commit and open a PR

Nothing lands on main directly. A git hook and a Claude Code hook both
refuse it. This skill is the only path.

## 1. Branch

If on `main`, create a branch first. Naming:

| Change | Branch |
|--------|--------|
| Feature from spec NNNN | `feat/NNNN-slug` |
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
their own commit before the code. Run `git diff --cached` and read it before
committing. Never `--no-verify`.

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
