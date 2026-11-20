#!/usr/bin/env bash
# Runs the AntennaCore tests as if the Mac were set to another language,
# without touching the Mac's own settings: the test process reads its
# preferences from a throwaway home folder. A test that leans on the
# system language instead of passing a locale fails here.
#
#   scripts/test-core-in-language.sh de-DE de_DE    # German, the CI run
#   scripts/test-core-in-language.sh ar-SA ar_SA    # Arabic
set -euo pipefail
cd "$(dirname "$0")/.."

language=${1:-de-DE}
locale=${2:-de_DE}
home=$(mktemp -d)
trap 'rm -rf "${home:?}"' EXIT

mkdir -p "$home/Library/Preferences"
defaults write "$home/Library/Preferences/.GlobalPreferences" AppleLanguages -array "$language"
defaults write "$home/Library/Preferences/.GlobalPreferences" AppleLocale "$locale"

CFFIXED_USER_HOME="$home" swift test --build-system swiftbuild --package-path Packages/AntennaCore "${@:3}"
