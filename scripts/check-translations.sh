#!/usr/bin/env bash
# Fails when a String Catalog key has no text, or a short plural set, in a
# language listed in Config/languages, or when a key is stale. Names the
# file, the key and the language. Needs Python 3, not Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/translations.py check "$@"
