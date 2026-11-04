# Specs

One file per feature. Numbered, four digits. Status lifecycle:
Draft → Accepted → In progress → Implemented → Superseded.

A spec is Accepted when the `spec-reviewer` agent has passed it and every
acceptance criterion is testable. It is Implemented when a PR has merged with
a test per criterion. The implementing PR sets that status itself, in the
spec header and in this table, so merging the code and updating the index
are one change. In progress is for a spec shipping as a stack of PRs; every
PR but the last uses it.

`scripts/check-specs.sh` runs in CI and in the `pr` skill. It fails when the
header and the row disagree, or when a spec marked Implemented has a
criterion with no Swift test citing `NNNN/AC-n`. Criteria whose test-plan
layer is `device` are exempt. The `implement` skill runs this loop.

| Spec | Title | Status |
|------|-------|--------|
| [0001](0001-m3u-playlist-parsing.md) | M3U playlist parsing | Accepted (retroactive) |
| [0002](0002-xmltv-guide-parsing.md) | XMLTV guide parsing | Draft (retroactive) |
| [0003](0003-xtream-codes-live-source.md) | Xtream Codes live source | Accepted (retroactive) |
| [0004](0004-source-management-with-icloud-sync.md) | Source management with iCloud sync | Draft (retroactive) |
| [0005](0005-favorites.md) | Favorites | Accepted (retroactive) |
| [0006](0006-first-run-onboarding.md) | First-run onboarding and add-source flow | Draft |
| [0007](0007-tv-channel-overlay.md) | Apple TV channel overlay | Draft |
| [0008](0008-tv-zap-bar-and-number-entry.md) | Apple TV zap bar and channel number entry | Draft |
| [0009](0009-tv-guide-grid.md) | Apple TV guide grid | Draft |
| [0010](0010-live-tv-on-iphone-ipad-mac.md) | Live TV browsing on iPhone, iPad and Mac | Draft |
| [0011](0011-movies-and-series-browsing.md) | Movies and series browsing | Draft |
| [0012](0012-search.md) | Search across channels, guide, movies and series | Draft |
| [0013](0013-channel-catalogue.md) | Channel catalogue: groups, numbers, initials, favorites | Accepted |
| [0014](0014-guide-data.md) | Guide data: download, join and query | Accepted |
| [0015](0015-tvos-shell.md) | tvOS shell: tab bar, full-screen playback and Menu | Draft |
| [0016](0016-xtream-vod-and-series-client.md) | Xtream VOD and series client | Accepted |

Template: [0000-template.md](0000-template.md). Create new ones with the `spec` skill.
