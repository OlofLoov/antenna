#!/usr/bin/env bash
# Greps for the hard constraints in CLAUDE.md that the compiler does not catch.
# Each check names the ADR or rule it enforces. Exit 1 if any hit.
# Usage: scripts/check-rules.sh      (from the repo root; CI runs it on every PR)
set -euo pipefail
cd "$(dirname "$0")/.."

status=0

check() {
  local name="$1" pattern="$2"
  shift 2
  local hits
  hits=$(grep -rnE --include='*.swift' "$pattern" "$@" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)
  if [[ -n "$hits" ]]; then
    printf 'FAIL %s\n%s\n\n' "$name" "$hits"
    status=1
  else
    printf 'ok   %s\n' "$name"
  fi
}

# ADR-0005: AntennaCore has no UI or persistence framework imports.
check "ADR-0005 AntennaCore imports no UI framework" \
  '^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+(SwiftUI|SwiftData|UIKit|AppKit|WatchKit|TVUIKit)\b' \
  Packages/AntennaCore/Sources

# ADR-0002: CloudKit-backed SwiftData forbids unique attributes.
check "ADR-0002 no @Attribute(.unique) in SwiftData models" \
  '@Attribute\(([^)]*\.unique)' \
  Apps

# ADR-0004: deployment target is 26.0 everywhere, so no checks below it.
check "ADR-0004 no availability checks below 26" \
  '(@available|#available|#unavailable)\([^)]*\b(iOS|tvOS|macOS|macCatalyst|visionOS)[[:space:]]+([0-9]|1[0-9]|2[0-5])(\.[0-9]+)?\b' \
  Apps Packages/AntennaCore/Sources

# ADR-0003: credentials never reach SwiftData or logs. Catches the obvious
# case of a password or token being printed or logged.
check "ADR-0003 no password or token in print/log calls" \
  '\b(print|debugPrint|NSLog|os_log|Logger\(\)\.[a-z]+|logger\.[a-z]+)\(.*(password|token|secret)' \
  Apps Packages/AntennaCore/Sources

# Layering: Apps reach playback only through PlaybackEngine and EngineRouter.
check "conventions: Apps do not construct AVPlayer outside the engine" \
  'AVPlayer\(' \
  Apps/Shared/Views Apps/Mobile Apps/TV

exit "$status"
