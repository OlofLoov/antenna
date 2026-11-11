#!/usr/bin/env bash
# The checks that take a minute or two: rules, specs, formatting, lint and
# the AntennaCore tests. The pre-push hook runs this. The simulator suites
# run nightly in the UI tests workflow, or on a PR labelled ui-tests.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

fail=0
step() {
  local name=$1; shift
  printf '== %s\n' "$name"
  "$@" || { printf 'FAILED: %s\n' "$name" >&2; fail=1; }
}

# shellcheck disable=SC2329 # called through step
core_tests() {
  # On macOS before 26 the Xcode toolchain cannot load swift-testing for a
  # package, so the Command Line Tools frameworks are used instead.
  local fw=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  local major
  major=$(sw_vers -productVersion | cut -d. -f1)
  if (( major < 26 )) && [[ -d "$fw/Testing.framework" ]]; then
    DEVELOPER_DIR=/Library/Developer/CommandLineTools swift test --package-path Packages/AntennaCore \
      -Xswiftc -F"$fw" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
      -Xlinker -F"$fw" -Xlinker -rpath -Xlinker "$fw"
  else
    swift test --package-path Packages/AntennaCore
  fi
}

step "repo rules" bash scripts/check-rules.sh
step "spec references" bash scripts/check-spec-refs.sh
if command -v openspec >/dev/null; then
  step "openspec" openspec validate --all --strict --no-interactive
fi
step "swift-format" swift format lint --strict --recursive --parallel Apps Packages
if command -v swiftlint >/dev/null; then
  step "swiftlint" swiftlint lint --strict --quiet
fi
step "AntennaCore tests" core_tests

exit "$fail"
