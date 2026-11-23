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

check "design-system/one-accent-color-per-profile: the accent only from the profile's accent value" \
  '(Palette\.accent|\.accentColor\b|\.(tint|foregroundStyle|fill|background)\(\.(blue|cyan|teal|mint|green|yellow|orange|pink|purple|indigo)\b)' \
  Apps

check "no availability checks below 26" \
  '(@available|#available|#unavailable)\([^)]*\b(iOS|tvOS|macOS|macCatalyst|visionOS)[[:space:]]+([0-9]|1[0-9]|2[0-5])(\.[0-9]+)?\b' \
  Apps Packages/AntennaCore/Sources

check "app-release: the app never names the App Review playlist or guide" \
  '(antuna-review|antuna\.app/review)' \
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

# An arrow typed as text keeps pointing the same way in Arabic. A
# `.backward` or `.forward` symbol mirrors.
check "localization: no arrows drawn as text" \
  'Text\("[^"]*[◂▸◀▶←→]' \
  Apps

# A sideways arrow that moves through a row picks layoutDirection's
# leadingArrow or trailingArrow, so in Arabic the right arrow goes to the
# item drawn on the right. The player's skip keys keep the physical arrows.
check_except "design-system/focus-moves-where-the-remote-points: sideways arrow keys follow the reading direction" \
  'keyboardShortcut\(\.(left|right)Arrow' \
  'Apps/Shared/Views/(Shelf/ShelfPlayerView|Live/LiveTimeshift)\.swift' \
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

check_except "design-system/type-uses-text-styles: fixed font sizes only for number entry, subtitles sized to the picture and badge initials" \
  '\.system\(size:' \
  'Apps/Shared/Components/ZapBar/NumberBox\.swift|Apps/Shared/Components/Player/SubtitleOverlay\.swift|Apps/Shared/Components/Profiles/ProfileBadge\.swift|Apps/Shared/Debug/[A-Za-z]+\.swift' \
  Apps

check_except "design-system/controls-use-system-styles: ButtonStyle types only in the app-drawn parts" \
  '(struct|class|enum)[[:space:]]+[A-Za-z]+(<[^>]*>)?[[:space:]]*:[^{]*\b(Primitive)?ButtonStyle\b' \
  'Apps/Shared/Components/(ChannelOverlay|ZapBar|MultiView)/[A-Za-z]+\.swift|Apps/Shared/Components/GuideGrid/GuideBlocks\.swift|Apps/Shared/Components/Groups/PasscodePad\.swift|Apps/Shared/Components/FocusCard\.swift' \
  Apps

# A prominent button is filled with the accent, and white on any of the
# five accents is under 2.7:1. prominentStyle(_:) gives every one the dark
# label (design-system/text-on-the-accent-is-dark).
check_except "design-system/text-on-the-accent-is-dark: prominent button styles only through prominentStyle(_:)" \
  '\.(borderedProminent|glassProminent)\b' \
  'Apps/Shared/Components/PrimaryAction\.swift' \
  Apps

# Corners come from the scale through Metrics.Corner or cornerShape(_:), never
# a literal radius (design-system/one-spacing-and-radius-scale). Metrics.swift
# defines the radii.
check_except "design-system/one-spacing-and-radius-scale: corner radii from the scale" \
  'cornerRadius: [0-9]' \
  'Apps/Shared/Components/Metrics\.swift|Apps/Shared/Debug/[A-Za-z]+\.swift' \
  Apps

# Glass belongs to the navigation layer: the tab bar, controls over video
# (the live strips, the Picture in Picture and AirPlay pair, the title
# player's track buttons) and the reminder banner that floats over every
# screen (design-system/liquid-glass-stays-on-the-navigation-layer).
# Buttons take glass through the system .glass and .glassProminent styles.
check_except "design-system/liquid-glass-stays-on-the-navigation-layer: the glass effect only on the navigation layer" \
  '\.glassEffect\(' \
  'Apps/Shared/Components/Browse/Browse(Timeshift)?Controls\.swift|Apps/Shared/Views/Live/LivePicture\.swift|Apps/Shared/Views/Shelf/TitleTrackControls\.swift|Apps/Shared/Components/Reminders/ReminderBanner\.swift' \
  Apps

# Glass alone or a plain surface alone: a view whose modifier chain applies
# glass (.glassEffect or a .glass button style) takes no .background,
# .border or .shadow, and no .overlay that strokes. The system draws the
# edge and the highlight (design-system/liquid-glass-stays-on-the-navigation-layer).
# A view's chain is the run of modifier lines at one indent. Files matching
# $2 are the named exceptions.
read -r -d '' glass_alone_py <<'PY' || true
import re
import sys

GLASS = re.compile(r"^\.(glassEffect\(|buttonStyle\(\.glass|prominentStyle\(\.glass)")
DECOR = re.compile(r"^\.(background|border|shadow)\b")
OVERLAY = re.compile(r"^\.overlay\b")
STROKE = re.compile(r"\.(stroke|strokeBorder|border)\(")


def indent(line):
    return len(line) - len(line.lstrip(" "))


