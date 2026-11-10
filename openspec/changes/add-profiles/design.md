# Design

## Context

See proposal.md for why. Today one implicit person owns everything: favorites are synced `FavoriteRecord`s with no owner, and the last channel (`shell.lastChannel`) and language picks (`player.languages`) sit in `UserDefaults` with one value each. Hidden groups, watch progress, My list, recent searches and recently watched are planned in other changes and not built yet.

Boards, under `openspec/specs/design-system/boards/`: `TV-Profiles.dc.html` (Who's watching), `TV-Profiles-Manage.dc.html`, `TV-Profiles-Edit.dc.html`, `TV-Shell-Menu-Profile.dc.html` (the tab bar with the profile button), `iPhone-Profiles.dc.html`, `iPhone-Profiles-Edit.dc.html`.

Not drawn yet: the iPad and Mac pickers, which are the iPhone layout centered in the window; the Profiles row in Settings on every device (a row above Sources with the current profile's color dot and name, or "Add a profile" with one profile, opening Manage profiles); the delete confirmation, which is the system alert with the copy below; the eight-profile line on Manage profiles.

Design-system requirements that apply: "Focus is the lifted white card", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums". Deviation: the eight profile colors are identity colors, not a second accent, and extend "One accent color".

## Goals / Non-Goals

**Goals:**
- No change at all for someone with one profile: no screen, button or name.
- Everything per person lives in records or keys that carry the profile, so the planned changes that add per-person data only add a field.

**Non-Goals:**
- Locking a profile or limiting what it shows.
- Per-profile app settings.

## Decisions

### In-app profiles, not Apple TV system users

| Option | Why not, or why |
|---|---|
| Apple TV system users (change `add-tvos-profiles`) | Every person adds the sources and types the logins again, nothing happens on iPhone, iPad or Mac, and the Top Shelf storage question stays open. Withdrawn. |
| Profiles kept on each device, not synced | A family's favorites would differ between the Apple TV and the phones, against `favorites` syncing today. |
| **Profiles in Antenna, synced, sharing the sources** | Chosen. One record type and a profile id on the per-person records. |

### Records

- `ProfileRecord` in `Apps/Shared/Persistence`, following the CloudKit rules (every property optional or defaulted, no unique attribute, no relationships): `id: UUID = UUID()`, `name: String = ""`, `colorIndex: Int = 0`, `sortOrder: Int = 0`, `createdAt: Date = .now`. Additive migration.
- `FavoriteRecord` gains `profileID: UUID?`. Additive.
- The first profile is "Main" with the fixed id `Profile.mainID` (`00000000-0000-0000-0000-00000000A1A1`). A per-person record whose profile id is nil belongs to Main, so nothing stored before this change moves. Writes for Main store nil.
- Main has no `ProfileRecord` until a second profile is added; then the device inserts Main's record (name "Main", color 0, sort order 0) with the fixed id, followed by the new profile. Two devices doing this before they sync make two records with Main's id; reads keep the earliest `createdAt` and the next write deletes the others. Duplicate profile ids otherwise resolve the same way.
- Deleting a profile deletes its `ProfileRecord` and every per-person record with its id in the same save. Deleting Main deletes the nil-profile records; Main's id then belongs to no one, and the next profile in order becomes the first. The last profile cannot be deleted.

### The other changes' records

- `add-group-management`: hiding a group is per profile, in its own record (profile id, group key, hidden), not a field on the household's group record. Order, names, own groups and locks stay household-wide. Its design.md says so.
- `add-watch-progress-sync`: progress, list entry and recent search records gain `profileID: UUID?` with the same nil-is-Main rule. Its design.md says so.
- `add-session-restore-and-recently-watched`: `recents.*` keys are per profile as below.

### Per-device values

- `profiles.current` in `UserDefaults.standard`: the current profile's id. Missing, unreadable or naming a deleted profile means none: with two or more profiles the picker shows, with one Main is current.
- `shell.lastChannel`, `recents.list`, `recents.session` and `player.languages` keep their keys and payloads for Main. Other profiles use the same key with `.<profile id>` appended. When a profile disappears, its keys on this device are removed at the next launch.

### Core and app

- AntennaCore gets `Profile` (id, name, color index, order) and `ProfileList`: ordering, duplicate resolution, the name rule (trimmed, 1 to 30 characters), the eight-profile cap, adding the second profile with Main, which profile is current, and whether the picker shows. Pure and tested with swift-testing.
- The app maps records to `ProfileList` in one `ProfileStore` on the main context and provides the current profile through an `@Entry` environment value. Screens that read per-person data filter by it; the catalogue's favorites come from the current profile's records.
- Apple TV: `ShellView` shows `ProfilePickerView` before the shell starts, so no channel is tuned before someone is chosen. iPhone, iPad and Mac: `RootView` does the same before the tabs.
- Switching calls the engine's `stop()`, sets `profiles.current`, rebuilds the catalogue and, on Apple TV, launches the shell again for the new profile.

### Copy

- Picker title "Who's watching?", button "Manage profiles"; on Manage, "Add profile" and "Done".
- Edit: field label "Name", the eight colors, "Save", "Delete profile".
- Delete alert: "Delete <name>?" and "Its favorites, hidden groups and history go too. Sources stay." with "Delete" and "Cancel".
- Eight-profile line: "You can have up to eight profiles."
- Settings row "Profiles", value the current profile's name, or "Add a profile" while there is one profile.

### Colors

Eight identity colors in order: `#5BB8FF`, `#FFB454`, `#4FD1C5`, `#C084FC`, `#F87171`, `#A3E635`, `#F472B6`, `#94A3B8`. The initial is the name's first letter or digit, uppercased, in `#0B0E13` on the color.

### Identifiers

`profiles.picker`, `profiles.tile.<index>`, `profiles.manage`, `profiles.add`, `profiles.done`, `profiles.edit.name`, `profiles.edit.color.<index>`, `profiles.edit.save`, `profiles.edit.delete`, `profiles.limit`, `shell.profile` (the tab bar button), `settings.profile`.

## Risks / Trade-offs

- [Profiles arrive late on a new device] → it opens as with one profile and shows the picker on the next launch; the spec says so.
- [A device removes a deleted profile's records while offline edits are pending elsewhere] → CloudKit applies the delete; favorites added offline to a deleted profile end up with no owner and are dropped by reads, then deleted on the next save.
- [Fixed id for Main] → the id is a constant, never derived from a user or device, so it carries nothing personal.
- [Every per-person query gains a filter] → covered by tests per screen; the filter lives in one place in `ProfileStore`.

## Open Questions

- Should switching profile on iPhone keep the open tab, or go back to Live? Can be decided during implementation; the spec only asks that the new profile's data shows.
