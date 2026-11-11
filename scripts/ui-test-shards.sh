#!/usr/bin/env bash
# Splits the UI tests in a directory into N shards for parallel CI jobs.
# Prints one line per shard: the xcodebuild -only-testing arguments for it.
# Tests are dealt round-robin by method, because one class can hold most of
# a target's tests (ShellUITests on tvOS).
#
#   scripts/ui-test-shards.sh Apps/UITests AntennaUITests 3
set -euo pipefail
dir=$1 target=$2 count=$3

tests=()
while IFS= read -r t; do tests+=("$t"); done < <(
  for f in "$dir"/*.swift; do
    awk -v target="$target" '
      match($0, /^[[:space:]]*(final[[:space:]]+)?(class|extension)[[:space:]]+[A-Za-z0-9_]+/) {
        n = split(substr($0, RSTART, RLENGTH), words, /[[:space:]]+/)
        cls = words[n]
      }
      match($0, /func[[:space:]]+test[A-Za-z0-9_]*[[:space:]]*\(/) && cls != "" {
        name = substr($0, RSTART, RLENGTH)
        sub(/^func[[:space:]]+/, "", name); sub(/[[:space:]]*\($/, "", name)
        print target "/" cls "/" name
      }' "$f"
  done | sort)

(( ${#tests[@]} > 0 )) || { echo "no tests found in $dir" >&2; exit 1; }
for ((s = 0; s < count; s++)); do
  line=""
  for ((i = s; i < ${#tests[@]}; i += count)); do
    line+="-only-testing:${tests[i]} "
  done
  printf '%s\n' "${line% }"
done
