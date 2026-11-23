#!/usr/bin/env bash
# Writes the site's final file tree into the folder given as $1.
#
# Copies the plain files in Web/ (everything but the Web/site app), fills the
# Apple team id into the association file from $APPLE_TEAM_ID while the
# committed file still holds the placeholder, and writes the App Review guide
# for the review playlist, from yesterday (UTC) for 36 days, or from
# $REVIEW_GUIDE_START (YYYY-MM-DD) when set. Exits non-zero when the id is
# missing or malformed, so the placeholder never reaches the site.
#
# With $2, the built SvelteKit app (Web/site/build after `npm run build`), it
# copies the app's pages in too, and fails when a plain file and a built file
# have the same path. Without $2 only the plain files are written, which is
# what swift test checks without Node.
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:?usage: publish-web.sh <output folder> [site build folder]}
site=${2:-}
placeholder=TEAMID_PLACEHOLDER
aasa=.well-known/apple-app-site-association

if [[ -n "$site" && ! -f "$site/index.html" ]]; then
  echo "$site holds no index.html; run npm run build in Web/site first" >&2
  exit 1
fi

mkdir -p "$out"
for entry in Web/* Web/.[!.]*; do
  [[ -e "$entry" ]] || continue
  [[ "$entry" == Web/site ]] && continue
  cp -R "$entry" "$out/"
done

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
python3 scripts/make-review-guide.py Web/review/antuna-review.m3u "$start" 36 >"$out/review/guide.xml"

if [[ -n "$site" ]]; then
  clashes=""
  while IFS= read -r path; do
    if [[ -e "$out/$path" ]]; then clashes+="$path"$'\n'; fi
  done < <(find "$site" -type f | sed "s|^${site%/}/||")
  if [[ -n "$clashes" ]]; then
    echo "These paths are both plain files in Web/ and built pages of the site:" >&2
    printf '%s\n' "$clashes" >&2
    exit 1
  fi
  cp -R "$site/." "$out"
fi
