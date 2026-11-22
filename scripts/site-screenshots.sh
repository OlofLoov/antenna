#!/usr/bin/env bash
# Picks the website's screenshots from the App Store set and writes them as
# JPEG into Web/site/static/images/<lang>/, with their sizes in
# Web/site/src/lib/screenshots.<lang>.json for the pages' width and height.
#
# Usage: scripts/site-screenshots.sh [lang] [store folder]
#   lang          the site language, en by default
#   store folder  an unpacked store-screenshots artifact; without it the newest
#                 unexpired artifact from main is downloaded with gh
#
# Each line of Web/site/static/images/screenshots.txt is
# "<platform> <store file> <site file>", platform one of appleTV, mac, iPhone
# or iPad. Apple TV and Mac pictures are resized to 1200 pixels wide, iPad to
# 900 and iPhone to 600, and written at JPEG quality 80 with sips. Exits
# non-zero when a listed file is missing from the store set. macOS only.
set -euo pipefail
cd "$(dirname "$0")/.."

lang=${1:-en}
store=${2:-}
list=Web/site/static/images/screenshots.txt
out=Web/site/static/images/$lang
sizes=Web/site/src/lib/screenshots.$lang.json

case "$lang" in
  en) locale=en-US ;;
  sv) locale=sv ;;
  *) echo "no store locale for $lang" >&2; exit 1 ;;
esac

command -v sips >/dev/null || { echo "sips not found; run this on a Mac" >&2; exit 1; }

if [[ -z "$store" ]]; then
  store=$(mktemp -d)
  trap 'rm -rf "$store"' EXIT
  run=$(gh api "repos/{owner}/{repo}/actions/artifacts?name=store-screenshots&per_page=50" \
    --jq '[.artifacts[] | select(.expired == false and .workflow_run.head_branch == "main")][0].workflow_run.id')
  if [[ -z "$run" || "$run" == null ]]; then
    echo "no unexpired store-screenshots artifact from main; run the App screenshots workflow" >&2
    exit 1
  fi
  echo "downloading store-screenshots from run $run"
  gh run download "$run" -n store-screenshots -D "$store"
fi

rm -rf "$out"
mkdir -p "$out"
missing=0
json="{"
separator=""
while read -r platform file name; do
  [[ -z "${platform:-}" || "$platform" == \#* ]] && continue
  case "$platform" in
    appleTV) source="$store/$locale/appleTV/$file"; width=1200 ;;
    mac) source="$store/$locale/mac/$file"; width=1200 ;;
    iPad) source="$store/$locale/$file"; width=900 ;;
    iPhone) source="$store/$locale/$file"; width=600 ;;
    *) echo "unknown platform $platform in $list" >&2; exit 1 ;;
  esac
  if [[ ! -f "$source" ]]; then
    echo "missing from the store set: $locale/${source#"$store/$locale/"}" >&2
    missing=1
    continue
  fi
  sips -s format jpeg -s formatOptions 80 --resampleWidth "$width" "$source" --out "$out/$name" >/dev/null
  w=$(sips -g pixelWidth "$out/$name" | awk '/pixelWidth/ { print $2 }')
  h=$(sips -g pixelHeight "$out/$name" | awk '/pixelHeight/ { print $2 }')
  json+="$separator\"$name\":{\"width\":$w,\"height\":$h}"
  separator=","
done <"$list"

if (( missing )); then
  exit 1
fi
printf '%s}\n' "$json" | python3 -m json.tool --tab >"$sizes"
ls -l "$out"
