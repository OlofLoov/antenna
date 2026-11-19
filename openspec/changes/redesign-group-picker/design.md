# Design

## Context

Live and the Guide on iPhone, and in a narrow iPad Split View, pick a group from `Browse.Chips`, a lazy horizontal row of `Browse.Chip`s under the now-playing line (`LiveGroupChips` in `LiveCompactView.swift`, `GuideCompactScreen.groups`). Locked groups follow as "(locked)" chips (`LockedGroupChips`). `fix-live-group-switching` made the row lazy so 300 chips do not stall, but the row still shows about four chips at a 390 pt width, has no counts and no search, and the open chip scrolls out of sight.

iPad in regular width and the Mac show the same groups in `Browse.Sidebar` as `Browse.GroupRow`s with counts (`LiveRegularView.liveGroups`). That list already serves as the sidebar column the owner asked for; it lacks only search.

`Catalogue.groups` gives the order every list uses: Favorites, Recents and New when they resolve, All channels unless hidden, then the source groups and own groups in the user's order, with hidden and locked groups left out. `Catalogue.lockedGroups` lists the locked ones, and `unlockGroup` from `GroupLockPrompt` asks for the passcode.

## Boards

- `iPhone-Live-Groups` (new): the Groups sheet at the medium detent over Live, and at the large detent far down a provider's list with a locked group.
- `iPhone-Live-Groups-Search` (new): a search that matches four groups, and one that matches nothing.
- `iPad-Live-Groups-Search` (new): the sidebar with a search typed into its groups.
- `iPhone`, `iPhone-RTL`, `iPhone-Guide`, `iPhone-Guide-Detail`, `iPhone-Guide-Placeholders`, `iPhone-Banner`, `iPhone-EmptyFavorites`, `iPhone-Live-New`, `iPhone-Recents`, `iPhone-Reminder-Banner`, `iPhone-Player`, `iPhone-Player-Error`, `iPhone-Player-Tracks`, `iPhone-Player-Timeshift` and `iPhone-Player-Timeshift-RTL`: the chip row is replaced by the group button, in the same place.
- The design-system reference, sections 2 and 7, names the group button and the sidebar search.

Design-system requirements followed: `design-system/controls-use-system-styles` (the button is a plain system button with no fill, stroke or glass; the sheet is a system list), `design-system/modals-are-system-presentations` (a system sheet with detents and the system close button), `design-system/targets-are-large-enough-to-hit` (44 pt button and rows), `design-system/type-uses-text-styles`, `design-system/layouts-mirror-in-right-to-left-languages`, `design-system/accessibility-identifiers-follow-the-board`.

Not drawn: the sheet in Arabic (it mirrors as any system list, see `iPhone-RTL`), and the folded iPad sidebar, which is the same sidebar over the list.

## Decisions

### One button and a sheet in place of the chips

Options considered:
- Keep the chips and add a "More" chip that opens a list (rejected): two ways to do one thing, and the row still hides where the user is.
- A system `Menu` from the button (rejected): a menu of 300 items has no search and no counts on the trailing edge, and it covers the picture.
- A pushed list in a navigation stack (rejected): Live has no navigation bar on iPhone, and pushing covers the picture the user is watching.
- A button that opens a sheet at the medium detent, with search, counts and a checkmark (chosen). The medium detent keeps the picture in view above the sheet, and the large detent gives room for long lists. The owner asked on 2026-11-19 for a layout that makes sense on iPhone; the agent coordinating that work chose this one on his behalf, so he may still want to change it.

The button (`Browse.GroupButton`) shows the open group's name, a middle dot, its channel count and a `chevron.down`, leading-aligned across the width at a 44 pt minimum height. It is a plain button with no background, so no glass, fill or stroke is mixed (`design-system/controls-use-system-styles`). The name is `.headline`, the count and chevron `.subheadline` in the muted color. VoiceOver reads "Sport, 42 channels" from the existing "%@, %lld channels" entry, with the hint "Opens the list of groups".

