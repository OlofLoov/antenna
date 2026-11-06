#!/usr/bin/env bash
# Fails when Swift code cites a requirement that is not in openspec/specs.
# A citation is <capability>/<requirement-slug>, where the slug is the
# requirement name lowercased with each run of other characters turned into
# one hyphen. Only capabilities with a main spec are checked; citations of
# capabilities that exist only in an active change are left alone.
set -euo pipefail
cd "$(dirname "$0")/.."

valid=$(mktemp)
cited=$(mktemp)
trap 'rm -f "$valid" "$cited"' EXIT

for spec in openspec/specs/*/spec.md; do
    capability=$(basename "$(dirname "$spec")")
    sed -n 's/^### Requirement: //p' "$spec" | while IFS= read -r name; do
        slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
        printf '%s/%s\n' "$capability" "$slug"
    done
done | sort -u >"$valid"

capabilities=$(find openspec/specs -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | paste -sd'|' -)
if [ -z "$capabilities" ]; then
    echo "no capabilities under openspec/specs"
    exit 1
fi

grep -rhoE "(^|[^a-z0-9/-])($capabilities)/[a-z0-9][a-z0-9-]*" Apps Packages --include='*.swift' |
    sed -E 's/^[^a-z]*//' | sort -u >"$cited" || true

missing=$(comm -23 "$cited" "$valid")
if [ -n "$missing" ]; then
    echo "These citations name no requirement in openspec/specs:"
    printf '%s\n' "$missing"
    exit 1
fi
echo "ok: all $(wc -l <"$cited" | tr -d ' ') cited requirements exist"
