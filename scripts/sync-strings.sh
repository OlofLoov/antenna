#!/usr/bin/env bash
# Exports the project's strings with Xcode and writes them into the String
# Catalogs: new literals are added, stale keys removed.
#   scripts/sync-strings.sh          sync the catalogs
#   scripts/sync-strings.sh --check  fail when code has a string the catalogs
#                                    lack, and leave the catalogs untouched
# Needs Xcode and a generated Antenna.xcodeproj (xcodegen generate).
# DERIVED_DATA=<path> reuses a build folder.
set -euo pipefail
cd "$(dirname "$0")/.."

mode=sync
if [[ "${1:-}" == "--check" ]]; then mode=missing; fi

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

# The export rewrites the catalogs in place. Keep the committed ones so the
# check compares against them and puts them back.
catalogs=()
while IFS= read -r file; do catalogs+=("$file"); done < <(find Apps Packages -name '*.xcstrings' -not -path '*/.build/*')
for file in "${catalogs[@]}"; do
  mkdir -p "$out/before/$(dirname "$file")"
  cp "$file" "$out/before/$file"
done

args=(-exportLocalizations -project Antenna.xcodeproj -scheme Antenna
  -localizationPath "$out/export" -exportLanguage en CODE_SIGNING_ALLOWED=NO -quiet)
if [[ -n "${DERIVED_DATA:-}" ]]; then args+=(-derivedDataPath "$DERIVED_DATA"); fi
xcodebuild "${args[@]}"

if [[ "$mode" == missing ]]; then
  for file in "${catalogs[@]}"; do cp "$out/before/$file" "$file"; done
fi
python3 scripts/translations.py "$mode" "$out/export"
