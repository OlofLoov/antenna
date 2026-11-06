#!/usr/bin/env bash
# Greps for the CLAUDE.md hard constraints the compiler does not catch. Exit 1 on any hit.
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

check "AntennaCore imports no UI framework" \
  '^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+(SwiftUI|SwiftData|UIKit|AppKit|WatchKit|TVUIKit)\b' \
  Packages/AntennaCore/Sources

check "no @Attribute(.unique) in SwiftData models" \
  '@Attribute\(([^)]*\.unique)' \
  Apps

check "no availability checks below 26" \
  '(@available|#available|#unavailable)\([^)]*\b(iOS|tvOS|macOS|macCatalyst|visionOS)[[:space:]]+([0-9]|1[0-9]|2[0-5])(\.[0-9]+)?\b' \
  Apps Packages/AntennaCore/Sources

check "no password or token in print/log calls" \
  '\b(print|debugPrint|NSLog|os_log|Logger\(\)\.[a-z]+|logger\.[a-z]+)\(.*(password|token|secret)' \
  Apps Packages/AntennaCore/Sources

# Like check, but hits in files matching the extended regex $3 are allowed.
check_except() {
  local name="$1" pattern="$2" allowed="$3"
  shift 3
  local hits
  hits=$(grep -rnE --include='*.swift' "$pattern" "$@" | grep -vE "^($allowed):" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)
  if [[ -n "$hits" ]]; then
    printf 'FAIL %s\n%s\n\n' "$name" "$hits"
    status=1
  else
    printf 'ok   %s\n' "$name"
  fi
}

word='(^|[^A-Za-z0-9_])'
end='([^A-Za-z0-9_]|$)'

check_except "conventions: Apple's player types only in the engine's files" \
  "${word}(AVPlayer|AVQueuePlayer|AVPlayerItem|AVPlayerViewController|VideoPlayer)${end}" \
  'Apps/Shared/Player/AVPlayerEngine(\+[A-Za-z]+)?\.swift' \
  Apps

check_except "conventions: AVPlayerLayer only in the engine and the player surface" \
  "${word}AVPlayerLayer${end}" \
  'Apps/Shared/Player/(AVPlayerEngine(\+[A-Za-z]+)?|PlayerSurfaceView)\.swift' \
  Apps

exit "$status"
