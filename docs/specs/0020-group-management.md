# 0020. Group management: hide, lock, rename, reorder and user groups

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- ADR needed: three new records in the synced container (`GroupRecord`, `GroupMemberRecord`, `ParentalRecord` holding a salted passcode verifier, never the passcode), and whether that verifier counts as a secret under ADR-0003. The ADR must state that a four-digit space has 10 000 values, so the verifier protects against casual reading of the store and not against anyone who can run a loop over a CloudKit dump. The criteria assume the records are accepted as written in the Interface section. This spec cannot move to Accepted until that ADR is Accepted and amends ADR-0003 for the verifier, or the criteria that name `ParentalRecord` are rewritten against what it decides.
- Acceptance order: 0013 first, then this spec. The fixtures cited as 0013/AC-2, AC-6a and AC-8 are on the 0013 branch until it merges.
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0013 (catalogue: `CatalogueGroup` kinds, `groupOrder`, numbers, order within a group, favorites resolution), 0005 (`FavoriteRecord` as the pattern for member records), 0007, 0009, 0010, 0012, 0008 and 0015 (the screens that show groups and tune channels). 0013 lists everything here as out of scope; this spec fills that gap and asks 0013 for an extended initialiser (Required of other specs).
- Amends, on acceptance: 0013/AC-2 (holds for `policy: .none`; `groups` otherwise follows 0020/AC-9), 0008/AC-15b (the All channels fallback becomes 0020/AC-10), 0015/AC-2a (a stored channel that is locked while locks are closed falls to AC-2b), 0007/AC-3 and 0010/AC-3 (list `groups` with the lock glyph), 0012/AC-2 (group match uses the display name). Each gains the note in its header and README row when this spec is accepted.
- Blocked, like 0013, on the 0001 follow-up that hashes `streamURL` out of `Channel.id`. No screen may insert a `GroupMemberRecord` until it is merged, because `channelID` would otherwise carry credentials for M3U sources (ADR-0003). The core layer can be implemented and tested before it.

## Design

Boards: `docs/design/boards/TV-Groups.dc.html` (tvOS), `docs/design/boards/iPad-Groups.dc.html` (iPadOS, macOS), `docs/design/boards/iPhone-Groups.dc.html` (iOS). State boards beside them: `TV-Groups-Locked.dc.html`, `TV-Groups-Empty.dc.html`, `TV-Groups-Members.dc.html`, `iPad-Groups-Locked.dc.html`, `iPad-Groups-Empty.dc.html`, `iPhone-Groups-Locked.dc.html`, `iPhone-Groups-Empty.dc.html`, `iPhone-Groups-Detail.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-8, DR-11, DR-12, DR-13. Deviations: DR-6, the member rows in a user group and in the channel picker are the compact variant of 0012 (logo, name, number, source name, no programme title and no progress bar) because the screen edits membership and shows no guide data; DR-3, the "Forgot passcode?" control on iOS, iPadOS and macOS is a link and uses the accent; DR-4, the HIDDEN, LOCKED and CUSTOM badges are letter-spaced label text 2 to 4 pt under the caption floor, as the badges of 0012; DR-5, the tvOS passcode keys are 72 by 56 pt because eleven keys must fit one row; DR-1, AC-25a pauses playback because a channel that has just been locked must not be heard.
States on the boards:
- `TV-Groups`: the Groups screen reached from the Settings sheet (0015/AC-12). Back link to Settings, title and subtitle, the group list with All channels first (no move handle), source groups with their count at the trailing edge, a LOCKED badge with the lock glyph on Movies, a HIDDEN badge with muted text on Adult, a CUSTOM badge on the user group Weekend sports, the New group row, and under "Not in any source" an orphan rule with its Remove control (AC-27). Focus is on the Sport row as the white card (`groups.row.<groupKey>`); the panel on the right shows the focused group's name, count and source, and the actions Rename, Hide, Lock, Move up, Move down (`groups.rename`, `groups.hide`, `groups.lock`, `groups.moveUp`, `groups.moveDown`) at 64 pt on the 0.12 surface, then the Passcode row, Lock now (`groups.lockNow`) and the "Include hidden channels in search" row with a check glyph (`groups.searchHidden`).
- `TV-Groups-Locked`: the passcode prompt (`groups.passcode`) over the dimmed screen: lock glyph, "Enter passcode" at 38 pt, the locked group's name in a muted 24 pt line, four 72 by 88 pt digit boxes (`groups.passcode.digit.<n>`, two filled), the digit row 0 to 9 and delete at 56 pt (`groups.passcode.key.<d>`, 5 focused as the white card), the error line "Wrong passcode" in `#FF5F57` at 22 pt (`groups.passcode.error`), and the muted 20 pt line "Forgot it? Reset the passcode in Antenna on your iPhone, iPad or Mac." (`groups.passcode.forgot`, not focusable on tvOS).
- `TV-Groups-Empty`: `groups.empty` reading "No groups yet. Add a source in Settings and its groups appear here." at muted 29 pt centred, no list, no panel, focus on the Back link as the white card.
- `TV-Groups-Members`: the channel picker for a user group (`groups.picker`): title with the group's name, filter field at 84 pt (`groups.picker.filter`), picker rows at 72 pt with a check glyph, number, logo tile, name and the source name in muted 22 pt (`groups.picker.row.<rowKey>`; the focused row is the white card), and on the right "In this group" with the member rows (`groups.member.<rowKey>`) and the Done button (`groups.picker.done`).
- `iPad-Groups`: three columns. Sidebar with Sources & Settings selected and a Settings list under it (the other entries are illustrative; the Sources and Settings spec owns them); the Groups column (352 pt) with the header "Groups" and the count, rows at 44 pt with the move handle, name, badges and count, the selected user group Weekend sports on the 0.12 surface, the New group row (`groups.new`); the detail column with the group name field (`groups.name`), the Hidden and Locked rows with a check glyph when on, the "Channels · 6" member list with handles (`groups.members`), the Add channels row (`groups.addChannels`) and Delete group (`groups.delete`) in `#FF5F57`.
- `iPad-Groups-Locked`: the same columns dimmed behind a centred 390 pt sheet: "Enter passcode" at 22 pt, the group name at muted 15 pt, four 56 by 64 pt boxes, "Forgot passcode?" as an accent link at 15 pt (`groups.passcode.forgot`). The system numeric keyboard is not drawn.
- `iPad-Groups-Empty`: the Groups column shows `groups.empty` at muted 15 pt centred and the detail column shows nothing.
- `iPhone-Groups`: Settings tab, navigation bar with Back to Settings and the title "Groups", rows at 52 pt with name, badges, count and a disclosure chevron, the New group row, the tab bar with Settings selected.
- `iPhone-Groups-Locked`: the passcode prompt as a sheet with the same parts as the iPad sheet at iPhone type sizes (22, 15, 15).
- `iPhone-Groups-Empty`: `groups.empty` at muted 15 pt centred under the navigation bar.
- `iPhone-Groups-Detail`: the pushed detail for a user group: name field, Hidden and Locked rows, members with handles in edit mode, Add channels, Delete group.
Not drawn: the passcode prompt while the verifier has not synced (AC-22), which is the prompt with the boxes and keys replaced by `groups.passcode.waiting` reading "Waiting for the passcode to sync from iCloud." at the muted body size of the platform, with `groups.passcode.forgot` under it on iOS, iPadOS and macOS; the lockout countdown (AC-21b), which replaces the error line with "Try again in <n> s" in the same style; the set-passcode flow (AC-18, AC-42), which is the prompt with the title "Set a passcode" and then "Enter it again"; the Rename field on tvOS, which is the onboarding text field of `TV-Onboard-3.dc.html` at 76 pt; the macOS picker, which is the iPad picker in a sheet; on iPad and iPhone a "Passcode" section under the list with `groups.setPasscode`, `groups.lockNow` and `groups.searchHidden` as 44 pt rows in the grouped-list style of `iPhone-Groups.dc.html`; the source-group detail on iPad and iPhone, which is the user-group detail without the members list and Delete group (`groups.detail` with `groups.name`, `groups.hide`, `groups.lock`); `groups.passcode` over the player on each platform (AC-25a), the same prompt over the dimmed player; `groups.members.empty` reading "No channels yet" at the muted body size (AC-32); the tvOS member panel with `groups.member.moveUp`, `groups.member.moveDown` and `groups.member.remove` at 64 pt in the style of the `TV-Groups` panel (AC-34); the overlay column for a focused locked group (AC-20a), which is 0007's `overlay.emptyGroup` reading "Locked. Press to enter the passcode." at muted 26 pt; the waiting-for-credential empty state (AC-37 test c), which is `groups.empty` with the text of that test and `groups.waiting.<sourceId>` rows in the style of 0010/AC-24. `groups.passcode.forgot.unavailable` (AC-24) and `groups.passcode.changed` (AC-43c), muted lines at the body size of the platform under the boxes and above them respectively. The boards in the repo are exports; the design canvas needs the same screens.

