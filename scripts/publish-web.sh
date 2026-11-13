#!/usr/bin/env bash
# Copies Web/ to the folder given as $1 for GitHub Pages, and fills the Apple
# team id into the association file from $APPLE_TEAM_ID while the committed
# file still holds the placeholder. Exits non-zero when the id is missing or
# malformed, so the placeholder never reaches the site. Also writes the App
# Review guide for the review playlist, from yesterday (UTC) for 36 days, or
# from $REVIEW_GUIDE_START (YYYY-MM-DD) when set.
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:?usage: publish-web.sh <output folder>}
placeholder=TEAMID_PLACEHOLDER
aasa=.well-known/apple-app-site-association

mkdir -p "$out"
cp -R Web/. "$out"

if grep -q "$placeholder" "$out/$aasa"; then
  team=${APPLE_TEAM_ID:-}
  if [[ -z "$team" ]]; then
    echo "APPLE_TEAM_ID is not set and $aasa still holds $placeholder" >&2
    exit 1
  fi
  if [[ ! "$team" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "APPLE_TEAM_ID must be ten capital letters or digits" >&2
    exit 1
  fi
  sed "s/$placeholder/$team/" "$out/$aasa" >"$out/$aasa.tmp"
  mv "$out/$aasa.tmp" "$out/$aasa"
fi

if ! python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$out/$aasa"; then
  echo "$aasa is not valid JSON" >&2
  exit 1
fi

yesterday='import datetime; print(datetime.datetime.now(datetime.timezone.utc).date() - datetime.timedelta(days=1))'
start=${REVIEW_GUIDE_START:-$(python3 -c "$yesterday")}
python3 scripts/make-review-guide.py Web/review/antenna-review.m3u "$start" 36 >"$out/review/guide.xml"
