# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Settings.dc.html`, `TV-Settings-Delete.dc.html`, `TV-Settings-Preferences.dc.html` (tvOS); `iPad-Settings.dc.html`, `iPad-Settings-Delete.dc.html` (iPadOS, macOS); `iPhone-Settings.dc.html`, `iPhone-Settings-Detail.dc.html`, `iPhone-Settings-Delete.dc.html` (iOS); `TV-Onboard-SignIn.dc.html` (reused for Sign in on this Apple TV).

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the details while Save runs; the error line under the form; a source row while loading; the Stalker row and the waiting-for-iCloud row; the signed-out iCloud footer; the "not loaded yet" status block and its failed variant; the M3U details form; the Preferences and About panes on iPad and Mac; the iPhone preference option screen; the Apple TV preference option list; the Sign in on this Apple TV form; iPhone edit mode with drag handles.

Decisions this builds on: adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only), adr-0009 (per-device state in UserDefaults).

## Goals / Non-Goals

**Goals:**
- One app-layer loader keeps every source loaded and the guide fed, and its per-source states drive the status lines.
- Source screens, the loading loop and preferences ship as one change because the status lines and actions are the loop's states and calls.

**Non-Goals:**
- Keeping channel lists between launches.
- A separate Refresh guide action, unless the implementation finds a reason for one.

## Decisions

- The previous revision of the old spec (`docs/specs/0023-sources-and-settings.md` at 0bce26a) holds the agreed texts: status lines, error sentences (from `add-first-run-onboarding`), the delete confirmation wording, the iCloud footer and the preference option lists. Use them.
- Source loading lives in an app-layer `SourceRefresher` that loads one source at a time in the user's order, tags each channel with its source, rebuilds the catalogue after each source, and calls the guide store in the order `guide-data` sets. `channel-catalogue` and `guide-data` wait on it, and several screens read its per-source states.
- Xtream loads call account info, then categories, then streams. An account failure stops the load.
- Load results are never written to the source record. This supersedes the `source-management` behaviour. The last successful load time per source lives in this device's `UserDefaults` (adr-0009). At launch every source loads whatever its age. The schedule applies only to sources already loaded in this process.
- Changes this device made are handled once. The store observer ignores a deletion it already handled and a link change whose load is already running. A save on a loading source cancels that load first.
- Deleting a source deletes its Keychain item and its favorite records and calls the guide store's remove once. A source removed by sync deletes the Keychain item on this device but never the favorites, which the deleting device already removed. Keychain errors log only the source id and the status code.
- Preferences record (pending decision, adr-0002 rules): every field defaulted, no uniqueness. On duplicates the newest is read and the rest deleted. Showing preferences inserts nothing.
- Large-source targets: a 50 000-channel M3U parses, tags and builds within 10 seconds in debug CI, off the main thread. A request is cancelled after 30 seconds.
- A channel that disappears from a reloaded source keeps playing until the user tunes elsewhere.
- No source link or host appears in a row, label or identifier. Log lines use the `redacted(_:)` helper from `guide-data` (adr-0003).

## Risks / Trade-offs

- Open question: synced preferences (assumed) or kept per device? The refresh interval and the Apple TV swipe setting are per device in nature. The answer changes where the preference values are stored, not what the user sees on this device.
- Open question: leaving edited details discards changes without asking. A "Discard changes?" prompt can be decided during implementation.
- Open question: the link field shows an M3U link in full, including any password in it, so VoiceOver reads it aloud. Masking it until edited can be decided during implementation.
- [One change covers screens, loader and preferences, so the work may be large] → split into several PRs before implementation if needed.
