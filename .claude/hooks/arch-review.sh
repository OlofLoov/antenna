#!/usr/bin/env bash
# Before Claude runs `git commit` or `gh pr create`, runs
# scripts/check-arch.sh on the branch plus staged changes. When it flags the
# change, injects a reminder to run the arch-reviewer agent. Never blocks.
set -u
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

if ! [[ "$cmd" =~ (^|[^[:alnum:]_./-])git[[:space:]]+commit([[:space:]]|$) ]] &&
  ! [[ "$cmd" =~ (^|[^[:alnum:]_./-])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$) ]]; then
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[[ -z "$root" ]] && exit 0
report=$(cd "$root" && ARCH_MSG="$cmd" bash scripts/check-arch.sh --staged 2>&1) && exit 0

jq -cn --arg c "arch-review: this change touches architectural paths without an ADR or diagram update.
$report

Before this commit or PR, run the arch-reviewer agent on the branch. Act on its verdict: update docs/architecture/ or add an ADR, add an \"ADR: NNNN\" trailer for the decision the change follows, or add \"Arch-Impact: none\". A VIOLATION verdict stops the commit." \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'
exit 0