def skip(line, depth):
    text = line.strip()
    if not text or text.startswith(("//", "#")):
        return True
    return indent(line) > depth or (indent(line) == depth and text[0] in "})]")


def heads(lines, at):
    depth = indent(lines[at])
    found = []
    for step in (-1, 1):
        i = at + step
        while 0 <= i < len(lines):
            if skip(lines[i], depth):
                i += step
            elif indent(lines[i]) == depth and lines[i].strip().startswith("."):
                found.append(i)
                i += step
            else:
                break
    for head in found:
        end = head + 1
        while end < len(lines) and (not lines[end].strip() or indent(lines[end]) > depth):
            end += 1
        yield head, lines[head:end]


def hits(path):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    found = set()
    for at, line in enumerate(lines):
        if GLASS.match(line.strip()):
            for head, body in heads(lines, at):
                text = lines[head].strip()
                if DECOR.match(text) or (OVERLAY.match(text) and any(STROKE.search(b) for b in body)):
                    found.add(head)
    return [f"{path}:{n + 1}:{lines[n]}" for n in sorted(found)]


print("\n".join(hit for path in sys.argv[1:] for hit in hits(path)))
PY

glass_alone() {
  local name="$1" allowed="$2"
  shift 2
  local hits
  hits=$(find "$@" -name '*.swift' -print0 | xargs -0 python3 -c "$glass_alone_py" | grep -vE "^($allowed):" || true)
  if [[ -n "$hits" ]]; then
    printf 'FAIL %s\n%s\n\n' "$name" "$hits"
    status=1
  else
    printf 'ok   %s\n' "$name"
  fi
}

glass_alone "design-system/liquid-glass-stays-on-the-navigation-layer: no fill, stroke, border or shadow on a glass view" \
  'Apps/Shared/Debug/[A-Za-z]+\.swift' \
  Apps

# A button is a system style or a plain surface, never an outline
# (design-system/controls-use-system-styles). The scan reads each Button's
# label closure for a stroke or border. The profile color swatches ring the
# picked color, which marks the choice rather than drawing the button.
read -r -d '' outlined_py <<'PY' || true
import re
import sys

BUTTON = re.compile(r"\bButton\b[^{]*\{\s*$|\blabel:\s*\{\s*$")
STROKE = re.compile(r"\.(stroke|strokeBorder|border)\(")


