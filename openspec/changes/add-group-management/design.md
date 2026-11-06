# Design

## Context

See proposal.md for why. Group rules apply in `channel-catalogue`, so every screen that lists groups follows them without its own logic.

Boards, under `openspec/specs/design-system/boards/`:
- tvOS: `TV-Groups.dc.html`, `TV-Groups-Locked.dc.html`, `TV-Groups-Empty.dc.html`, `TV-Groups-Members.dc.html`.
- iPadOS and macOS: `iPad-Groups.dc.html`, `iPad-Groups-Locked.dc.html`, `iPad-Groups-Empty.dc.html`.
- iOS: `iPhone-Groups.dc.html`, `iPhone-Groups-Locked.dc.html`, `iPhone-Groups-Empty.dc.html`, `iPhone-Groups-Detail.dc.html`.
- `TV-Onboard-3.dc.html` for the tvOS text field reused for Rename.

Not drawn: the passcode prompt while the passcode has not synced yet; the lockout countdown; setting and changing the passcode; the passcode prompt over the player; the "passcode was changed on another device" line; the reset-unavailable line; the Passcode section (Change passcode, Lock now, search hidden groups) on iPad and iPhone; a provider group's detail on iPad and iPhone; the macOS channel picker; the Apple TV member actions panel; an empty own group; a locked group focused in the Apple TV overlay; the Groups screen while every playlist waits for its login.

Design-system requirements that apply: “Live video keeps playing under overlays”, “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Channel rows share one anatomy”, “Channels without a logo show initials”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”.

Decisions this builds on: adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free), adr-0006 (no free tier, paid unlock only), adr-0009 (keep per-device state in UserDefaults).

On Apple TV the user opens Groups from Settings, after the passcode prompt if any group is locked and locks are closed. The list shows All channels, every provider group, the user's own groups and New group, with Rename, Hide, Lock, Move up and Move down beside the selected row. Locking the first group asks for four digits twice. On iPad and Mac, Sources & Settings then Groups shows a middle list and a right-hand editor; rows drag to reorder and Add channels opens a picker. On iPhone, Settings then Groups; tapping a row opens its settings and Edit shows drag handles.

## Goals / Non-Goals

**Goals:**
- With no rules, every catalogue query equals today's result.
- The policy build at most 1.5 times the catalogue build at 50 000 channels; picker filtering within 100 ms; the Groups screen's first frame within one second with 400 groups.

**Non-Goals:**
- Locking single channels, movie categories, Favorites, All channels or the whole app.

## Decisions

- Records (app layer, adr-0002 rules): a group record (kind, source id, provider name, custom name, hidden, locked, sort order, created at), a member record shaped like the favorite record, and a passcode record holding a salt and a check value (the verifier). Migration is additive. Malformed records are ignored and no record can hide or lock Favorites.
- The passcode is never stored, synced or logged. The verifier is built in `Apps/Shared/Persistence` with CryptoKit because AntennaCore stays on Foundation (adr-0005). The decision record must say that four digits are only 10 000 values, so the verifier stops casual reading of the store and nothing more.
- The verifier syncs because tvOS Keychain items do not: a parent sets the passcode on the phone and the Apple TV is locked without anyone touching it. The open-locks state lives in memory per device; the search toggle and lockout state live in this device's `UserDefaults`.
- Group keys in identifiers never contain a stream URL (adr-0003).
- The catalogue's `Catalogue` gains a group policy and a locks-open flag, both defaulting so that with no rules every query equals today's result. Rules for sources that have not finished loading are neither applied nor orphans.
- Hiding never renumbers. A locked channel's number is hidden while locks are closed. All channels can be hidden but not locked.
- Duplicate rules, user groups and passcode records: the earliest `createdAt` wins; the rest show as orphans (rules) or are deleted (passcode records).
- Starting values: lockout after five wrong entries, 30 seconds doubling up to 5 minutes, per device; locks close after 15 minutes in the background or 15 minutes without remote input on Apple TV.
- The reset asks only for the device's own passcode or login, so a child who knows the family iPad's passcode can reset the lock. The owner can ask for a stronger check.
- Test layers: hide, lock, order and own-group rules run as core tests on the catalogue; rename, passcode, lockout, auto-close and locked-while-playing as integration tests; unlock and reset as UI tests; cross-device sync on two devices.

## Risks / Trade-offs

- [A synced passcode check value can be brute-forced from the store] → four digits stop casual reading only; the decision record says so.
- [M3U channel ids carry the stream link] → own groups cannot save M3U channels until the `m3u-playlists` follow-up ships.
- Open question: should the passcode check value sync through iCloud (chosen here), or should each device keep its own passcode? The decision record this change waits on settles it; a passcode per device changes the passcode and sync requirements.
