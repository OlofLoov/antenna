#!/usr/bin/env bash
# Flags a branch that changes the architecture without touching its records.
#
# A change counts as architectural when it touches project.yml, a
# Package.swift, an entitlements file, Apps/Shared/Persistence/, the
# AntennaCore Playback/ directory, or adds a non-test line that uses
# URLSession. Such a branch passes when it also changes docs/architecture/
# or docs/adr/, or when a commit carries the trailer "Arch-Impact: none" or
# "ADR: NNNN" naming an ADR in docs/adr/.
#
# Usage: scripts/check-arch.sh [--staged] [base]
#   base      default: merge base with origin/main
#   --staged  also count staged changes, and read trailers from $ARCH_MSG
#             (the commit about to be made). The Claude Code hook
#             .claude/hooks/arch-review.sh runs it this way before a commit.
# Exit 1 means: run the arch-reviewer agent. Nothing in CI runs this.
set -euo pipefail
cd "$(dirname "$0")/.."

staged=0
if [[ "${1:-}" == "--staged" ]]; then
  staged=1
  shift
fi
base="${1:-$(git merge-base HEAD origin/main)}"

if (( staged )); then
  diff_args=(--cached "$base")
else
  diff_args=("$base..HEAD")
fi

changed=$(git diff --name-only "${diff_args[@]}")

sensitive=$(printf '%s\n' "$changed" | grep -E \
  -e '^project\.yml$' \
  -e '(^|/)Package\.swift$' \
  -e '\.entitlements$' \
  -e '^Apps/Shared/Persistence/' \
  -e '^Packages/AntennaCore/Sources/AntennaCore/Playback/' || true)

network=$(git diff -U0 "${diff_args[@]}" -- '*.swift' ':!*/Tests/*' ':!Apps/Tests/*' |
  grep -E '^\+[^+].*\bURLSession\b' || true)
if [[ -n "$network" ]]; then
  sensitive=$(printf '%s\nnew URLSession use:\n%s\n' "$sensitive" "$network" | sed '/^$/d')
fi

if [[ -z "${sensitive//[[:space:]]/}" ]]; then
  printf 'ok   no architectural paths touched\n'
  exit 0
fi

if printf '%s\n' "$changed" | grep -qE '^docs/(architecture|adr)/'; then
  printf 'ok   architectural change comes with docs/architecture or docs/adr\n'
  exit 0
fi

messages=$(git log --format='%B' "$base..HEAD")
(( staged )) && messages=$(printf '%s\n%s\n' "$messages" "${ARCH_MSG:-}")

if printf '%s\n' "$messages" | grep -qiE '^Arch-Impact: *none *$'; then
  printf 'ok   architectural paths touched, a commit declares Arch-Impact: none\n'
  exit 0
fi

for adr in $(printf '%s\n' "$messages" | sed -nE 's/^ADR: *([0-9]{4}).*/\1/p' | sort -u); do
  if compgen -G "docs/adr/$adr-*.md" >/dev/null; then
    printf 'ok   architectural paths touched, a commit cites ADR-%s\n' "$adr"
    exit 0
  fi
done

printf 'FLAG architectural change without an ADR or diagram update\n%s\n\n' "$sensitive"
printf 'Run the arch-reviewer agent. Then update docs/architecture/ or add an ADR,\n'
printf 'cite the ADR the change follows with an "ADR: NNNN" trailer, or add\n'
printf '"Arch-Impact: none" if no record applies.\n'
exit 1
