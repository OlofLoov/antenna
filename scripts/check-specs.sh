#!/usr/bin/env bash
# Checks that what docs/specs claims about status is backed by the tree.
#
# For every row in docs/specs/README.md:
#   - the Status word in the row and in the spec file agree,
#   - a spec marked Implemented has, for every AC-n whose test-plan layer is
#     not "device", at least one Swift file under Packages/ or Apps/ that
#     cites "NNNN/AC-n".
# Every spec file must have a row. A row whose file is not merged yet is
# printed and skipped, because spec PRs add their row before the file lands.
#
# Usage: scripts/check-specs.sh [repo-root]
# Runs in CI (Spec status job) and in the pr skill's verify step.
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
specs="$root/docs/specs"
readme="$specs/README.md"
fail=0

err()  { printf 'check-specs: %s\n' "$1" >&2; fail=1; }
note() { printf 'check-specs: %s\n' "$1"; }

[[ -f "$readme" ]] || { err "missing $readme"; exit 1; }

while IFS='|' read -r _ link _ status _; do
  id=$(printf '%s' "$link" | sed -nE 's/.*\[([0-9]{4})\]\(([^)]+)\).*/\1/p')
  file=$(printf '%s' "$link" | sed -nE 's/.*\[([0-9]{4})\]\(([^)]+)\).*/\2/p')
  [[ -z "$id" ]] && continue
  row_status=$(printf '%s' "$status" | awk '{print $1}')

  if [[ ! -f "$specs/$file" ]]; then
    note "$id: row present, $file not merged yet"
    continue
  fi

  file_status=$(sed -nE 's/^- Status: *([A-Za-z]+).*/\1/p' "$specs/$file" | head -1)
  if [[ -z "$file_status" ]]; then
    err "$id: no '- Status:' line in $file"
    continue
  fi
  if [[ "$file_status" != "$row_status" ]]; then
    err "$id: README says $row_status, $file says $file_status"
  fi
  [[ "$file_status" == "Implemented" ]] || continue

  # Criterion ids up to a Dropped section, if any.
  acs=$(awk '/^## Dropped/ { exit } /^### AC-/ { sub(/^### /, ""); print $1 }' "$specs/$file")
  [[ -z "$acs" ]] && err "$id: Implemented but has no '### AC-n' headings"
  for ac in $acs; do
    layer=$(awk -F'|' -v ac="$ac" '
      $2 ~ "^ *"ac" *$" { gsub(/^ +| +$/, "", $3); print $3; exit }' "$specs/$file")
    case "$layer" in device*) continue ;; esac
    if ! grep -rqE --include='*.swift' "$id/$ac([^0-9a-z]|$)" "$root/Packages" "$root/Apps" 2>/dev/null; then
      err "$id: Implemented but no test cites $id/$ac (test plan layer: ${layer:-none})"
    fi
  done
done < <(grep -E '^\| *\[[0-9]{4}\]' "$readme")

for f in "$specs"/[0-9][0-9][0-9][0-9]-*.md; do
  id=$(basename "$f" | cut -c1-4)
  [[ "$id" == "0000" ]] && continue
  grep -qE "^\| *\[$id\]" "$readme" || err "$id: $(basename "$f") has no row in README"
done

if (( fail )); then
  exit 1
fi
note "ok"