## Problem

A provider playlist arrives with hundreds of groups the user never watches, names they would not choose, adult content next to the kids' channels, and an order set by the provider. TiviMate users rank the ability to hide, lock, rename and reorder groups among the reasons they stay, and merging several playlists into one guide is the feature they praise most. Antenna shows every provider group as it comes, and nothing persists a change to that list.

## Scope

In:
- `GroupPolicy` in AntennaCore: rules per `CatalogueGroup` (hidden, locked, custom name, sort order) and user groups with members from any source. `Catalogue` applies it (Interface).
- Hidden groups leave the overlay, sidebar, chips, guide and All channels. They stay out of search unless the user opts in on this device.
- Locked groups: a four-digit passcode set once per iCloud account, verified on every device. While locks are closed on a device, locked channels are unreachable everywhere: group lists, All channels, Favorites, search, guide, digit entry and zapping. Entering the passcode opens the locks on that device until the app relaunches, spends 15 minutes in the background, sits 15 minutes without remote input on tvOS, or the user chooses Lock now.
- Rename a source group or a user group. Identity is unchanged, so favorites, the current group and sort order follow the rename.
- Reorder groups. Favorites and All channels stay pinned at the top. Channel order inside a source group is 0013/AC-6a's and is not changed by this spec: `tvg-chno` or the Xtream `num` first, playlist order as the fallback.
- User groups: create, rename, pick channels from any source, reorder members, delete. Members resolve like favorites (0013/AC-8). A user group is a `CatalogueGroup` like any other, so 0008's current group and 0009's guide grid work on it, which is how several playlists become one guide.
- The Groups screen on every platform, reached from Settings (tvOS: the Settings sheet of 0015/AC-12; iPad and Mac: Sources & Settings; iPhone: the Settings tab).
- Three synced records: `GroupRecord`, `GroupMemberRecord`, `ParentalRecord` (ADR needed, above). This spec owns the record-to-policy mapping in the app layer (AC-43) and the `PasscodeVerifier` (Interface).
- Until the Sources and Settings spec is accepted, the Groups entry is a row labelled "Groups" appended to the existing Settings list of 0004/AC-7 (`settings.groups`) on iOS, iPadOS and macOS.
- Accessibility identifiers with prefix `groups.`.

Out (explicitly):
- Hiding or locking VOD and series categories (a 0011 follow-up; 0011 lists parental controls as out).
- Quick actions on group rows in the overlay, sidebar or chips (long press, swipe, context menu). 0007 and 0010 list them as open questions; a follow-up spec adds them on top of this one.
- Hiding or reordering single channels, and per-channel number overrides (a channel editing spec).
- Sorting a user group by number instead of the user's order (open question).
- Locking the whole app, or locking Favorites and All channels.
- Time-based locks and content ratings.
- A passcode on Settings itself (the Sources and Settings spec).
- Importing TiviMate or other players' group configurations.
- Reset of the passcode on tvOS without another device (open question).

Required of other specs:
- 0013: `CatalogueGroup` gains `.user(UUID)`; `Catalogue.init` gains `policy: GroupPolicy<Token> = .none` and `locksOpen: Bool = false`; `groups` becomes the visible list of AC-1 and AC-9; `rows(in:)`, `count(of:)`, `match(digits:)` and the Favorites group follow AC-2, AC-5 and AC-7. 0013/AC-2, AC-3, AC-6b, AC-12 and AC-17 hold unchanged for `.none`.
- 0004 or the source-refresh spec: the loader passes the mapped policy to each catalogue rebuild and rebuilds when any `GroupRecord`, `GroupMemberRecord` or `ParentalRecord` changes.
- 0007: the group column lists `groups` (AC-9) with the lock glyph on locked groups; focusing a locked group while locks are closed shows `overlay.emptyGroup` with the text of AC-20a instead of 0007/AC-4's column, and select or swipe right on it runs AC-20b; `overlay.channelsHeader` reads the display name (AC-8) and, for a user group, "Your order" as it does for Favorites (AC-34); the current-group fallback of AC-10 applies after Menu.
- 0008: AC-15b's "All channels" fallback becomes AC-10's fallback; swipe and digit entry run over the visible rows, which AC-5 and AC-7 define; a playing channel that is in no visible row reads `zapBar.position` as its source group's display name with no position, and swipe up or down tunes to the first or last row of the current group.
- 0009: `guide.empty` reads the display name; a locked current group at Guide open runs AC-20b, Menu leaves the guide on the fallback group.
- 0010: sidebar and chips list `groups` with the lock glyph; selecting a locked group runs AC-20b; `browse.listHeader` reads the display name; Sources & Settings gains the Groups entry.
- 0012: `SearchIndex` is built from `searchableChannels` (AC-11), so programmes of excluded channels are excluded with them; 0012/AC-2 and AC-16 match and show the display name.
- 0015: AC-2a falls back to AC-2b when the stored channel is locked while locks are closed, and the Settings sheet gets the Groups entry.
- The Sources and Settings spec (not yet on main): owns the Settings list that the Groups entry sits in.

## Interface

Every criterion reads its result through one of these. Names are binding; signatures may gain labels or `Sendable` constraints in the implementing PR. All of it lives in AntennaCore and never imports SwiftData (ADR-0005).

