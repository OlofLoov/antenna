#!/usr/bin/env bash
# Checks that what docs/specs claims about status is backed by the tree.
#
# Reads the spec files themselves. There is no index to keep in step:
# scripts/spec-index.sh prints one on demand.
#
# For every docs/specs/NNNN-*.md other than the template:
#   - it has a "- Status:" line with a known status word,
#   - a spec marked Implemented has, for every AC-n whose test-plan layer is
#     not "device", at least one Swift file under Packages/ or Apps/ that
#     cites "NNNN/AC-n",
#   - every board its Design section names exists in docs/design/boards/.
# Every board in docs/design/boards/ must be named by at least one spec.
#
# Usage: scripts/check-specs.sh [repo-root]
# Runs in CI (Spec status job) and in the pr skill's verify step.
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
specs="$root/docs/specs"
boards="$root/docs/design/boards"
fail=0

err()  { printf 'check-specs: %s\n' "$1" >&2; fail=1; }
note() { printf 'check-specs: %s\n' "$1"; }

design_section() {
  awk '/^## Design/ { on = 1; next } /^## / { on = 0 } on' "$1"
}

design_boards() {
  design_section "$1" | grep -oE '[A-Za-z0-9_-]+\.dc\.html' | sort -u
}

for f in "$specs"/[0-9][0-9][0-9][0-9]-*.md; do
  id=$(basename "$f" | cut -c1-4)
  [[ "$id" == "0000" ]] && continue
  name=$(basename "$f")

  status=$(sed -nE 's/^- Status: *(In progress|[A-Za-z]+).*/\1/p' "$f" | head -1)
  case "$status" in
    Draft|Accepted|"In progress"|Implemented|Superseded) ;;
    "") err "$id: no '- Status:' line in $name"; continue ;;
    *)  err "$id: unknown status '$status' in $name" ;;
  esac

  for b in $(design_boards "$f"); do
    [[ -f "$boards/$b" ]] || err "$id: Design section names $b, not in docs/design/boards"
  done

  [[ "$status" == "Implemented" ]] || continue

  # Criterion ids up to a Dropped section, if any.
  acs=$(awk '/^## Dropped/ { exit } /^### AC-/ { sub(/^### /, ""); print $1 }' "$f")
  [[ -z "$acs" ]] && err "$id: Implemented but has no '### AC-n' headings"
  for ac in $acs; do
    layer=$(awk -F'|' -v ac="$ac" '
      $2 ~ "^ *"ac" *$" { gsub(/^ +| +$/, "", $3); print $3; exit }' "$f")
    case "$layer" in device*) continue ;; esac
    if ! grep -rqE --include='*.swift' "$id/$ac([^0-9a-z]|$)" "$root/Packages" "$root/Apps" 2>/dev/null; then
      err "$id: Implemented but no test cites $id/$ac (test plan layer: ${layer:-none})"
    fi
  done
done

if [[ -d "$boards" ]]; then
  # A board counts as named with or without its .dc.html extension.
  designs=$(for f in "$specs"/[0-9][0-9][0-9][0-9]-*.md; do design_section "$f"; done)
  for b in "$boards"/*.dc.html; do
    [[ -e "$b" ]] || continue
    stem=$(basename "$b" .dc.html)
    grep -qE "(^|[^A-Za-z0-9-])$stem([^A-Za-z0-9-]|$)" <<<"$designs" ||
      err "board $(basename "$b") is named by no spec's Design section"
  done
fi

if (( fail )); then
  exit 1
fi
note "ok"
