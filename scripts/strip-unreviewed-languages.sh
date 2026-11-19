#!/usr/bin/env bash
# Release build phase: removes every <code>.lproj from the built product
# whose language is not listed in Config/reviewed-languages, so a release
# ships only languages a native speaker has reviewed. English and Base stay.
# Debug builds keep every language. Extensions in PlugIns and frameworks are
# signed on their own and run this phase in their own target.
#   strip-unreviewed-languages.sh [product-dir]
# Without an argument it reads TARGET_BUILD_DIR and WRAPPER_NAME from Xcode.
set -euo pipefail

if [[ $# -eq 0 && "${CONFIGURATION:-}" != "Release" ]]; then
  echo "strip-unreviewed-languages: ${CONFIGURATION:-no} configuration, keeping every language"
  exit 0
fi

root=$(cd "$(dirname "$0")/.." && pwd)
product=${1:-"${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}"}
reviewed=()
while IFS= read -r line; do
  line=${line//[[:space:]]/}
  if [[ -n "$line" ]]; then reviewed+=("$line"); fi
done < "$root/Config/reviewed-languages"

keep() {
  local code=$1
  [[ "$code" == "en" || "$code" == "Base" ]] && return 0
  local r
  for r in "${reviewed[@]+"${reviewed[@]}"}"; do
    [[ "$code" == "$r" ]] && return 0
  done
  return 1
}

dirs=$(find "$product" \( -name PlugIns -o -name Frameworks \) -prune -o -type d -name '*.lproj' -print)
while IFS= read -r dir; do
  [[ -n "$dir" ]] || continue
  code=$(basename "$dir" .lproj)
  if ! keep "$code"; then
    rm -rf "$dir"
    echo "strip-unreviewed-languages: removed ${dir#"$product"/}"
  fi
done <<< "$dirs"