```swift
extension CatalogueGroup {
    case user(UUID)
}

struct GroupRule<Token: Hashable & Sendable>: Hashable, Sendable {
    var group: CatalogueGroup            // .all, .named, .ungrouped or .user
    var isHidden: Bool
    var isLocked: Bool
    var customName: String?
    var sortOrder: Int?
    var createdAt: Date
    var recordToken: Token?
}

struct GroupMember<Token: Hashable & Sendable>: Hashable, Sendable {
    var groupID: UUID
    var channelID: String
    var sourceID: UUID?
    var sortOrder: Int
    var recordToken: Token?
}

struct UserGroup<Token: Hashable & Sendable>: Hashable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var members: [GroupMember<Token>]
}

struct GroupPolicy<Token: Hashable & Sendable>: Sendable {
    init(rules: [GroupRule<Token>], userGroups: [UserGroup<Token>], searchIncludesHidden: Bool)
    static var none: GroupPolicy
}

enum GroupOrphan<Token: Hashable & Sendable>: Hashable, Sendable {
    case rule(GroupRule<Token>)                  // its group exists in no finished source, or it lost a duplicate race
    case duplicateUserGroup(UserGroup<Token>)    // a second UserGroup with an id already taken
}

extension Catalogue {
    init(channels: [Channel], groupOrder: [UUID: [String]], favorites: [FavoriteSnapshot<Token>],
         policy: GroupPolicy<Token> = .none, locksOpen: Bool = false, loadedSourceIDs: Set<UUID> = [])

    var groups: [CatalogueGroup]                 // visible: not hidden; locked groups included
    var managedGroups: [CatalogueGroup]          // every group the Groups screen lists, hidden included, same order
    var orphans: [GroupOrphan<Token>]            // see AC-16
    func displayName(for group: CatalogueGroup) -> String?   // nil for .favorites, .all and .ungrouped without a custom name
    func isHidden(_ group: CatalogueGroup) -> Bool
    func isLocked(_ group: CatalogueGroup) -> Bool
    func isLocked(_ channel: Channel) -> Bool    // in a locked source group or a locked user group
    var searchableChannels: [Channel]
    func sortOrders(moving group: CatalogueGroup, to index: Int) -> [CatalogueGroup: Int]
    func unresolvedMembers(of group: CatalogueGroup) -> [GroupMember<Token>]
    func addingMember(_ channel: Channel, to group: CatalogueGroup) -> GroupMember<Token>?
    func membersToRemove(for channel: Channel, in group: CatalogueGroup) -> [GroupMember<Token>]
}
```

`loadedSourceIDs` holds the ids of sources that finished loading with at least one request succeeding. A rule for a source outside that set is neither applied nor an orphan.

Records in the app layer, mapped to and from the types above with `Token` as `PersistentIdentifier`, every property optional or defaulted per ADR-0002:

- `GroupRecord`: `id: UUID = UUID()`, `kindRaw: String = "named"` ("all", "named", "ungrouped", "user"), `sourceID: UUID?`, `providerName: String?` (the provider's group name for "named"), `name: String?` (custom name, or the user group's name), `isHidden: Bool = false`, `isLocked: Bool = false`, `sortOrder: Int?`, `createdAt: Date = .now`.
- `GroupMemberRecord`: `groupID: UUID?`, `channelID: String = ""`, `sourceID: UUID?`, `sortOrder: Int = 0`, `addedAt: Date = .now`. Same shape as `FavoriteRecord`.
- `ParentalRecord`: `salt: Data?`, `verifier: Data?`, `createdAt: Date = .now`. The passcode itself is never stored, synced or logged.

Mapping (AC-43): a "named", "ungrouped" or "all" `GroupRecord` maps to one `GroupRule`; a "user" `GroupRecord` maps to one `UserGroup` and one `GroupRule` for `.user(id)` carrying its `isHidden`, `isLocked`, `sortOrder` and `createdAt`; `GroupMemberRecord`s map to the `UserGroup.members` of their `groupID`.

Migration: additive, three new models and no change to `SourceRecord` or `FavoriteRecord`; SwiftData's lightweight migration applies.

The verifier lives in `Apps/Shared/Persistence/PasscodeVerifier.swift`, because it needs CryptoKit and ADR-0005 keeps AntennaCore on Foundation alone:

```swift
enum PasscodeVerifier {
    static func make(_ passcode: String, salt: Data) -> Data       // SHA-256 over salt plus passcode, 10 000 rounds
    static func verify(_ passcode: String, salt: Data, verifier: Data) -> Bool
}
```

Per-device state, in the injected `UserDefaults` suite, never in SwiftData: `groups.searchIncludesHidden` (Bool), `groups.lockoutUntil` (Date) and `groups.lockoutCount` (Int). The open-locks state lives in memory only.

Why the verifier syncs and the open state does not: tvOS Keychain items do not sync (0006 header), so a passcode kept in the Keychain could never reach an Apple TV without typing it there, and a child could then set one. With the verifier in the synced container a parent sets the passcode once on the phone, every device verifies it, and the lock takes effect on the Apple TV without anyone touching it. The open-locks state is per device because it answers "who is holding this remote now", which no other device can know.

## User flow

tvOS:
1. From the Settings sheet the user selects Groups. The Groups screen lists All channels, every source group, every user group and the New group row. When any group is locked and locks are closed, the passcode prompt comes first.
2. Moving focus down the list updates the panel. Select on Hide, Lock, Move up or Move down applies at once. Select on Rename opens the text field. Select on a user group's row opens the channel picker; the panel for a user group also offers Delete.
3. Lock on the first group ever asks the user to set a four-digit passcode, twice.
4. Menu returns to the Settings sheet; the overlay, zap bar and guide reflect the new list the next time they are shown.
5. Later, selecting a locked group in the overlay shows the prompt. Four correct digits open the locks and the group's channels appear. Menu returns to the previous group.

iPadOS and macOS:
1. Sources & Settings, then Groups. The middle column lists the groups; the detail column edits the selected one. Rows drag to reorder.
2. A user group's detail lists its channels with handles; Add channels opens the picker as a sheet.
3. The passcode prompt is a centred sheet. iPadOS types into it with the system numeric keyboard, macOS with the hardware keyboard.

iOS:
1. Settings tab, Groups. Tapping a row pushes its detail. Edit enables drag handles.
2. The prompt is a sheet.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Default policy changes nothing
Given the catalogue fixtures of 0013/AC-2, AC-6a and AC-8
When the catalogue is built with `policy: .none` and `locksOpen: false`
Then `groups`, `rows(in:)` for every group, `number(for:)`, `match(digits:)` and `rows(in: .favorites)` equal the results of the three-argument initialiser; `managedGroups` equals `groups` without `.favorites`; `orphans` is empty; `searchableChannels` equals the channels of `rows(in: .all)`.

### AC-2 Hidden group
Given the catalogue of 0013/AC-2 and a rule hiding `.named(A, "News")`
When the catalogue is built
Then `.named(A, "News")` is absent from `groups` and present in `managedGroups` with `isHidden` true and its 0013/AC-3 count; `rows(in: .all)` omits its channels and `count(of: .all)` drops by that number; `rows(in: .named(A, "News"))` still returns the group's rows, so the Groups screen can show them.

### AC-2b Hidden channels keep their numbers
Given the catalogue of AC-2
When `number(for:)` and `match(digits:)` run
Then `number(for:)` for every channel outside the hidden group is unchanged from AC-1, so hiding never renumbers; `match(digits:)` returns nil for a digit string that only a hidden channel matches.

### AC-3 Favorites survive hiding
Given a favorite that resolves to a channel in a hidden group
When the catalogue is built
Then `rows(in: .favorites)` lists it in 0013/AC-8 order and `isFavorite` is true for it; hiding affects groups, not favorites.

### AC-4 All channels can be hidden, Favorites cannot
Given a rule hiding `.all`
When the catalogue is built
Then `.all` is absent from `groups` and listed first in `managedGroups` with `isHidden` true; `.favorites` is listed first in `groups`, `isHidden(.favorites)` and `isLocked(.favorites)` are false.

