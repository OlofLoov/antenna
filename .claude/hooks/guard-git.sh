#!/usr/bin/env bash
# PreToolUse hook for Bash. Denies commits on main and pushes to main so that
# every change reaches main through a pull request. Evaluates each line of
# the command on its own so prose in heredocs does not trip it.
#
# The branch is read in the directory the git command runs in: the shell's
# working directory, moved by any `cd` before it and by `git -C`. Each
# worktree has its own branch, so a worktree on a feature branch can commit
# while another checkout sits on main.
set -u
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
[[ -d "$dir" ]] || dir="${CLAUDE_PROJECT_DIR:-$PWD}"

deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Resolves a path as `cd` would from $1. Prints nothing when it does not exist.
resolve() {
  local from=$1 to=$2
  to=${to%\"}; to=${to#\"}; to=${to%\'}; to=${to#\'}
  [[ "$to" == "~"* ]] && to="$HOME${to#\~}"
  [[ "$to" != /* ]] && to="$from/$to"
  (cd "$to" 2>/dev/null && pwd)
}

branch_in() {
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ""
}

git_word='(^|[^[:alnum:]_./-])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?'

while IFS= read -r line; do
  segments=${line//&&/$'\n'}
  segments=${segments//||/$'\n'}
  segments=${segments//;/$'\n'}
  while IFS= read -r seg; do
    seg="${seg#"${seg%%[![:space:]]*}"}"
    if [[ "$seg" =~ ^cd[[:space:]]+([^[:space:]]+) ]]; then
      moved=$(resolve "$dir" "${BASH_REMATCH[1]}")
      [[ -n "$moved" ]] && dir=$moved
      continue
    fi
    here=$dir
    if [[ "$seg" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
      other=$(resolve "$dir" "${BASH_REMATCH[1]}")
      [[ -n "$other" ]] && here=$other
    fi
    if [[ "$seg" =~ ${git_word}commit([[:space:]]|$) && "$(branch_in "$here")" == "main" ]]; then
      deny "On main. Create a branch (feat/<change-name>, fix/<slug>, chore/<slug>) before committing. Everything lands through a PR."
    fi
    if [[ "$seg" =~ ${git_word}push([[:space:]]|$) ]]; then
      if [[ "$seg" =~ [[:space:]](origin[[:space:]]+)?(HEAD:)?main([[:space:]]|$) ]]; then
        deny "Pushing to main is not allowed. Push the feature branch and open a PR with the pr skill."
      fi
      if [[ "$(branch_in "$here")" == "main" && ! "$seg" =~ [[:space:]]origin[[:space:]]+[^[:space:]]+ ]]; then
        deny "On main with no explicit target. Push a feature branch and open a PR with the pr skill."
      fi
    fi
  done <<< "$segments"
done <<< "$cmd"
exit 0