def hits(path):
    with open(path, encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    found = set()
    for at, line in enumerate(lines):
        if line.strip().startswith("//") or not BUTTON.search(line):
            continue
        depth = line.count("{") - line.count("}")
        i = at + 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count("{") - lines[i].count("}")
            if STROKE.search(lines[i]) and not lines[i].strip().startswith("//"):
                found.add(i)
            i += 1
    return [f"{path}:{n + 1}:{lines[n]}" for n in sorted(found)]


print("\n".join(hit for path in sys.argv[1:] for hit in hits(path)))
PY

outlined=$(find Apps -name '*.swift' -print0 | xargs -0 python3 -c "$outlined_py" |
  grep -vE '^(Apps/Shared/Components/Profiles/ProfileBadge\.swift|Apps/Shared/Views/Profiles/ProfileFlow\.swift):' || true)
if [[ -n "$outlined" ]]; then
  printf 'FAIL %s\n%s\n\n' "design-system/controls-use-system-styles: no stroke or border in a button's label" "$outlined"
  status=1
else
  printf 'ok   %s\n' "design-system/controls-use-system-styles: no stroke or border in a button's label"
fi

# A flat block of the ground color over art leaves an edge across the
# picture. Copy over art sits on HeroScrim, which spans the whole picture
# (design-system/the-scrim-blends-into-the-art).
check "design-system/the-scrim-blends-into-the-art: no flat scrim block over art" \
  'Palette\.(ground|scrimTint)\.opacity\([0-9.]+\)\.frame\((width|maxWidth):' \
  Apps/Shared

# On Apple TV the system hover effects lift a circle on a rounded square
# platter and cut it. A focusable circle lifts itself with
# circleLiftOnTelevision (profiles/who-s-watching-at-launch).
check "profiles/who-s-watching-at-launch: no system hover effect on a circle" \
  'contentShape\(\.hoverEffect, Circle\(\)\)' \
  Apps/Shared

# Copy kept in a String constant skips the String Catalog. Copy is a
# LocalizedStringResource (the swiftui-composition skill, rule 9).
check_except "localization: copy in views and components is not a plain String constant" \
  '(static let [A-Za-z]+ = "[A-Z][a-z]+( [A-Za-z]+)*|: String = "[A-Z][a-z]+( [A-Za-z]+)*)' \
  'Apps/Shared/(Views|Components)/[A-Za-z/]+Fixtures\.swift' \
  Apps/Shared/Views Apps/Shared/Components

# Xcode's string extraction skips a literal whose declared type is an
# optional resource, such as `let x: LocalizedStringResource? = n == 1 ?
# "1 favorite" : "\(n) favorites"`, so the catalog never gets the key and
# the sync check cannot see it. Build the resource in a function that
# returns it non-optional, and make the optional from that.
check "localization: no copy declared as an optional resource" \
  '(let|var)[[:space:]]+[A-Za-z_]+[[:space:]]*:[[:space:]]*(LocalizedStringResource|String\.LocalizationValue|LocalizedStringKey)\?[[:space:]]*=' \
  Apps Packages/AntennaCore/Sources

# Shown text is translated, so "LIVE" is "EN VIVO" in Spanish and a test
# against the English word fails. Code branches on a kind, never on copy.
check_except "localization: views never compare text with English copy" \
  '(==|!=)[[:space:]]*"[A-Z][A-Za-z -]+"|"[A-Z][A-Za-z -]+"[[:space:]]*(==|!=)' \
  'Apps/Shared/Views/Import/ImportModel\.swift' \
  Apps/Shared/Views Apps/Shared/Components Apps/Mobile Apps/TV

# On Apple TV the release of a held select reaches a button as a click, so a
# button with its own long press does both. HoldButton swallows that click
# (tvos-shell/one-press-does-one-thing).
check_except "tvos-shell/one-press-does-one-thing: a long press on a button only through HoldButton" \
  '(onLongPressGesture|LongPressGesture\()' \
  'Apps/Shared/Components/HoldButton\.swift' \
  Apps/Shared Apps/TV

# The shared session keeps replies in a URL cache on disk, keyed by the
# full address. Only posters and logos may use it; a request that can
# carry a login goes through `URLSession.provider` or another session
# with no cache (source-management/provider-replies-are-not-kept-on-disk).
check_except "source-management/provider-replies-are-not-kept-on-disk: the shared URL session only for posters and logos" \
  '(URLSession\.shared|URLSession[[:space:]]*=[[:space:]]*\.shared|session:[[:space:]]*\.shared)([^A-Za-z0-9_]|$)' \
  'Apps/Shared/Persistence/(PosterCache|LogoCache)\.swift' \
  Apps/Shared Apps/Mobile Apps/TV Apps/TopShelf Packages/AntennaCore/Sources Packages/AntennaDemux/Sources

check "localization: Core never compares translated words" \
  '(==|!=)[[:space:]]*[Ww]ords(\([a-z]+\))?\("|[Ww]ords(\([a-z]+\))?\("[^"]*"\)[[:space:]]*(==|!=)' \
  Packages/AntennaCore/Sources

# Core text takes the language, calendar and time zone as parameters. The
# device's own settings come in only as a default argument, or as a
# property that calls its locale-taking twin with `.autoupdatingCurrent`,
# so a test passes a fixed locale and reads the same on a Mac set to any
# language (scripts/test-core-in-language.sh runs the suite that way).
device_settings=$(grep -rnE --include='*.swift' \
  '(Locale|Calendar|TimeZone)\.(current|autoupdatingCurrent)|(^|[^A-Za-z0-9_)?!])\.(current|autoupdatingCurrent)([^A-Za-z0-9_]|$)' \
  Packages/AntennaCore/Sources |
  grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' |
  grep -vE '(Locale|Calendar|TimeZone)[[:space:]]*=[[:space:]]*\.(current|autoupdatingCurrent)([^A-Za-z0-9_]|$)' |
  grep -vE 'var [A-Za-z]+: [^{]+\{ [A-Za-z]+\(\.autoupdatingCurrent\) \}' || true)
if [[ -n "$device_settings" ]]; then
  printf 'FAIL %s\n%s\n\n' "localization: Core reads the device's language, calendar and time zone only as defaults" "$device_settings"
  status=1
else
  printf 'ok   %s\n' "localization: Core reads the device's language, calendar and time zone only as defaults"
fi

# Terraform configures no request log: no CloudFront standard or real-time
# logs, no S3 server access logs, no API Gateway access logs, no WAF logging
# or sampled requests (hosting/nothing-keeps-a-record-of-requests).
tf_logging=$(grep -rnE --include='*.tf' \
  '(^|[^A-Za-z0-9_])(logging_config|access_log_settings|aws_s3_bucket_logging|aws_cloudfront_realtime_log_config|aws_wafv2_web_acl_logging_configuration|realtime_log_config_arn)([^A-Za-z0-9_]|$)|sampled_requests_enabled[[:space:]]*=[[:space:]]*true' \
  Infra 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(#|//)' || true)
if [[ -n "$tf_logging" ]]; then
  printf 'FAIL %s\n%s\n\n' "hosting/nothing-keeps-a-record-of-requests: no request logging in Infra" "$tf_logging"
  status=1
else
  printf 'ok   %s\n' "hosting/nothing-keeps-a-record-of-requests: no request logging in Infra"
fi

tf_mx=$(grep -rnE --include='*.tf' 'type[[:space:]]*=[[:space:]]*"MX"' Infra 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(#|//)' || true)
if [[ -n "$tf_mx" ]]; then
  printf 'FAIL %s\n%s\n\n' "hosting/the-domain-receives-no-email: no MX record in Infra" "$tf_mx"
  status=1
else
  printf 'ok   %s\n' "hosting/the-domain-receives-no-email: no MX record in Infra"
fi

exit "$status"
