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

On Apple TV the user opens Groups from Settings, after the passcode prompt if any group is locked and locks are closed. The list shows All channels, every provider group, the user's own groups and New group, with Rename, Hide, Lock, Move up and Move down beside the selected row. Locking the first group asks for four digits twice. On iPad and Mac, Sources & Settings then Groups shows a middle list and a right-hand editor; rows drag to reorder and Add channels opens a picker. On iPhone, Settings then Groups; tapping a row opens its settings and Edit shows drag handles.

## Goals / Non-Goals

**Goals:**
- With no rules, every catalogue query equals today's result.
- The policy build at most 1.5 times the catalogue build at 50 000 channels; picker filtering within 100 ms; the Groups screen's first frame within one second with 400 groups.

**Non-Goals:**
- Locking single channels, movie categories, Favorites, All channels or the whole app.

## Decisions

- Records (app layer, following the CloudKit rules: every property optional or defaulted, no unique attribute, relationships optional): a group record (kind, source id, provider name, custom name, hidden, locked, sort order, created at), a member record shaped like the favorite record, and a passcode record holding a salt and a check value (the verifier). Migration is additive. Malformed records are ignored and no record can hide or lock Favorites.
- Hiding is per profile (change `add-profiles`): a hidden-group record (profile id, group key, hidden) beside the group record, with a nil profile id meaning the first profile. Order, custom names, own groups, locks and the passcode stay shared by every profile.
- The passcode is never stored, synced or logged. The verifier is built in `Apps/Shared/Persistence` with CryptoKit because AntennaCore imports Foundation only. The decision on these records must say that four digits are only 10 000 values, so the verifier stops casual reading of the store and nothing more.
- The verifier syncs because tvOS Keychain items do not: a parent sets the passcode on the phone and the Apple TV is locked without anyone touching it. The open-locks state lives in memory per device; the search toggle and lockout state live in this device's `UserDefaults`.
- Group keys in identifiers never contain a stream URL.
- The catalogue's `Catalogue` gains a group policy and a locks-open flag, both defaulting so that with no rules every query equals today's result. Rules for sources that have not finished loading are neither applied nor orphans.
- Hiding never renumbers. A locked channel's number is hidden while locks are closed. All channels can be hidden but not locked.
- Duplicate rules, user groups and passcode records: the earliest `createdAt` wins; the rest show as orphans (rules) or are deleted (passcode records).
- Starting values: lockout after five wrong entries, 30 seconds doubling up to 5 minutes, per device; locks close after 15 minutes in the background or 15 minutes without remote input on Apple TV.
- The reset asks only for the device's own passcode or login, so a child who knows the family iPad's passcode can reset the lock. The owner can ask for a stronger check.
- Test layers: hide, lock, order and own-group rules run as core tests on the catalogue; rename, passcode, lockout, auto-close and locked-while-playing as integration tests; unlock and reset as UI tests; cross-device sync on two devices.

## Risks / Trade-offs

- [A synced passcode check value can be brute-forced from the store] → four digits stop casual reading only; the decision says so.
- [M3U channel ids carry the stream link] → own groups cannot save M3U channels until the `m3u-playlists` follow-up ships.
- Open question: should the passcode check value sync through iCloud (chosen here), or should each device keep its own passcode? The decision this change waits on settles it; a passcode per device changes the passcode and sync requirements.

## Implementation decisions

