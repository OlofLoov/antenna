#!/usr/bin/env bash
# Validate a commit message against Conventional Commits.
# Usage: lint-commit.sh <file-with-message>   (git commit-msg hook)
#        lint-commit.sh - < message            (stdin, used by CI)
set -euo pipefail

if [[ "${1:-}" == "-" || -z "${1:-}" ]]; then msg=$(cat); else msg=$(cat "$1"); fi

# Drop comment lines git adds in the editor.
header=$(printf '%s\n' "$msg" | grep -v '^#' | sed -n '1p')

# Merge, revert and fixup commits are allowed through.
case "$header" in
  "Merge "*|"Revert "*|"fixup! "*|"squash! "*) exit 0 ;;
esac

types='feat|fix|docs|refactor|test|build|ci|chore|perf|style|revert'
pattern="^(${types})(\([a-z0-9._/-]+\))?!?: [^ ].*$"

fail() { printf 'commit message rejected: %s\n\n  %s\n\nExpected: <type>(<scope>)?: <subject>\n  types: %s\n  scopes (optional): core, app, tv, mobile, adr, spec, ci, build, docs\n' "$1" "$header" "$types" >&2; exit 1; }

[[ "$header" =~ $pattern ]] || fail "header does not match conventional format"
(( ${#header} <= 72 )) || fail "header longer than 72 characters"
[[ "$header" != *. ]] || fail "subject must not end with a period"