### AC-5 Locked group while locks are closed
Given the catalogue of 0013/AC-2, a rule locking `.named(B, "Kids")`, a favorite in it, and `locksOpen: false`
When the catalogue is built
Then `.named(B, "Kids")` is listed in `groups` with `isLocked` true and its full count; `rows(in: .named(B, "Kids"))` is empty; `rows(in: .all)`, `rows(in: .favorites)`, `searchableChannels` and `match(digits:)` exclude its channels; `count(of: .all)` and `count(of: .favorites)` exclude them; `number(for:)` returns nil for each of them, so a number does not reveal the channel, and is unchanged from AC-1 for every other channel; `isLocked(channel)` is true for each of them and false for every other channel.

### AC-6 Locks open
Given the policy of AC-5 and `locksOpen: true`
When the catalogue is built
Then every query equals the AC-1 result for the same fixtures, `isLocked(.named(B, "Kids"))` stays true and `isLocked(channel)` stays true for its channels, so screens can keep the glyph while the rows are reachable.

### AC-7 Locked user group locks its members
Given a user group U with members from sources A and B, a rule locking `.user(U)`, and `locksOpen: false`
When the catalogue is built
Then `rows(in: .user(U))` is empty, the member channels are absent from `rows(in: .all)`, `rows(in: .favorites)`, `rows(in:)` of their source groups and `searchableChannels`, and `isLocked(channel)` is true for them; the same channels are present in all of those once `locksOpen` is true.

### AC-8 Display name
Given rules with `customName` "  Sports  ", "" and "   " for three source groups, and a user group named "Weekend sports"
When `displayName(for:)` runs
Then it returns "Sports" for the first, nil for the two blank ones (so the UI falls back to the provider name or its own label), "Weekend sports" for the user group; `rows(in:)` and `count(of:)` for a renamed group equal the unrenamed results; a `customName` longer than 60 characters is truncated to 60 after trimming; `displayName(for: .favorites)` and `displayName(for: .all)` are nil whatever the rules say.

### AC-9 Group order
Given source groups G1 to G4 in 0013/AC-2 order, user groups U1 (`createdAt` later) and U2 (earlier), and rules giving G3 `sortOrder` 0, U1 `sortOrder` 1, G1 `sortOrder` 2 and nothing for the rest
When the catalogue is built
Then `groups` is [`.favorites`, `.all`, G3, U1, G1, G2, G4, U2]: pinned groups first, then groups with a `sortOrder` ascending, then groups without one in 0013/AC-2 order, then user groups without one by `createdAt` ascending; two equal `sortOrder` values are ordered source groups first in 0013/AC-2 order, then user groups by `createdAt`; `managedGroups` is the same list without `.favorites` and with hidden groups in their positions.

### AC-10 Current group fallback
Given the current group (0008/AC-15) is G
When G becomes hidden, locked while locks are closed, or deleted, as reported by the next catalogue build
Then the app layer's current group becomes the first group in `groups` after `.favorites` that is not locked while locks are closed (`.all` when it is visible, since `.all` can be hidden but never locked), else `.favorites`; the fallback is never a group that would run AC-20b; the playing channel is unchanged unless AC-25a applies.

### AC-11 Searchable channels
Given hidden group H, locked group L, visible group V, and `searchIncludesHidden` false then true
When `searchableChannels` is read with `locksOpen: false`
Then with false it holds exactly the channels of `rows(in: .all)`; with true it adds H's channels and still excludes L's; with `locksOpen: true` and `searchIncludesHidden` true it holds every channel of every source group.

### AC-12 Member resolution
Given a user group with members M1 (`sortOrder` 1, `sourceID` nil), M2 (`sortOrder` 0, `sourceID` A), M3 (`channelID` not loaded) and M4 identical to M2
When `rows(in: .user(U))` runs
Then members resolve as 0013/AC-8 resolves favorites (by `channelID`, and by `sourceID` when non-nil, first in All channels order on ties), rows are in `sortOrder` order with ties broken by All channels order, a channel appears once at its lowest `sortOrder`, `count(of: .user(U))` equals the rows.

### AC-12b Unresolved members and empty user groups
Given the user group of AC-12, and a second user group whose only member does not resolve
When `unresolvedMembers(of:)` and `groups` are read
Then `unresolvedMembers(of: .user(U))` is [M3] ordered by `sortOrder` then `channelID`; the second group is listed in `groups` and `managedGroups` with count 0.

### AC-13 Adding and removing members
Given a user group U whose members' highest `sortOrder` is 4 and a channel C from source S not in U
When `addingMember(C, to: .user(U))` runs
Then it returns a `GroupMember` with `groupID == U`, `channelID == C.id`, `sourceID == S`, `sortOrder == 5`, `recordToken == nil`; with no members `sortOrder` is 0; when `membersToRemove(for: C, in: .user(U))` is non-empty it returns nil; for a group that is not `.user` it returns nil; `membersToRemove(for: C, in: .user(U))` returns every member of U whose `channelID == C.id` and whose `sourceID` is nil or equals S, and nothing else.

### AC-14 Order inside a source group is untouched
Given source group G with channels numbered 3, 5 (`position` 9), 5 (`position` 2) and two unnumbered channels at `position` 0 and 4, and rules that hide another group, rename G and move G to index 0
When `rows(in: G)` runs
Then the order is 0013/AC-6a's: provider numbers ascending, then source order, then `position`, with the unnumbered channels at the fallback numbers 0013/AC-5a assigns, so `tvg-chno` and `num` win and playlist order is the fallback; `number(for:)` for every row is the AC-1 value.

### AC-15 Move produces a full assignment
Given `managedGroups` [`.all`, G1, G2, G3, U1] built from rules with no `sortOrder`
When `sortOrders(moving: G3, to: 0)` runs
Then it returns [G3: 0, G1: 1, G2: 2, U1: 3] and no key for `.all` or `.favorites`; the index counts movable groups only, so 0 is the first position after `.all`; an index at or past the count of movable groups appends; moving `.all` or `.favorites` returns an empty dictionary; building a catalogue from rules carrying that assignment yields `managedGroups` [`.all`, G3, G1, G2, U1].

### AC-16 Duplicate rules
Given `loadedSourceIDs` [A] and two rules for `.named(A, "Sport")` with `createdAt` 10:00 and 10:05 and different `customName`s
When the catalogue is built twice from the same input
Then the 10:00 rule applies and the 10:05 rule is `.rule` in `orphans`; both builds give identical results (0013/AC-11b).

### AC-16b Rule for a missing group
Given `loadedSourceIDs` [A] and a rule for `.named(A, "Gone")` where no loaded channel has group "Gone"
When the catalogue is built
Then the rule is `.rule` in `orphans` and `.named(A, "Gone")` is in neither `groups` nor `managedGroups`.

### AC-16c Rule for a source not loaded
Given `loadedSourceIDs` [A] and a rule for `.named(B, "Sport")`
When the catalogue is built
Then the rule is neither applied nor in `orphans`.

### AC-16d Duplicate user groups
Given two user groups with the same id and `createdAt` 11:00 and 11:05
When the catalogue is built
Then the 11:00 user group applies and the 11:05 one is `.duplicateUserGroup` in `orphans`.

### AC-17 Policy application is fast
Given 50 000 channels in 400 groups, 300 rules, 20 user groups with 2 000 members in total and 100 favorites
When the catalogue is built with the policy
Then the build takes at most 1.5 times as long as the 0013/AC-14 build of the same channels without a policy, measured in the same `swift test` run on the same machine; benchmark, not CI-gated.

