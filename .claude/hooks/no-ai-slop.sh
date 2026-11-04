#!/usr/bin/env bash
# Reminds Claude to run the no-ai-slop skill on what it just wrote.
#
# Wired as a PostToolUse hook on Write|Edit and a PreToolUse hook on Bash.
# After a file change it names the file and asks for a Detect pass. Before a
# `git commit` or `gh pr` command it does the same for the message or body.
# It checks nothing itself; it only injects the reminder as additional context.
set -u
input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty')
skill='.claude/skills/no-ai-slop/SKILL.md'

emit() {
  jq -cn --arg e "$1" --arg c "$2" \
    '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
  exit 0
}

case "$event" in
  PostToolUse)
    path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')
    [[ -z "$path" ]] && exit 0
    ext="${path##*.}"
    name="${path##*/}"
    case "${ext,,}" in
      md|markdown|txt|rst)
        emit PostToolUse "no-ai-slop: you just wrote $name. Run the Detect job from $skill on the whole file, fix every pattern it names in place, then check against eval.md. Keep the author's meaning; add no claims. Plain sentences, no em dashes, no summary ending." ;;
      json|plist|xcconfig|xcprivacy|lock|strings|entitlements|resolved|png|jpg|jpeg|gif|pdf|svg)
        exit 0 ;;
      *)
        emit PostToolUse "no-ai-slop: you just changed $name. Apply $skill to its comments, doc comments and user-facing strings only: say what the caller can rely on, cut filler words and puffery, no colon reveals, no em dashes." ;;
    esac
    ;;
  PreToolUse)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    [[ -z "$cmd" ]] && exit 0
    if [[ "$cmd" =~ (^|[^[:alnum:]_./-])git[[:space:]]+commit([[:space:]]|$) ]]; then
      emit PreToolUse "no-ai-slop: this writes a commit message. Apply $skill: subject names the change, body says what and why in plain sentences, no filler, no puffery, no em dashes, no recap line."
    fi
    if [[ "$cmd" =~ (^|[^[:alnum:]_./-])gh[[:space:]]+pr[[:space:]]+(create|edit|comment|review)([[:space:]]|$) ]]; then
      emit PreToolUse "no-ai-slop: this writes a PR body or comment. Apply $skill to it before sending: lead with the change, concrete facts over importance language, no colon reveals, no em dashes, no summary ending."
    fi
    ;;
esac
exit 0