- The synced records are settled here, which lifts the block named in the proposal. `GroupRecord` (one per group: kind, source id, provider name, custom name, locked, sort order, created at; an own group uses its id as the record id), `GroupMemberRecord` (group id, channel id, source id, sort order, added at) and `HiddenGroupRecord` (profile id, group key, hidden, created at). All fields are optional or defaulted and nothing is unique, so adding them to the schema is an additive migration. Options considered: one record holding every rule as JSON (one write conflicts with every other, and a bad blob loses everything), or per-profile copies of every rule (order and names would drift between profiles). One record per group won.
- The passcode check value syncs in a SwiftData record. The other option, a synchronizable Keychain item, does not reach Apple TV, so a passcode set on a phone would never lock the TV. Four digits are 10 000 values, so anyone who can read the store can recover them; the salted verifier only stops someone reading the digits off the record.
- A group key is `all`, `named.<source>.<provider name>`, `ungrouped.<source>` or `own.<id>`. It is what `HiddenGroupRecord` stores and what accessibility identifiers use. It never holds a channel id, so never a stream link.
- Locked groups leave `Catalogue.groups` while locks are closed, as the `channel-catalogue` delta says, and `Catalogue.lockedGroups` lists them for the screens that show a lock row. The `group-management` spec asks for a lock on the group, the catalogue delta for the group to be absent; the two lists keep both true.
- Hiding a provider group takes its channels out of All channels and out of the number match, as well as out of the group list. Its favorites stay in Favorites and Recents. Hiding an own group hides only the group, since its channels belong to their provider groups.
- Locking an own group locks its channels everywhere while locks are closed, as locking a provider group does.
- A channel is "in" an own group when its source and id match a loaded channel; the earliest such channel in All channels order wins, as favorites resolve. Own groups list even when empty.
- Own groups refuse channels whose id holds `://`, which is every M3U channel today, until the `m3u-playlists` follow-up takes the link out of M3U ids. The rule is on the id, not the source kind, so it lifts by itself when that ships.
- Duplicate `GroupRecord`s for one group: the earliest `createdAt` wins and the others are listed with the groups that are gone, each with Remove.
- Rules for a source with no loaded channels (loading, failed, waiting for its login, or loaded empty) are neither applied nor listed as gone.
- Deleting a playlist deletes its group records, hidden flags and own-group members. Deleting a profile deletes its hidden flags.
- The fallback when the group on screen disappears is the first group listed after Favorites and Recents, so All channels unless hidden, else Favorites.
- Searching hidden groups is a per-device `UserDefaults` flag, `groups.searchHidden`.
- The passcode check value is an HMAC-SHA256 of the digits keyed by a random 16-byte salt, in `PasscodeRecord` (salt, verifier, created at, changed at). Changing the passcode rewrites the record in effect with a new salt. Duplicates keep the earliest `createdAt` and the rest are deleted.
- "Changed on another device" compares the record in effect with the record id and change time this device last set or entered, kept in `UserDefaults` under `groups.passcodeKnown`. The wait after wrong entries is `groups.lockout`. Neither holds the digits.
- Open locks live in memory in `GroupLocks`, so a relaunch starts with them closed. Apple TV counts a focus move in the shell as remote input for the 15-minute idle close; screens over the shell, such as Settings, do not reset it.
- The Groups screen is a system List on every platform, with each group's settings on a pushed detail screen (Name, Hidden, Locked, Move up, Move down, and for an own group its channels, Add channels and Delete group). It does not reproduce the boards' right-hand editor on iPad and Mac or the side panel on Apple TV; those layouts are a follow-up. Rows drag to reorder on iPhone, iPad and Mac; Move up and Move down work everywhere.
- The passcode prompt draws its own keypad on every platform, where `iPhone-Groups-Locked` shows the system numeric keyboard. One component covers every platform and UI tests type the same keys.
- Forgot passcode asks LocalAuthentication for `.deviceOwnerAuthentication`, which accepts the device passcode, the Mac login password, Face ID or Touch ID. UI tests skip it with `-ui-testing-groups-owner`.
- The 400-group budget is checked on the screen's data build (`GroupStoreTests`, under 500 ms for 400 groups and 20 000 channels). The first frame itself is not timed.
- Locked groups follow the open groups in the iPad and Mac sidebar, the iPhone and Guide chips and the Apple TV overlay, each with a lock and no count. Picking one shows the passcode prompt; the right passcode opens the locks and selects the group once the catalogue lists it, while the channel playing keeps playing. The Guide lists the same groups, so it never opens on a locked one.
- A channel that becomes locked while it plays is paused under the passcode prompt, on every platform. Closing the prompt plays the first channel of the fallback group, else the first of All channels, else stops the player (iPhone, iPad, Mac) or the engine (Apple TV). A locked channel restored at launch goes through the same check once it starts. The lock screen and Control Center reach the player through the same engine, so their play requests meet the same prompt.
- The prompt for a locked group and the prompt over a locked channel share one sheet (iPhone, iPad, Mac) or full-screen cover (Apple TV) per screen. A second cover on the Apple TV shell made the zap bar hide early after a failed stream in the UI tests.