### AC-18 Setting the passcode
Given no `ParentalRecord` in the store and no locked group
When the user activates `groups.lock` for a group and enters "1234" then "1234" in the set-passcode prompt
Then one `ParentalRecord` with a non-empty `salt` and `verifier` and one `GroupRecord` with `isLocked` true exist, or when the save fails neither does; `PasscodeVerifier.verify("1234", salt:, verifier:)` is true and `verify("1235", ...)` is false; the group shows the LOCKED badge; locks are open on this device.

### AC-18b Passcode entries differ
Given the set-passcode prompt of AC-18
When the user enters "1234" then "4321"
Then `groups.passcode.error` reads "The passcodes don't match", the boxes clear for a new first entry, and no `ParentalRecord` or `GroupRecord` is inserted.

### AC-18c The passcode is never written
Given the flows of AC-18, AC-18b, AC-21a and AC-42 run with an injected logger
When the store, the defaults suite and the logger's output are searched for the digits typed
Then none contains them, and no log call receives a `ParentalRecord`, its `salt` or its `verifier`.

### AC-19a Groups screen is behind the passcode
Given at least one locked group and locks closed on this device
When the user opens the Groups screen
Then `groups.passcode` is shown in place of `groups.list`, and a correct passcode opens the locks and reveals `groups.list`.

### AC-19b Groups screen opens at once
Given no locked group (test a), or locked groups with locks open (test b)
When the user opens the Groups screen
Then `groups.list` is shown and `groups.passcode` is not.

### AC-20a Focus on a locked group on tvOS
Given locks closed and a locked group in the overlay (0007)
When focus rests on the group row
Then the channel column shows `overlay.emptyGroup` reading "Locked. Press to enter the passcode." and the panel is empty; the engine state is unchanged (DR-1).

### AC-20b Selecting a locked group shows the prompt
Given locks closed and a locked group in the overlay (tvOS: select or swipe right on the row), the sidebar or chips (0010: tap or click), or as the guide's current group when the Guide tab opens (0009)
When the user selects it, or the guide opens on it
Then `groups.passcode` is shown with the group's display name in its subtitle; digits from the on-screen keys, the system numeric keyboard or a hardware keyboard (tvOS and macOS) fill the boxes.

### AC-20c Correct passcode opens the group
Given the prompt of AC-20b
When four correct digits are entered
Then locks open for this device, the group becomes selected and its rows appear; the engine state is unchanged.

### AC-20d Dismissing the prompt
Given the prompt of AC-20b
When the user dismisses it: Menu on tvOS, Cancel or a tap outside the sheet on iOS and iPadOS, Cancel or Escape on macOS
Then the prompt closes, the previously selected group stays selected and the engine state is unchanged.

### AC-21a Wrong passcode
Given the prompt
When the user enters a wrong passcode, up to four times
Then after each entry `groups.passcode.error` reads "Wrong passcode" and the boxes clear.

### AC-21b Lockout after five wrong entries
Given the prompt and an injected clock
When the fifth wrong entry in a row is made
Then input is ignored (tvOS: the keys are disabled; other platforms: typed digits do not fill the boxes), the error line reads "Try again in 30 s" counting down on the injected clock, `groups.lockoutUntil` in the defaults suite is now plus 30 s and `groups.lockoutCount` is 1; when the time passes, input is accepted again.

### AC-21c Lockout grows and persists
Given `groups.lockoutCount` n after an earlier lockout
When the next run of five wrong entries ends, before or after a relaunch
Then the wait is 30 s times 2 to the power n, capped at 5 minutes, and the count is n plus 1; a relaunch during a lockout shows the remaining countdown; a correct entry removes both keys. The lockout is per device: it lives in this device's defaults suite, so another device or a reinstall starts without one (Open questions).

### AC-22 Verifier not yet synced
Given a locked `GroupRecord` in the store and no usable `ParentalRecord` (absent, or `salt` or `verifier` nil)
When the prompt would be shown
Then `groups.passcode.waiting` reads "Waiting for the passcode to sync from iCloud.", no digit box or key is shown, the set-passcode flow is not offered, and when a usable `ParentalRecord` arrives (injected store change) the prompt switches to the boxes without user action; on iOS, iPadOS and macOS `groups.passcode.forgot` is shown under the waiting line and activating it runs AC-24; on tvOS the waiting line is followed by the static `groups.passcode.forgot` text of AC-24.

### AC-23 Open locks end
Given locks open on this device
When the user activates `groups.lockNow`, or the app has been in the background for 15 minutes on the injected clock, or the process relaunches
Then locks are closed: the next catalogue build runs with `locksOpen: false`, the current group falls back per AC-10, and AC-25a applies to the playing channel; a background stay shorter than 15 minutes keeps the locks open. The 15 minutes count from the scene entering the background whether or not audio or Picture in Picture keeps playing; when they expire during background playback, AC-25a pauses it.

### AC-23b Locks close on an idle Apple TV
Given locks open on tvOS and an injected clock and idle source
When 15 minutes pass with no remote input, or the system reports the screen saver or sleep
Then locks close as in AC-23; remote input within the 15 minutes restarts the count.

### AC-24 Forgot passcode
Given the prompt on iOS, iPadOS or macOS and an injected device-owner authenticator
When the user activates `groups.passcode.forgot` and the authenticator succeeds
Then the set-passcode flow of AC-18 runs and on completion every existing `ParentalRecord` is deleted and one new record with the new `salt` and `verifier` is inserted, every locked group stays locked, and locks are open on this device; the reset is offered during a lockout too, because it needs the device owner's authentication and not the passcode; when the authenticator fails the prompt is unchanged; when it is unavailable (no device passcode set) `groups.passcode.forgot.unavailable` reads "Set a device passcode in Settings to reset it." and the prompt is otherwise unchanged; on tvOS `groups.passcode.forgot` is static text reading "Forgot it? Reset the passcode in Antenna on your iPhone, iPad or Mac." and no reset is offered.

### AC-25a Playing channel becomes locked
Given a channel is playing and locks are closed
When a catalogue build reports `isLocked(channel)` true for it (a local lock, a synced record or AC-23)
Then `pause()` is called once on the engine, `groups.passcode` is shown over the player with the channel's group name, the Now Playing info is cleared, and no `load(_:)` is called while the prompt is shown.

### AC-25b Passcode resumes playback
Given the prompt of AC-25a
When four correct digits are entered
Then `play()` is called once and the prompt closes.

### AC-25c Dismissal tunes away
Given the prompt of AC-25a
When the user dismisses it (Menu or Cancel)
Then `load(_:)` is called once with the first channel per 0006/AC-15 among the visible rows and the prompt closes; when no visible row exists the player closes to the shell.

### AC-26 Groups screen contents
Given the policy of AC-9 with G2 hidden, G4 locked and an orphan rule
When the Groups screen is shown with locks open
Then `groups.list` lists `groups.row.<groupKey>` for every `managedGroups` entry in order, each with the display name (or the provider name, "All channels", "Ungrouped · <source>"), `groups.row.<groupKey>.count` with the 0013/AC-3 count, `groups.row.<groupKey>.hidden` reading "HIDDEN" on G2, `groups.row.<groupKey>.locked` with the lock glyph on G4, "CUSTOM" on user groups, no move handle on `.all`, and `groups.new` as the last row before the orphan section; when more than one source is loaded a source group row also shows `groups.row.<groupKey>.source` with the source name in the muted caption.

### AC-26b Row sizes
Given the Groups screen of AC-26
When the frame of `groups.row.<groupKey>` is read
Then it is 72 pt tall on tvOS (80 when focused), 44 on iPadOS and macOS and 52 on iOS (DR-5).

