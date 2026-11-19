# Proposal

## Why

> As an on-the-go viewer with a big IPTV subscription, when I want another channel group on my iPhone, I want to see every group, how many channels each has and which one I'm in, and find "UK ▸ SPORTS HD" by typing "sport".

On 2026-11-19 the owner said that on iPhone "the channel group menu needs a different layout, the way it is right now makes no sense." Live and the Guide on iPhone pick a group from a row of chips that scrolls sideways under the now-playing line. Real providers send 50 to 300 groups or more, named like "SE | NEWS" or "UK ▸ SPORTS HD". The row shows about four chips at a time, gives no counts and has no search, and once the open chip scrolls out of view nothing on screen says which group is open.

iPad and Mac already list the groups in the sidebar with their counts, but have no way to search them either.

## What Changes

- On iPhone, and on iPad in a narrow Split View, Live and the Guide replace the chip row with one group button: the open group's name, its channel count and a chevron, full width and leading-aligned.
- The button opens a Groups sheet at the medium detent, which drags up to the large one. It has a search field, the built-in groups first (Favorites, Recents, New when they show, All channels), then every other group in the provider's order or the user's order, each with its channel count and a checkmark on the open one. Locked groups follow with a lock and no count, as they do today.
- Picking a group closes the sheet and shows its channels from the top. The channel keeps playing, the pick is remembered as today, and Live and the Guide keep sharing one open group.
- On iPad in regular width and on a Mac, the sidebar stays the group list, in the same order with the same counts, and gains a search field above the groups on Live and the Guide.
- Typed text narrows the groups the way Live's channel filter narrows channels: case and accents ignored, every word somewhere in the name.

Out of scope:
- Swiping the channel list left or right to change group.
- The Apple TV channel overlay's group column.
- Genres in Movies and Series, which keep their chips and sidebar rows.
- Sorting groups or showing them by source in the sheet. The order is the one group management already sets.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: the iPhone layout names the group button in place of the chips; picking a group covers the sheet; a new requirement covers finding a group among hundreds by search, in the sheet and in the sidebar.
- `guide-on-iphone-ipad-and-mac`: the iPhone guide shows the group button above the day chips, and an empty group keeps the button working.
- `design-system`: the right-to-left scenario for the group chips becomes the group button and sheet.
- `localization`: a provider group named in Arabic shows right to left in the group list.

## Impact

- Platforms: iPhone, iPad and Mac. Apple TV is unchanged.
- Code: `Apps/Shared/Components/Browse/` (the chips go, a group button and a group list row come), `Apps/Shared/Views/Live/` (the sheet, the sidebar search), `Apps/Shared/Views/Guide/GuideCompactScreen.swift`, and a group search in `Packages/AntennaCore` next to `ChannelFilter`.
- Strings: "Groups", "Search groups", "No groups match" and the button's spoken label, in sv, de, es, fr, pt-BR and ar.
- Tests: every iPhone UI test that tapped a chip opens the sheet first. New UI tests open the sheet, search and pick, and scroll and search 200 groups. `AppJourneys` takes its New group shot through the sheet.
- Boards: `iPhone-Live-Groups`, `iPhone-Live-Groups-Search` and `iPad-Live-Groups-Search` are new; every iPhone board that drew the chip row now draws the group button.
- Depends on: `group-management` (order, hidden and locked groups), `session-restore-and-recently-watched` (Recents and the remembered group), `localization`.
