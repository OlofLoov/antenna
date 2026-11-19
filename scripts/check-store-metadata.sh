#!/usr/bin/env bash
# Fails when an App Store listing in fastlane/metadata is missing, too long or names what it must not.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/store_metadata.py check "$@"