### AC-27 Orphan rules on the Groups screen
Given `orphans` holds a `.rule` for `.named(A, "Gone")`, a `.rule` for `.all` that lost a duplicate race and a `.duplicateUserGroup`
When the Groups screen is shown
Then a section headed "Not in any source" lists `groups.orphan.<groupKey>` for each, reading "<customName or providerName> · <source name>" for a named or ungrouped rule, "All channels" for `.all`, and "<name> (duplicate)" for a user group, each with `groups.orphan.<groupKey>.remove`; activating Remove deletes that `GroupRecord` (and, for a user group, its `GroupMemberRecord`s) and the row; the section is absent when `orphans` is empty; the app passes only finished sources in `loadedSourceIDs`, so a rule whose source is loading, failed or waiting for its credential is not listed.

### AC-28 Hide and show
Given the Groups screen with locks open
When the user activates `groups.hide` for G1 (tvOS panel) or the Hidden row in G1's detail (iOS, iPadOS, macOS)
Then a `GroupRecord` for G1 is inserted if absent and `isHidden` is set, the row shows the HIDDEN badge, and `groups` from the next catalogue build omits G1; activating again clears `isHidden` and removes the badge; a record whose `isHidden`, `isLocked`, `name` and `sortOrder` are all back to their defaults is deleted rather than kept.

### AC-29 Rename
Given G1's detail or panel
When the user enters "  Sports  " in `groups.name` and commits (Return, Done, or focus leaving the field)
Then the `GroupRecord` for G1 has `name` "Sports", the row and `groups.name` read "Sports"; committing an empty or whitespace-only name clears `name` and the row reads the provider name again; text beyond 60 characters is not accepted by the field.

### AC-29b Rename a user group
Given a user group's detail or panel
When the user commits "  Weekend  " then an empty string in `groups.name`
Then after the first commit the `GroupRecord` has `name` "Weekend"; the empty commit is rejected with `groups.name.error` reading "Give the group a name" and the name stays "Weekend".

### AC-30 Reorder groups
Given the Groups screen with `managedGroups` [`.all`, G1, G2, G3]
When the user activates `groups.moveUp` on G3 (tvOS) or drags G3 above G1 (iOS, iPadOS, macOS)
Then the `GroupRecord`s carry the AC-15 assignment for the resulting order, the list shows the new order, and focus (tvOS) or selection stays on G3; `groups.moveUp` is disabled on the first movable row and `groups.moveDown` on the last; `.all` has neither control and cannot be dragged.

### AC-31 Lock and unlock a group
Given a `ParentalRecord` exists and locks are open
When the user activates `groups.lock` for G1
Then the `GroupRecord` for G1 has `isLocked` true and the row shows the LOCKED badge; activating it again clears `isLocked`; neither direction prompts for the passcode, because AC-19a already did.

### AC-32 Create a user group
Given the Groups screen
When the user activates `groups.new` and commits the name "Weekend sports"
Then a `GroupRecord` with `kindRaw` "user", that `name`, `sortOrder` nil and no members is inserted (a group record carries no `channelID`, so this criterion is not blocked by the 0001 follow-up; AC-33 is), the group appears as the last user group without a `sortOrder` (AC-9), it is selected or focused, its detail shows "No channels yet" and `groups.addChannels`, and the overlay, sidebar and chips list it with count 0 the next time they are shown.

### AC-33 Pick channels
Given a user group's detail with locks open
When the user activates `groups.addChannels`
Then `groups.picker` lists `groups.picker.row.<rowKey>` for every channel of every source group in 0013/AC-6b order, hidden groups included, with the check glyph on current members, the number, the logo or initials tile, the name and the source name; typing in `groups.picker.filter` filters through a `SearchIndex(channels:, programmes: [], titles: [])` over those channels, so name and number matching is 0012's own code (0012/AC-2, AC-3) and not a copy, without a debounce; select or tap toggles membership, inserting the AC-13 member as a `GroupMemberRecord` or deleting the AC-13 removal set; `groups.picker.done` and Menu close the picker; when locks close while the picker is open (AC-23), the picker is dismissed and AC-19a applies; no `GroupMemberRecord` is inserted while `Channel.id` can contain a stream URL (header).

### AC-33b Picker filter over a huge source
Given 50 000 channels in the picker
When one character is typed in `groups.picker.filter`
Then the filtered rows are returned within 100 ms in a `swift test` benchmark of the `SearchIndex` call, not CI-gated, and the list on device updates within one frame of that result.

### AC-34 Reorder members
Given a user group with members M0 to M3 in that order
When the user drags M3 above M1 (iOS, iPadOS, macOS) or activates `groups.member.moveUp` on M3 twice (tvOS panel of `groups.member.<rowKey>`, which also offers `groups.member.moveDown` and `groups.member.remove`)
Then the `GroupMemberRecord`s' `sortOrder` values read 0, 1, 2, 3 for M0, M3, M1, M2 and `rows(in: .user(U))` follows; `groups.member.remove` deletes the AC-13 removal set for that row.

### AC-35 Delete a user group
Given a user group U that is the current group
When the user activates `groups.delete` and confirms "Delete group" in the confirmation
Then U's `GroupRecord` and every `GroupMemberRecord` with `groupID == U` are deleted, the row disappears, selection moves to the next row or the previous, and the current group falls back per AC-10; Cancel changes nothing; `groups.delete` is absent for source groups and `.all`.

### AC-36 Hidden channels in search
Given the Groups screen
When the user activates `groups.searchHidden`
Then the row shows the check glyph, `groups.searchIncludesHidden` is true in the defaults suite and no SwiftData record changes; the next catalogue build has `searchIncludesHidden` true in its policy; activating again reverses it.

### AC-37 Empty states
Given sources that have all finished loading with no channel (test a), or one loaded source whose channels all have `group` nil (test b), or sources that are all waiting for their credential (test c)
When the Groups screen is shown
Then in a `groups.empty` reads "No groups yet. Add a source in Settings and its groups appear here." and `groups.list` and `groups.new` are absent; in b the list holds `.all`, `.ungrouped(S)` reading "Ungrouped · <source name>" and `groups.new`; in c `groups.empty` reads "Waiting for your sources to sign in from iCloud." followed by `groups.waiting.<sourceId>` reading "<name> · waiting for login" per source, as 0010/AC-24, and `groups.list` and `groups.new` are absent.

### AC-38 tvOS focus and Menu
Given the Groups screen on tvOS with focus on a row
When the user swipes right
Then focus moves to the first enabled action in the panel for that row; swipe left from the panel returns to the row; Menu from the panel returns to the row; Menu from the list returns to the Settings sheet with `shell.settingsSheet` present and the engine state unchanged; Menu from `groups.passcode` on the Groups screen returns to the Settings sheet.

### AC-38b tvOS focus targets
Given every tvOS board of this spec rendered in a UI test
When the frames of focusable elements are read
Then each is at least 64 pt tall, except `groups.passcode.key.<d>` at 56 pt (Design, DR-5 deviation).

### AC-39 Large group sets
Given 400 groups and 20 user groups
When the Groups screen is opened
Then the first frame with rows is drawn within one second on an Apple TV 4K (3rd generation) and an iPhone 15, and a Move up on tvOS is reflected in the list within 100 ms.

### AC-40 Sync between devices
Given device A hides G1, renames G2, locks G3 and creates user group U
When device B, signed into the same iCloud account, is online
Then B's overlay or sidebar omits G1, shows G2's new name, shows G3 with the lock glyph and lists U with its members; B's locks are closed until the passcode is entered on B; A's locks are unaffected by anything B does.

