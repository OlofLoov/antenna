#!/usr/bin/env bash
# PreToolUse hook for Bash. Denies commits on main and pushes to main so that
# every change reaches main through a pull request. Evaluates each line of
# the command on its own so prose in heredocs does not trip it.
set -u
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

git_word='(^|[^[:alnum:]_./-])git[[:space:]]+'

while IFS= read -r line; do
  if [[ "$line" =~ ${git_word}commit([[:space:]]|$) && "$branch" == "main" ]]; then
    deny "On main. Create a branch (feat/<change-name>, fix/<slug>, chore/<slug>) before committing. Everything lands through a PR."
  fi
  if [[ "$line" =~ ${git_word}push([[:space:]]|$) ]]; then
    if [[ "$line" =~ [[:space:]](origin[[:space:]]+)?(HEAD:)?main([[:space:]]|$) ]]; then
      deny "Pushing to main is not allowed. Push the feature branch and open a PR with the pr skill."
    fi
    if [[ "$branch" == "main" && ! "$line" =~ [[:space:]]origin[[:space:]]+[^[:space:]]+ ]]; then
      deny "On main with no explicit target. Push a feature branch and open a PR with the pr skill."
    fi
  fi
done <<< "$cmd"
exit 0
