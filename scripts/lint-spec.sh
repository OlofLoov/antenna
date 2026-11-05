#!/usr/bin/env bash
# Mechanical checks on docs/specs/NNNN-*.md, the ones every spec-reviewer
# round kept finding. Run before the reviewer so it can spend its findings on
# meaning.
#
# Errors (exit 1):
#   - Status is not a bare lifecycle word (Draft, Accepted, In progress,
#     Implemented, Superseded).
#   - An AC-n block lacks a Given, When or Then.
#   - The test plan lacks a row for an AC-n, or has a row for one that does
#     not exist (criteria under "## Dropped" need no row).
#   - A cross-reference NNNN/AC-n names a criterion the other spec does not
#     have, live or dropped (when that spec is in the tree).
#   - A "User stories:" line names a US-n that docs/product/user-stories.md
#     does not define.
#   - A Design section names a board file that does not exist, or lacks a
#     "Boards:" line.
# Notes (printed, exit 0):
#   - More than 12 live criteria: likely implementation detail that belongs
#     in the plan (see .claude/skills/spec/checklist.md).
#   - A cross-reference to a spec that is not in the tree, or to a criterion
#     the other spec has dropped.
#   - No "User stories:" line.
#   - A "Blocked on" line that says something is not yet written.
#
# Usage: scripts/lint-spec.sh [repo-root] [spec-file ...]
set -u
root="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
shift $(( $# > 0 ? 1 : 0 ))
specs="$root/docs/specs"
boards="$root/docs/design/boards"
stories="$root/docs/product/user-stories.md"
fail=0

err()  { printf 'lint-spec: %s\n' "$1" >&2; fail=1; }
note() { printf 'lint-spec: %s\n' "$1"; }

if (( $# > 0 )); then
  files=("$@")
else
  files=()
  for f in "$specs"/[0-9][0-9][0-9][0-9]-*.md; do
    [[ "$(basename "$f")" == 0000-* ]] && continue
    files+=("$f")
  done
fi

# Prints "id|given|when|then" per criterion heading, up to a Dropped section.
criteria() {
  awk '
    /^## Dropped/ { flush(); exit }
    /^### AC-/    { flush(); id = $2; g = w = t = 0; active = 1; next }
    /^## /        { flush(); active = 0; next }
    active {
      if ($0 ~ /(^|[^A-Za-z])Given([^A-Za-z]|$)/) g = 1
      if ($0 ~ /(^|[^A-Za-z])When([^A-Za-z]|$)/)  w = 1
      if ($0 ~ /(^|[^A-Za-z])Then([^A-Za-z]|$)/)  t = 1
    }
    function flush() { if (id != "") print id "|" g "|" w "|" t; id = "" }
    END { flush() }
  ' "$1"
}

for file in "${files[@]}"; do
  name=$(basename "$file")
  id="${name:0:4}"

  status=$(sed -nE 's/^- Status: *(.*)$/\1/p' "$file" | head -1)
  case "$status" in
    Draft|Accepted|"In progress"|Implemented|Superseded) ;;
    "") err "$name: no '- Status:' line" ;;
    *)  err "$name: Status must be a bare lifecycle word, got '$status'" ;;
  esac

  stories_line=$(grep -m1 '^- User stories:' "$file")
  if [[ -z "$stories_line" ]]; then
    note "$name: no '- User stories:' line naming the stories in docs/product/user-stories.md"
  else
    while read -r us; do
      [[ -z "$us" ]] && continue
      grep -qE "^- \*\*$us\*\*" "$stories" || err "$name: names $us, not in docs/product/user-stories.md"
    done < <(grep -oE 'US-[0-9]+' <<< "$stories_line" | sort -u)
  fi

  if grep -qiE '^- Blocked on.*(not yet written|pending|unwritten)' "$file"; then
    note "$name: Blocked on names something that does not exist yet; the implement skill will refuse this spec until it does"
  fi

  acs=()
  while IFS='|' read -r ac g w t; do
    [[ -z "$ac" ]] && continue
    acs+=("$ac")
    (( g )) || err "$name: $ac has no Given"
    (( w )) || err "$name: $ac has no When"
    (( t )) || err "$name: $ac has no Then"
  done < <(criteria "$file")
  (( ${#acs[@]} )) || err "$name: no '### AC-n' headings"
  (( ${#acs[@]} > 12 )) && note "$name: ${#acs[@]} criteria; specs aim for 5 to 12, detail belongs in the plan"

  # First cell of each test plan row, expanded: "AC-4a, AC-4b" and
  # "AC-17a to AC-17d" both count as rows for each criterion they name.
  plan=$(awk '
    /^## Test plan/ { on = 1; next }
    /^## /          { on = 0 }
    on && /^\| *AC-/ {
      cell = $0; gsub(/^\| */, "", cell); sub(/ *\|.*$/, "", cell)
      gsub(/ to /, ",", cell); gsub(/ /, "", cell)
      n = split(cell, parts, ",")
      if (n == 2 && parts[1] ~ /^AC-[0-9]+[a-z]$/ && parts[2] ~ /^AC-[0-9]+[a-z]$/ &&
          substr(parts[1], 1, length(parts[1]) - 1) == substr(parts[2], 1, length(parts[2]) - 1) &&
          index($0, " to ") > 0) {
        base = substr(parts[1], 1, length(parts[1]) - 1)
        from = substr(parts[1], length(parts[1])); upto = substr(parts[2], length(parts[2]))
        letters = "abcdefghijklmnopqrstuvwxyz"
        for (i = index(letters, from); i <= index(letters, upto); i++) print base substr(letters, i, 1)
      } else {
        for (i = 1; i <= n; i++) if (parts[i] != "") print parts[i]
      }
    }' "$file")
  for ac in "${acs[@]}"; do
    grep -qxF "$ac" <<< "$plan" || err "$name: test plan has no row for $ac"
  done
  while read -r row; do
    [[ -z "$row" ]] && continue
    printf '%s\n' "${acs[@]}" | grep -qxF "$row" || err "$name: test plan row $row names a criterion that does not exist"
  done <<< "$plan"

  while read -r ref; do
    other="${ref%%/*}"; ac="${ref#*/}"
    [[ "$other" == "$id" ]] && continue
    target=""
    for candidate in "$specs"/"$other"-*.md; do
      [[ -f "$candidate" ]] && { target="$candidate"; break; }
    done
    if [[ -z "$target" ]]; then
      note "$name: cites $ref but spec $other is not in the tree"
      continue
    fi
    grep -qE "^### $ac( |$)" "$target" && continue
    if awk '/^## Dropped/ { on = 1; next } /^## / { on = 0 } on' "$target" | grep -qE "(^|[^A-Za-z0-9-])$ac([^A-Za-z0-9]|$)"; then
      note "$name: cites $ref, which $(basename "$target") has dropped; cite the spec by number"
    else
      err "$name: cites $ref but $(basename "$target") has no $ac"
    fi
  done < <(grep -oE '\b[0-9]{4}/AC-[0-9]+[a-z]?\b' "$file" | sort -u)

  if grep -q '^## Design' "$file"; then
    design=$(awk '/^## Design/ { on = 1; next } /^## / { on = 0 } on' "$file")
    grep -q '^Boards:' <<< "$design" || err "$name: Design section has no 'Boards:' line"
    while read -r board; do
      [[ -f "$boards/$board" ]] || err "$name: Design names $board, not in docs/design/boards"
    done < <(grep -oE '[A-Za-z0-9-]+\.dc\.html' <<< "$design" | sort -u)
  fi
done

if (( fail )); then
  exit 1
fi
note "ok"