### AC-41 Lock with an existing passcode while locks are closed
Given a usable `ParentalRecord`, no locked group and locks closed
When the user activates `groups.lock` for G1
Then `groups.passcode` is shown first; a correct entry opens the locks and AC-31 applies; a dismissal leaves G1 unlocked.

### AC-42 Change the passcode
Given locks open
When the user activates `groups.setPasscode` and completes the set-passcode flow of AC-18
Then every existing `ParentalRecord` is deleted and one new record with the new `salt` and `verifier` is inserted, every locked group stays locked, and locks stay open on this device; a mismatch in the second entry leaves the old record in place.

### AC-43 Record mapping
Given a store holding a "named" `GroupRecord` with nil `sourceID`, a "named" one with nil `providerName`, a "user" one with nil `name`, one with `kindRaw` "favorites", one with `kindRaw` "later", a `GroupMemberRecord` with nil `groupID`, a `GroupMemberRecord` whose `groupID` matches no "user" record, a `ParentalRecord` with nil `salt`, two usable `ParentalRecord`s with `createdAt` 10:00 and 10:05, and one valid record of each kind
When the policy is mapped
Then each malformed record is ignored and maps to nothing; the 10:00 `ParentalRecord` is the verifier in use; the valid records map to the `GroupRule`, `UserGroup`, `GroupMember` values of the Interface with their `recordToken` set; a "user" `GroupRecord` yields both a `UserGroup` and a `GroupRule` for `.user(id)`; no `GroupRule` names `.favorites`. Mapping writes nothing.

### AC-43b Duplicate passcode records
Given two usable `ParentalRecord`s, as two offline devices each setting a first passcode produce
When the store change is observed
Then the record with the later `createdAt` is deleted and the earlier one stays.

### AC-43c The losing device is told
Given this device set the passcode whose `ParentalRecord` AC-43b deleted
When the prompt is next shown on it
Then `groups.passcode.changed` reads "The passcode was changed on another device." above the boxes, and only the remaining record's passcode opens the locks.

### AC-44 Tune requests from outside the lists
Given locks closed and a locked channel that is the stored channel at launch (0015/AC-2a), the target of a Now Playing or remote command, or the target of any later URL or Shortcut handler
When the app is asked to tune it
Then `load(_:)` is not called for it, it does not appear in the Now Playing info, and the request runs AC-20b for its group; dismissal leaves the app on the AC-10 fallback.

### AC-45 Deleting a source
Given a source S with `GroupRecord`s and `GroupMemberRecord`s whose `sourceID` is S
When S is deleted (0004)
Then those records are deleted in the same save; members with `sourceID` nil that resolved to S's channels stay and become unresolved (AC-12b); user groups stay.

### AC-46 tvOS text entry
Given the Groups screen on tvOS
When focus moves to `groups.name` (after Rename) or `groups.picker.filter` and the user presses select
Then the system keyboard opens with dictation available, and Done commits as AC-29 and AC-29b say for `groups.name` and filters as AC-33 says for `groups.picker.filter`.

### AC-47 VoiceOver and Reduce Motion
Given VoiceOver on (test a) or Reduce Motion on (test b)
When a group row and the passcode prompt are read or shown
Then in a the row's label is the name, the count and "hidden" or "locked" where they apply, and each digit box reads "digit n of 4, filled" or "digit n of 4, empty"; in b the prompt appears without animation.

### AC-48 Groups entry in Settings
Given the Settings list of 0004/AC-7 on iOS, iPadOS and macOS, and the Settings sheet of 0015/AC-12 on tvOS
When it is shown
Then `settings.groups` reads "Groups" after the source rows and opens the Groups screen.

## Edge cases and failure modes

- Offline: everything here is local; records queue for sync. A device that never comes online keeps its own view.
- Slow or huge source: the policy is applied in the same build as 0013 (AC-17); the Groups screen is virtualised (AC-39). Rules for a source still loading are not orphans (AC-27).
- Malformed records: AC-43 lists them. A record with `kindRaw` "favorites" is among the ignored ones, so Favorites can never be hidden or locked (AC-4).
- Credential not yet synced: the source's groups are absent (0004/AC-10); the app leaves it out of `loadedSourceIDs`, so its rules are neither applied nor orphans; its locked groups cannot leak because they have no channels. AC-37 test c shows the state.
- iCloud signed out: the records stay in the local store and never sync, so the passcode and every rule apply on this device only until the account signs in, when the AC-43b rule settles any duplicate verifier.
- Offline at launch: no source is in `loadedSourceIDs`, so no rule is an orphan and nothing can be removed by mistake.
- First launch with an empty store: 0006/AC-1 shows onboarding and the Groups screen is unreachable.
- tvOS, remote only: reorder by Move up and Move down (AC-30, AC-34); passcode by the on-screen digit row or a hardware keyboard; no drag anywhere.
- A provider renames a category: the old rule becomes an orphan (AC-27) and the new group arrives unmanaged. A user group keyed by its own id is unaffected.
- Provider category and user group with the same display name: both listed; identity is the `CatalogueGroup`, never the name.
- Two devices rename or reorder at once: CloudKit's last writer wins per record; `sortOrder` collisions fall back to AC-9's tie rule, so the list is deterministic on every device even when it differs from what either user saw.
- Locking a group while its channel is on screen on another device: AC-25a on that device once the record arrives.
- A locked channel that is also a favorite or a user-group member: unreachable through every path while locks are closed (AC-5, AC-7); the Favorites count excludes it.
- Zapping (0008/AC-9) and digit entry (0008/AC-10) run over visible rows, so they skip hidden and locked channels without their own rule.
- Reduce Motion and VoiceOver: AC-47.
- `Channel.streamURL` is never part of a `groupKey`, a `GroupMemberRecord`, an identifier or a log line (ADR-0003); the passcode never leaves the prompt's view model (AC-18).
- Entitlement lapses (ADR-0006): the paywall replaces every screen here; records are kept.

## Test plan

