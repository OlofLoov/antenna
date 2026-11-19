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

check "app-release: the app never names the App Review playlist or guide" \
  '(antenna-review|code-crave\.se/review)' \
  Apps

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

check "localization: directional symbols use backward and forward" \
  '"(chevron|arrow)\.(left|right)(\.(circle|square))?(\.fill)?"' \
  Apps

check_except "localization: no fixed date format outside the parsers and test fixtures" \
  'dateFormat[[:space:]]*=' \
  'Packages/AntennaCore/Sources/AntennaCore/(Parsers|Stalker|Xtream)/[A-Za-z+]+\.swift|Apps/Shared/Debug/[A-Za-z+]+\.swift|Apps/(Tests|TVTests)/[A-Za-z+]+\.swift' \
  Apps Packages/AntennaCore/Sources

check_except "localization: UI tests launch through launchInEnglish()" \
  '\.launch\(\)' \
  'Apps/UITests/LaunchInEnglish\.swift' \
  Apps/UITests Apps/TVUITests Apps/Journeys Apps/TVJourneys

check_except "app-intents: Siri and Shortcuts types only in Apps/Shared/Intents, never on Apple TV" \
  "${word}(AppIntent|AppEntity|AppEnum|AppShortcutsProvider)${end}" \
  'Apps/Shared/Intents/[A-Za-z]+\.swift' \
  Apps/Shared Apps/TV Apps/TopShelf

# Fails on a line matching $2 that sits outside every #if DEBUG block, so
# the code it names never reaches a Release build. A comment line passes.
debug_only() {
  local name="$1" pattern="$2"
  shift 2
  local hits=""
  local file out
  while IFS= read -r file; do
    out=$(awk -v pat="$pattern" -v file="$file" '
      /^[[:space:]]*#if[[:space:]]/ { depth++; stack[depth] = ($0 ~ /#if[[:space:]]+DEBUG([[:space:]]|$)/) ? "D" : "O"; next }
      /^[[:space:]]*#elseif/ { stack[depth] = "O"; next }
      /^[[:space:]]*#else/ { if (stack[depth] == "D") stack[depth] = "N"; next }
      /^[[:space:]]*#endif/ { depth--; next }
      /^[[:space:]]*\/\// { next }
      $0 ~ pat {
        inside = 0
        for (i = 1; i <= depth; i++) if (stack[i] == "D") inside = 1
        if (!inside) printf "%s:%d:%s\n", file, NR, $0
      }
    ' "$file")
    if [[ -n "$out" ]]; then hits+="$out"$'\n'; fi
  done < <(grep -rlE --include='*.swift' "$pattern" "$@" || true)
  if [[ -n "$hits" ]]; then
    printf 'FAIL %s\n%s\n\n' "$name" "$hits"
    status=1
  else
    printf 'ok   %s\n' "$name"
  fi
}

debug_only "title-metadata: the mock lookup and its sample scores only inside #if DEBUG" \
  "${word}(MockTitleLookup|DebugTitleScores)${end}" \
  Apps/Shared Apps/Mobile Apps/TV Apps/TopShelf Packages/AntennaCore/Sources

# Like check_except, but hits only print a warning with a count per file and
# never fail. refresh-visual-design turns these into failures once no file is left.
warn_except() {
  local name="$1" pattern="$2" allowed="$3"
  shift 3
  local hits
  hits=$(grep -rnE --include='*.swift' "$pattern" "$@" | grep -vE "^($allowed):" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)
  if [[ -n "$hits" ]]; then
    printf 'WARN %s: %s lines\n' "$name" "$(wc -l <<<"$hits" | tr -d ' ')"
    cut -d: -f1 <<<"$hits" | sort | uniq -c | sort -rn | sed 's/^ */  /'
    printf '\n'
  else
    printf 'ok   %s\n' "$name"
  fi
}

warn_except "design-system/type-uses-text-styles: fixed font sizes only for glyphs, number entry and guide times" \
  '\.system\(size:' \
  'Apps/Shared/Components/ZapBar/NumberBox\.swift|Apps/Shared/Debug/[A-Za-z]+\.swift' \
  Apps

warn_except "design-system/controls-use-system-styles: ButtonStyle types only in the app-drawn parts" \
  '(struct|class|enum)[[:space:]]+[A-Za-z]+(<[^>]*>)?[[:space:]]*:[^{]*\b(Primitive)?ButtonStyle\b' \
  'Apps/Shared/Components/(ChannelOverlay|ZapBar|MultiView)/[A-Za-z]+\.swift|Apps/Shared/Components/GuideGrid/GuideBlocks\.swift|Apps/Shared/Components/Groups/PasscodePad\.swift' \
  Apps

# Copy kept in a String constant skips the String Catalog. Warns until the
# app strings move to the catalog (add-localization task 2.4), then fails.
warn_except "localization: copy in views and components is not a plain String constant" \
  '(static let [A-Za-z]+ = "[A-Z][a-z]+( [A-Za-z]+)*|: String = "[A-Z][a-z]+( [A-Za-z]+)*)' \
  'Apps/Shared/(Views|Components)/[A-Za-z/]+Fixtures\.swift' \
  Apps/Shared/Views Apps/Shared/Components

exit "$status"
