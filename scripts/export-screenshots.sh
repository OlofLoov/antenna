#!/usr/bin/env bash
# Exports the screenshot walk-throughs' steps from result bundles as
# <out>/<device>/<test>/<nn>-<step>.png (add-app-screenshots-ci).
# Only attachments named <nn>-<step> are kept, so failure snapshots and
# debug descriptions stay out. A test method testFirstRun becomes firstRun.
#
# Usage: scripts/export-screenshots.sh <out-dir> <bundle.xcresult>...
set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "usage: $0 <out-dir> <bundle.xcresult>..." >&2
    exit 64
fi

out=$1
shift
mkdir -p "$out"
raw=$(mktemp -d)
trap 'rm -rf "$raw"' EXIT

count=0
for bundle in "$@"; do
    dir="$raw/$(basename "$bundle" .xcresult)"
    mkdir -p "$dir"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$dir" --filter '*.png' > /dev/null
    while IFS=$'\t' read -r test device file name; do
        step=$(printf '%s' "$name" | sed -nE 's/^([0-9]{2}-[A-Za-z0-9-]+)(_[0-9]+_[0-9A-F-]+)?\.png$/\1/p')
        [ -n "$step" ] || continue
        method=${test##*/}
        method=${method%()}
        method=${method#test}
        method="$(printf '%s' "${method:0:1}" | tr '[:upper:]' '[:lower:]')${method:1}"
        folder=$(printf '%s' "$device" | sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//')
        mkdir -p "$out/$folder/$method"
        cp "$dir/$file" "$out/$folder/$method/$step.png"
        count=$((count + 1))
    done < <(jq -r '.[] | .testIdentifier as $t | .attachments[] | [$t, .deviceName, .exportedFileName, .suggestedHumanReadableName] | @tsv' "$dir/manifest.json")
done

echo "Exported $count screenshots to $out"
find "$out" -name '*.png' | sort
