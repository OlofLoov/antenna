#!/usr/bin/env bash
# Fails when a branch changes the architecture without touching its records.
#
# A change counts as architectural when it touches project.yml, a
# Package.swift, an entitlements file, Apps/Shared/Persistence/, the
# AntennaCore Playback/ directory, or adds a line that uses URLSession.
# Such a branch passes when it also changes docs/architecture/ or
# docs/adr/, or when one of its commits carries the trailer
# "Arch-Impact: none".
#
# Usage: scripts/check-arch.sh [base]   (default: merge base with origin/main)
# Runs in CI (Architecture records job) and in the pr skill's verify step.
set -euo pipefail
cd "$(dirname "$0")/.."

base="${1:-$(git merge-base HEAD origin/main)}"
range="$base..HEAD"

changed=$(git diff --name-only "$range")

sensitive=$(printf '%s\n' "$changed" | grep -E \
  -e '^project\.yml$' \
  -e '(^|/)Package\.swift$' \
  -e '\.entitlements$' \
  -e '^Apps/Shared/Persistence/' \
  -e '^Packages/AntennaCore/Sources/AntennaCore/Playback/' || true)

network=$(git diff -U0 "$range" -- '*.swift' | grep -E '^\+[^+].*\bURLSession\b' || true)
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

if git log --format='%(trailers:key=Arch-Impact,valueonly)' "$range" | grep -qix 'none'; then
  printf 'ok   architectural paths touched, a commit declares Arch-Impact: none\n'
  exit 0
fi

printf 'FAIL architectural change without an ADR or diagram update\n%s\n\n' "$sensitive"
printf 'Run the arch-reviewer agent. Then update docs/architecture/ or add an ADR,\n'
printf 'or add the trailer "Arch-Impact: none" to the commit if neither applies.\n'
exit 1
