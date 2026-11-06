# Design

## Context

See proposal.md for why. Live reads groups, numbers and favorite rows from `channel-catalogue`, programmes from `guide-data`, and saves favorites through `favorites`.

Boards, under `openspec/specs/design-system/boards/`: `iPad.dc.html`, `iPhone.dc.html`, `iPad-Loading.dc.html`, `iPhone-Loading.dc.html`, `iPad-NothingSelected.dc.html`, `iPad-Error.dc.html`, `iPhone-Error.dc.html`, `iPad-Banner.dc.html`, `iPhone-Banner.dc.html`, `iPad-Empty.dc.html`, `iPhone-EmptyFavorites.dc.html`, `iPad-Collapsed.dc.html`, `iPad-Collapsed-Narrow.dc.html`, `iPhone-FullScreen.dc.html`, `iPad-Focus.dc.html`.

Not drawn: "Loading guide…" and "No programme information" in the details, the now-playing line and the row; the filled star; the grayed-out Picture in Picture button.

Design-system requirements that apply: “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channel rows share one anatomy”, “A current programme always shows its progress”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”, “Nothing shows before the paywall”, “Loading shows real progress per step”.

On iPad and Mac, Live is selected in the sidebar with Favorites, All channels and each group with its count below it. The middle column lists the group's channels, and the filter narrows them as the user types. Picking a channel plays it on the right with the programme, times, description, star and what is next underneath. Controls appear on a tap or when the pointer is over the picture.

On iPhone, the Live tab shows the picture at the top, a line with the programme and a star, group chips and the channels. Tapping a channel plays it in place. The full-screen button, or turning the phone sideways, fills the screen.

## Goals / Non-Goals

**Goals:**
- With 20 000 channels the first rows show within one second on an iPhone 15, a five-second flick drops no frames, and filtering takes under 50 ms in a debug `swift test`.

**Non-Goals:**
- Swipe actions and context menus on iPhone rows. A later change can add them.
- A separate player window on Mac.
- Matching the filter against programme titles or group names.
- Switching channel by resting on a row with the arrow keys. Only Return switches.

## Decisions

- Column breakpoints: three columns from 904 pt (sidebar 232, list 352, player never under 320). The sidebar folds below 904, the list below 672.
- Board deviations: “Channel rows share one anatomy”, the number trails the name on touch and pointer platforms; “A current programme always shows its progress”, the iPhone now-playing line has no bar; “Targets are large enough to hit”, controls drawn 30 to 40 pt get a 44 by 44 pt hit area; “Text stays above the platform caption floor”, the LIVE badge and tile initials sit one point under the floor. Mac leaves out the PiP control drawn on the iPad boards.
- Controls hide three seconds after the last touch and one second after the pointer leaves.
- Offline wording applies when every failure is `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`, as in onboarding. A source without a credential counts as neither loaded nor failed. A credential that arrives is picked up within 5 s or at the next scene activation.
- Tests use a fake engine that records loaded URLs to a file in the test's temp directory. Nothing derived from a stream URL goes on an accessibility attribute.
- Accessibility identifiers use the prefix `browse.`. The filter has no debounce and does not match group names.
- The Favorites tab on iOS, iPadOS and macOS is removed. The `favorites` delta removes its tab requirements; storage and sync stay as they are.
- With no source at all, onboarding from change `add-first-run-onboarding` shows instead of Live.

## Risks / Trade-offs

- [Live depends on an in-place player that does not exist yet] → tests use a stand-in engine until change `add-playback-engine` ships.
- [Removing the Favorites tab changes where users find favorites] → the Favorites group sits first in the sidebar and chips, as the catalogue orders it.
