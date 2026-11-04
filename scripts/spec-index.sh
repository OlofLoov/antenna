#!/usr/bin/env bash
# Prints the spec and board indexes from the spec files.
#
# No index is committed, so spec PRs never touch a shared file and never
# conflict with each other. Status comes from each spec's "- Status:" line,
# boards from each spec's Design section.
#
# Usage:
#   scripts/spec-index.sh           table of specs: id, title, status
#   scripts/spec-index.sh --boards  table of boards and the specs naming them
#   scripts/spec-index.sh --next    next free spec number, counting merged
#                                   specs and docs/spec-NNNN-* branches on origin
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
specs="$root/docs/specs"
boards="$root/docs/design/boards"

spec_files() {
  for f in "$specs"/[0-9][0-9][0-9][0-9]-*.md; do
    [[ "$(basename "$f" | cut -c1-4)" == "0000" ]] || printf '%s\n' "$f"
  done
}

design_section() {
  awk '/^## Design/ { on = 1; next } /^## / { on = 0 } on' "$1"
}

case "${1:-}" in
  "")
    printf '| Spec | Title | Status |\n|------|-------|--------|\n'
    spec_files | while read -r f; do
      name=$(basename "$f")
      id=${name:0:4}
      title=$(sed -nE '1s/^# [0-9]{4}\. *//p' "$f")
      status=$(sed -nE 's/^- Status: *//p' "$f" | head -1)
      printf '| [%s](%s) | %s | %s |\n' "$id" "$name" "$title" "$status"
    done
    ;;
  --boards)
    printf '| Board | Specs |\n|-------|-------|\n'
    for b in "$boards"/*.dc.html; do
      [[ -e "$b" ]] || continue
      stem=$(basename "$b" .dc.html)
      ids=$(spec_files | while read -r f; do
        design_section "$f" | grep -qE "(^|[^A-Za-z0-9-])$stem([^A-Za-z0-9-]|$)" &&
          basename "$f" | cut -c1-4
      done | paste -sd, - | sed 's/,/, /g')
      printf '| %s | %s |\n' "\`$(basename "$b")\`" "${ids:-none}"
    done
    ;;
  --next)
    merged=$(spec_files | xargs -n1 basename | cut -c1-4)
    pushed=$(git -C "$root" ls-remote --heads origin 'docs/spec-*' 2>/dev/null |
      sed -nE 's#.*refs/heads/docs/spec-([0-9]{4})-.*#\1#p')
    last=$(printf '%s\n%s\n' "$merged" "$pushed" | grep -E '^[0-9]{4}$' | sort -n | tail -1)
    printf '%04d\n' $((10#${last:-0} + 1))
    ;;
  *)
    sed -n '2,13p' "$0" >&2
    exit 2
    ;;
esac