Core criteria are swift-testing tests over fixtures in AntennaCore with `Token` as `Int`. Integration tests use an in-memory `ModelContainer`, an injected `UserDefaults` suite, an injected clock, a fake engine recording `pause()`, `play()` and `load(_:)`, and a fake device-owner authenticator. UI tests run with fixture catalogues and launch arguments naming the policy and the lock state. Identifiers: `groups.root`, `groups.list`, `groups.row.<groupKey>`, `groups.row.<groupKey>.count`, `groups.row.<groupKey>.source`, `groups.row.<groupKey>.hidden`, `groups.row.<groupKey>.locked`, `groups.row.<groupKey>.custom`, `groups.new`, `groups.orphans`, `groups.orphan.<groupKey>`, `groups.orphan.<groupKey>.remove`, `groups.panel`, `groups.detail`, `groups.name`, `groups.name.error`, `groups.rename`, `groups.hide`, `groups.lock`, `groups.moveUp`, `groups.moveDown`, `groups.delete`, `groups.members`, `groups.members.empty`, `groups.member.<rowKey>`, `groups.member.moveUp`, `groups.member.moveDown`, `groups.member.remove`, `groups.addChannels`, `groups.picker`, `groups.picker.filter`, `groups.picker.row.<rowKey>`, `groups.picker.done`, `groups.searchHidden`, `groups.lockNow`, `groups.setPasscode`, `groups.passcode`, `groups.passcode.digit.<n>`, `groups.passcode.key.<d>`, `groups.passcode.error`, `groups.passcode.forgot`, `groups.passcode.forgot.unavailable`, `groups.passcode.changed`, `groups.passcode.waiting`, `groups.empty`, `groups.waiting.<sourceId>`, `settings.groups`. `<groupKey>` is a string the implementing PR derives from the `CatalogueGroup` (kind, source id and a hash of the provider name, or the user group id); it never contains a stream URL.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core | TBD |
| AC-2 | core | TBD |
| AC-2b | core | TBD |
| AC-3 | core | TBD |
| AC-4 | core | TBD |
| AC-5 | core | TBD |
| AC-6 | core | TBD |
| AC-7 | core | TBD |
| AC-8 | core | TBD |
| AC-9 | core | TBD |
| AC-10 | integration (current-group model) | TBD |
| AC-11 | core | TBD |
| AC-12 | core | TBD |
| AC-12b | core | TBD |
| AC-13 | core | TBD |
| AC-14 | core | TBD |
| AC-15 | core | TBD |
| AC-16 | core | TBD |
| AC-16b | core | TBD |
| AC-16c | core | TBD |
| AC-16d | core | TBD |
| AC-17 | core benchmark | TBD |
| AC-18 | integration (in-memory container, verifier) + ui | TBD |
| AC-18b | integration + ui | TBD |
| AC-18c | integration (injected logger, defaults, store scan) | TBD |
| AC-19a | ui | TBD |
| AC-19b | ui (tests a and b) | TBD |
| AC-20a | ui (tvOS overlay; fake engine) | TBD |
| AC-20b | ui (tvOS overlay, iPad sidebar, iPhone chips, guide; hardware keyboard on macOS) | TBD |
| AC-20c | ui (fake engine) | TBD |
| AC-20d | ui (each platform's dismissal; fake engine) | TBD |
| AC-21a | ui | TBD |
| AC-21b | integration (injected clock, defaults) + ui | TBD |
| AC-21c | integration (injected clock, defaults, relaunch) | TBD |
| AC-22 | ui (injected store change; forgot path on iPad, static text on tvOS) | TBD |
| AC-23 | integration (injected clock, lifecycle events) | TBD |
| AC-23b | integration (injected clock, injected idle source) | TBD |
| AC-24 | ui (fake authenticator; tvOS static text) | TBD |
| AC-25a | integration (fake engine, Now Playing fake) + ui | TBD |
| AC-25b | integration (fake engine) | TBD |
| AC-25c | integration (fake engine) | TBD |
| AC-26 | ui | TBD |
| AC-26b | ui (frames) | TBD |
| AC-27 | ui | TBD |
| AC-28 | integration + ui | TBD |
| AC-29 | integration + ui | TBD |
| AC-29b | integration + ui | TBD |
| AC-30 | integration + ui (tvOS and iPad) | TBD |
| AC-31 | integration + ui | TBD |
| AC-32 | integration + ui | TBD |
| AC-33 | ui | TBD |
| AC-33b | core benchmark | TBD |
| AC-34 | integration + ui (tvOS and iPad) | TBD |
| AC-35 | integration + ui | TBD |
| AC-36 | integration (defaults) + ui | TBD |
| AC-37 | ui (three fixtures) | TBD |
| AC-38 | ui (tvOS) | TBD |
| AC-38b | ui (tvOS frames) | TBD |
| AC-39 | device | manual on Apple TV 4K and iPhone 15 with a 400-group fixture |
| AC-40 | device | CloudKit cannot run in CI; manual two-device check |
| AC-41 | ui | TBD |
| AC-42 | integration + ui | TBD |
| AC-43 | integration (in-memory container) | TBD |
| AC-43b | integration (in-memory container, injected store change) | TBD |
| AC-43c | ui | TBD |
| AC-44 | integration (fake engine, Now Playing fake) | TBD |
| AC-45 | integration (in-memory container) | TBD |
| AC-46 | ui (tvOS) | TBD |
| AC-47 | ui (accessibility labels, Reduce Motion launch argument) | TBD |
| AC-48 | ui | TBD |

## Open questions

Decisions made without an interview; each can be overturned at review.

- Passcode verifier in the synced container (ADR needed). The alternative is a passcode per device in the local Keychain, which keeps ADR-0003 untouched but lets anyone at the Apple TV set the first passcode there.
- Locked channels vanish from All channels, Favorites, search, guide, zapping and digit entry while locks are closed, rather than showing a lock glyph in place. Chosen because a listed-but-blocked channel still exposes its name and programme title.
- Hidden groups' channels leave All channels too. TiviMate does the same; the alternative keeps All channels complete and makes hiding cosmetic.
- Favorites in a hidden group stay in Favorites (AC-3).
- Open locks end on relaunch, Lock now, or 15 minutes in the background (AC-23). The duration is a guess.
- Four digits, fixed. Six digits or a free passphrase would cost a keyboard on tvOS.
- Lockout after five wrong entries, doubling from 30 s to 5 minutes (AC-21b, AC-21c).
- The reset on iOS, iPadOS and macOS needs only the device owner's authentication (AC-24), so a child who knows the family iPad's passcode can reset the parental passcode. Chosen because the alternative, the Apple ID password, is not available to an app. The lockout (AC-21c) is per device and a reinstall clears it.
- Locks close after 15 minutes without remote input on tvOS (AC-23b), because a tvOS app is rarely relaunched or backgrounded.
- A locked channel's number is hidden while locks are closed (AC-5), so the number does not reveal what sits there.
- No passcode reset on tvOS without another Apple device (AC-24). The alternative is a reset that deletes every lock, which defeats the lock.
- The Groups screen is wholly behind the passcode when any group is locked (AC-19a), so hiding is also protected. The alternative protects only the Lock control.
- "Include hidden channels in search" is per device in `UserDefaults` (AC-36). Syncing it needs a settings record no ADR has introduced.
- New user groups append at the end (AC-9). TiviMate puts them first.
- Members of a user group are in the user's order with no sort-by-number option. A later revision can add a per-group sort flag to `GroupRecord`.
- Picker lists every channel including hidden groups (AC-33), so a user can hide a provider group and still pull two of its channels into a user group.
- Favorites is not a user group. Unifying `FavoriteRecord` into `GroupMemberRecord` would simplify this spec and 0013 but changes a shipped schema (ADR-0002 migration).
- The orphan section (AC-27) could instead clean up silently after a configurable period.

## Dropped

- AC-19 is split into AC-19a and AC-19b; its Then covered three Givens.
- AC-29's user-group clause is split out as AC-29b; source and user groups reject an empty name differently.
- AC-37 test a (no `SourceRecord`): unreachable, because 0006/AC-1 shows onboarding and no Settings exists. Replaced by the waiting-for-credential case.
- AC-4's `.favorites` rule clause: no record can produce such a rule; AC-43 owns the mapping.
- AC-20 is split into AC-20a to AC-20d; one Then covered the focus text, the prompt, the unlock and four dismissal paths.
- AC-21 is split into AC-21a to AC-21c.
- AC-25 is split into AC-25a to AC-25c.
- AC-2's numbering and digit-match clauses moved to AC-2b, AC-12's unresolved and empty-group clauses to AC-12b, AC-16's four cases to AC-16 to AC-16d, AC-18's mismatch and no-leak clauses to AC-18b and AC-18c, AC-26's row heights to AC-26b, AC-38's focus-size clause to AC-38b, and AC-43's deletion of the later `ParentalRecord` to AC-43b.