The sheet (`LiveGroupSheet`) is a `NavigationStack` with a `List`, the inline title "Groups", a `.searchable` field always shown in the navigation bar drawer with the prompt "Search groups", and `Button(role: .close)` as the cancellation action. Detents are `.medium` and `.large`. Two untitled sections: the built-in groups (Favorites, Recents, New, All channels, whichever the catalogue lists), then the rest, with locked groups after them. When nothing matches, the system search empty state (`ContentUnavailableView.search`) replaces the list. Each row is `Browse.GroupChoiceRow`: a checkmark slot, the group's glyph for built-in groups, the name, and the count at the trailing edge, or a lock with no count. The sheet opens scrolled to the open group, so a group 150 rows down is in view.

Picking a row calls `LiveModel.show(_:)`, as the chips did, so the pick is remembered for the next launch and the Guide and Live share it, then closes the sheet. Picking a locked row closes the sheet and asks for the passcode from the sheet's `onDismiss`, since a second sheet cannot be presented while the first is still on screen.

### Search lives in AntennaCore

`GroupChoices` (`Packages/AntennaCore/Sources/AntennaCore/Catalogue/GroupChoices.swift`) takes a catalogue, the query and the label function, and returns the built-in choices, the other choices and the locked ones, each with its index in `Catalogue.groups`, or none for a locked group. It matches with `ChannelFilter`, so case and accents are ignored and every typed word must appear in the name, as in Live's channel filter. Built-in groups match by the name shown in the app's language. The label function is the app's `Catalogue.label(of:)`, so a group the user renamed matches by its new name. `CatalogueGroup.isBuiltIn` says which groups are pinned.

Options considered:
- Filter in the view with `localizedStandardContains` (rejected): logic belongs in AntennaCore, and it would match differently from the channel filter.
- Search also inside channel names, so "BBC" finds the group holding BBC One (rejected for now): Search already finds channels, and a group list that answers with groups whose names do not match reads as wrong.

### iPad and Mac keep the sidebar

On iPad in regular width and on a Mac the sidebar already lists the groups with their counts beside the channel list, so no `NavigationSplitView` is added. A `Browse.FilterField` heads the groups on Live and the Guide, labelled "Search groups" with the identifier `browse.groups.search`, and narrows the rows through `GroupChoices`. The query lives in `LiveRegularView` and clears when the section changes. When nothing matches, a muted "No groups match" line takes the rows' place. Movies and Series keep their genre rows without a field.

### Identifiers

- `browse.groups`: the group button on Live. `guide.groups`: the group button on the Guide, which replaces `guide.chips`.
- `browse.groups.sheet`: the sheet's list. `browse.groups.close`: its close button. `browse.groups.empty`: the empty search state.
- Rows keep the chips' identifiers so a test reads the same row: `browse.group.<index>` in Live's sheet and the sidebar, `guide.group.<index>` in the Guide's sheet, `groups.new` for New, `browse.locked.<storageKey>` for a locked group. The index is the group's place in the full list, so it does not change while searching.
- `browse.groups.search`: the sidebar's search field.

`LiveGroupChips` and `LockedGroupChips` are deleted. `Browse.Chips` and `Browse.Chip` stay for the scope chips in Search.

### The Guide list on another group

`GuideCompactList` takes `.id(live.group)`, as Live's list already does, so another group's rows open at the first row with the filter field above it out of sight.

### Testing

`GroupChoicesTests` in AntennaCore cover order, built-in pinning, locked groups, accent and case folding, renamed groups and indexes. iPhone UI tests open the sheet with a helper, `XCUIApplication.pickGroup(_:)`, that taps the group button when the row is not on screen. `GroupPickerUITests` opens the sheet, searches, picks and checks the list changed, and with `-ui-testing-many-groups`, a Debug launch argument that adds 200 provider-named groups to Home, scrolls the sheet to the end and finds one group by search. `LiveRegularUITests` searches the sidebar. `AppJourneys` opens the sheet to reach New.

## Platforms

iPhone, iPad and Mac. On iPhone and in a narrow iPad Split View the button and sheet replace the chips in Live and the Guide. On iPad in regular width and on a Mac the sidebar stays the group list and gains search. Apple TV is out of scope: its channel overlay has its own group column, which `tv-channel-overlay` covers.

## Risks

- Picking a group now takes two taps on iPhone where a chip on screen took one. The sheet opening on the open group, with the built-in groups at the top, keeps the common picks one swipe away.
- UI tests that read `browse.group.<n>` without opening the sheet fail on iPhone. Every test that touched a chip moves to `pickGroup(_:)` or opens the sheet.
