#!/usr/bin/env bash
# One-time local setup. Safe to re-run.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath scripts/githooks
chmod +x scripts/*.sh scripts/githooks/* .claude/hooks/*.sh
echo "git hooks path -> scripts/githooks"
command -v xcodegen >/dev/null || echo "note: brew install xcodegen"
command -v gh >/dev/null || echo "note: brew install gh (needed by the pr skill)"
command -v swiftlint >/dev/null || echo "note: brew install swiftlint (CI runs it with --strict)"
[[ -f Config/Local.xcconfig ]] || echo "note: cp Config/Local.xcconfig.example Config/Local.xcconfig and set DEVELOPMENT_TEAM"
