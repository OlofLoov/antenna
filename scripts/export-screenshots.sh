#!/usr/bin/env bash
# Exports the screenshot walk-throughs' steps from result bundles as
# <out>/<device>/<test>/<nn>-<step>.png (add-app-screenshots-ci).
# With --store, exports only the testStore walk as the App Store set for
# each listed store locale: <out>/<locale>/<nn>-<device>-<step>.png, and
# <out>/<locale>/appleTV/<nn>-<step>.png for Apple TV (add-store-localization)
# and <out>/<locale>/mac/<nn>-<step>.png for the Mac (polish-store-screenshots).
# Only attachments named <nn>-<step> are kept, so failure snapshots and
# debug descriptions stay out. A test method testFirstRun becomes firstRun.
#
# Usage: scripts/export-screenshots.sh [--store <locale,...>] <out-dir> <bundle.xcresult>...
set -euo pipefail

store=""
if [ "${1:-}" = "--store" ]; then
    store=${2:?"--store takes a comma-separated list of store locales"}
    shift 2
fi

if [ "$#" -lt 2 ]; then
    echo "usage: $0 [--store <locale,...>] <out-dir> <bundle.xcresult>..." >&2
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
        if [ -n "$store" ]; then
            [ "$method" = "store" ] || continue
            IFS=',' read -r -a locales <<< "$store"
            for locale in "${locales[@]}"; do
                case "$test" in
                    TVJourneys/*) target="$out/$locale/appleTV/$step.png" ;;
                    MacJourneys/*) target="$out/$locale/mac/$step.png" ;;
                    *) target="$out/$locale/${step:0:2}-$folder-${step:3}.png" ;;
                esac
                mkdir -p "$(dirname "$target")"
                cp "$dir/$file" "$target"
                count=$((count + 1))
            done
            continue
        fi
        mkdir -p "$out/$folder/$method"
        cp "$dir/$file" "$out/$folder/$method/$step.png"
        count=$((count + 1))
    done < <(jq -r '.[] | .testIdentifier as $t | .attachments[] | [$t, .deviceName, .exportedFileName, .suggestedHumanReadableName] | @tsv' "$dir/manifest.json")
done

echo "Exported $count screenshots to $out"
find "$out" -name '*.png' | sort
