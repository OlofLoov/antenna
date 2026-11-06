# Design

## Context

See proposal.md for why. Onboarding replaces the empty Channels tab from `source-management` when there are no sources.

Boards, under `openspec/specs/design-system/boards/`:
- tvOS: `TV-Onboard-1.dc.html`, `TV-Onboard-2.dc.html`, `TV-Onboard-3.dc.html`, `TV-Onboard-3-M3U.dc.html`, `TV-Onboard-3-Connecting.dc.html`, `TV-Onboard-SignIn.dc.html`, `TV-Onboard-Help.dc.html`, `TV-Onboard-4.dc.html`, `TV-Onboard-4-NoLive.dc.html`, `TV-Onboard-4-Empty.dc.html`, `TV-Onboard-5.dc.html`, `TV-Onboard-5-Two.dc.html`.
- iOS: `iPhone-Onboard-1.dc.html`, `iPhone-Onboard-Help.dc.html`, `iPhone-Onboard-2.dc.html`, `iPhone-Onboard-2-M3U.dc.html`, `iPhone-Onboard-2-Connecting.dc.html`, `iPhone-Onboard-2-NoLink.dc.html`, `iPhone-Onboard-3.dc.html`, `iPhone-Onboard-3-NoLive.dc.html`, `iPhone-Onboard-3-Empty.dc.html`, `iPhone-Onboard-3-Two.dc.html`. iPad and Mac show the same sheet centered.

Not drawn: the guide line done and failed, the movies line after it stops waiting for counts, account lines without an expiry date or screen count, and the tvOS "Reading the guide…" line.

Design-system requirements that apply: “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Nothing shows before the paywall”, “Loading shows real progress per step”.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only).

On Apple TV the user sees the welcome screen, picks M3U or Xtream and fills in the details, chooses Connect, and watches the checklist fill in. Start watching becomes available once channels are in. The last screen sums up what was added while the first channel plays behind it, with Start watching and Add another source.

On iPhone, iPad and Mac the user sees a welcome sheet, then one sheet with the provider type, the fields and the clipboard banner. Connect moves to the checklist sheet, and Start watching opens Live with the first channel playing.

## Goals / Non-Goals

**Goals:**
- One fetch at Connect feeds both the check and the checklist.
- Validation and save go through the same code path as adding a source in Settings.

**Non-Goals:**
- The purchase flow, Stalker portals, file import, editing or deleting providers, per-provider guide toggles, several guides per playlist and background refresh. See proposal.md.

## Decisions

- Error messages, checklist wording and summary tile rules are those in docs/specs/0006 as accepted at c758aa4. Fixed captions on the boards are copy to match.
- Connect fetches once and the checklist reuses that response.
- An absent or empty Xtream `user_info.status` counts as active. A rejected login is the Xtream client's unauthorized error.
- The movies line stops waiting 20 seconds after login and reads "Movies and series available" without counts.
- The first channel is the lowest-numbered channel of the first source group in `channel-catalogue` order, skipping Favorites and All channels. The tvOS summary and Start watching use the same channel.
- Clipboard detection uses pattern detection for a probable web URL, which does not read the pasteboard. macOS shows no banner.
- tvOS sign-in writes under the record's `credentialKey` (its id when nil), skips Stalker records, names the sources still to sign in, and Menu on it suspends the app. Passwords never go in SwiftData or logs (adr-0003).
- Apple TV keeps passwords in its own Keychain and the sign-in screen is the way in, until the adr-0003 amendment chooses otherwise.
- Back from Add another source returns to the summary.
- Design deviations: “One accent color” accent on done markers, the clipboard banner and the tvOS ready eyebrow; “Targets are large enough to hit” show-password control with a 44 pt hit area; “Nothing fake and nothing bundled” the tvOS keyboard card describes the continuity keyboard generically.

## Risks / Trade-offs

- [adr-0003 assumes synced passwords, and Apple TV has no iCloud Keychain] → the Apple TV sign-in requirement covers it until the amendment lands. The change is blocked on that amendment.
- Open question: should Fill in understand provider messages that contain more than a single link? Can be decided during implementation.
