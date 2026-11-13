# Design

## Context

The Apple TV overlay (`ChannelOverlayView`, board `Main`) has a lazy group column and a lazy channel column, each a focus section. `ShellScreen.focusMoved` steers focus between them after the fact:

- Left from a channel, the focus engine picks the group at the same height, and `focusMoved` then sets focus to the shown group. When the shown group is off screen, the lazy column has not built its row, the assignment finds nothing, and focus stays on the wrong group. The next `focusMoved` call then shows that group. The overlay opens on the group last tuned from with focus in the channels, and the group column opens at its top, so with hundreds of groups the shown group is usually off screen.
- Right from a group, focus first lands on whichever row is level with it, then jumps to the entry row.
- Moving onto a group swaps the channel column's rows inside the same scroll view, which keeps the previous group's offset for a frame before `onChange(of: model.group)` scrolls to the entry row.
- Every row's logo is an `AsyncImage`, which starts empty for each new row, so all logos go back to initials on every group move and decode again at full size.

`ShellScreen` owns the `@FocusState`, so every focus move evaluates its body and the overlay's. The overlay rebuilt the channel column each time, and a `ForEach` collects the id of every row it lists, so a move in All channels walked every row of the catalogue. `ShellScreen` also rebuilt the catalogue from scratch when a favorite changed; the new `LiveBrowsingPerformanceTests` time that at 350 ms for 50 000 channels in a debug build on an M-series Mac, where swapping the favorites takes 2 ms.

The catalogue queries themselves are cheap. The same tests time one group move, every group's count plus the shown group's rows, at about 1.2 ms in a debug build with 380 groups. `Catalogue.groups` was worked out again on every call and `CataloguePolicy.isLocked` built a set of locks per call; both are now stored once per catalogue.

No screen changes, so no board is redrawn. The overlay keeps `Main` and the design-system requirements it already follows (`design-system/focus-is-the-lifted-white-card`, `design-system/channels-without-a-logo-show-initials`).

## Decisions

### Where focus lands between the columns

Each column declares where focus enters it with `defaultFocus(_:_:priority: .userInitiated)`, which applies when focus moves into a focus section from outside, including swipes. The group column's target is the shown group. The channel column's target is `ChannelOverlayModel.target`: the row last highlighted in the shown group's list, else the entry row (`entry`, the playing channel or the first row). `show` clears the highlight when the group changes, because the new group's list opens fresh at its entry row and a row from an earlier visit may not exist in it yet. So right from a group just moved onto lands on the entry row, and left then right again comes back to the row the user left, which is still on screen. The entry row cannot be the target in that second case: thirty rows down, the lazy list has not built it, and focus would land on whatever row is level with the group. The panel describes the highlighted row, so after a move to another group it stays empty until a row there is highlighted, as it already did for a group without the old row. The group column sits in a `ScrollViewReader` and scrolls the shown group to its middle when the overlay opens, and when the shown group changes while focus is elsewhere, so the target row exists. The `focusMoved` redirects stay as a fallback. The multi-view tile picker shows the same overlay and gets the same targets.

Options considered:
- Keep the redirects and make the group column a plain `VStack` so every row exists (rejected): hundreds of group rows built on every open, and focus still shows on the wrong group for a frame.
- Remember the last focused row per section with UIKit's `remembersLastFocusedIndexPath` (rejected): needs a UIKit collection view in place of the SwiftUI columns.
- `defaultFocus` with user-initiated priority plus a scrolled group column (chosen).

### One list per group

The channel column is `OverlayChannelList`, given `.id(model.group)`, so each group gets its own scroll view that opens at its entry row. The previous group's offset is never drawn.

`OverlayChannelList` is `Equatable` on the catalogue's new `revision`, the group and the entry row, and is drawn with `.equatable()`, so a focus move elsewhere in the overlay skips its body. The guide's rows redraw through observation of the guide store as before. In the multi-view picker the list always redraws, since its tile badges come from a closure.

`Catalogue.revision` is a `UUID` made by every build and every `replacing…` call. Comparing catalogues field by field would walk every row, and the type has no `Equatable` conformance to keep honest.

### Logos

`LogoCache` (in `Persistence/`, next to `PosterCache`) downloads a logo once through `URLSession.shared`, decodes it with ImageIO as a thumbnail at most 280 pixels on its longest side on a detached task, and keeps it in an `NSCache` of up to 20 MB. Rows asking for one address while it loads share the download. A failure is remembered for five minutes, so a dead link is not fetched again for every row it appears in. The download still goes through `URLCache.shared`, which the Top Shelf reads.

`LogoImage` is the component that replaces `AsyncImage` for channel logos on every platform: the overlay rows and panel, the Apple TV guide, the zap bar, the player panel, `Browse.Logo` on iPhone, iPad and Mac, and the iPhone, iPad and Mac guides. It reads the cache synchronously, so a logo seen once draws in a row's first frame. The loader comes from the `logoLoader` environment value, which `ShelfSync` sets for both shells, as it sets `posterLoader`. Previews leave it out and show initials, so they stay deterministic. The Guide sources screen keeps its `AsyncImage`; it shows one logo per row in Settings and is not a channel list.

Options considered:
- Keep `AsyncImage` and lean on `URLCache` (rejected): it still starts every new row empty and decodes at full size on each appearance.
- A disk cache like `PosterCache` (rejected for now): `URLCache` already keeps the bytes; the decode was the cost.

### Favorites on Apple TV

`ShellScreen` swaps the favorites into the existing catalogue with `replacingFavorites(_:)` when only the favorites changed, as `LiveModel` already does on iPhone, iPad and Mac. `ShellModel.rebuildChannels` leaves `channels` alone when a reload brings the same list, so a background refresh with no change redraws nothing.

### The rest

- The iPhone chips row (`Browse.Chips`, used by Live and the Guide) is a `LazyHStack`, so hundreds of chips are not laid out on every group change.
- Catalogue builds in `Catalogue.shell` and `LiveModel.rebuild`, and logo downloads, are signpost intervals under the "browse" category (`BrowseSignposts`), so a stall on a device can be timed in Instruments before deciding whether the build should move off the main actor.

### Testing

`LiveBrowsingPerformanceTests` in AntennaCore run in CI with loose budgets: one group move under 8 ms, the guide for the rows on screen under 5 ms, and a favorite under a tenth of a full build, all over 50 000 channels in 400 groups with group rules and a seven-day guide. The budgets leave room for a slow runner and still fail a query that walks the whole catalogue.

`-ui-testing-large-catalogue`, Debug only, adds 20 000 channels in 300 groups to Home playlist. `ChannelOverlayLargeUITests` checks that left from a1 lands on Ungrouped at the bottom of the group column, that left from thirty rows down a group's list lands on that group with its list, that right again comes back to the row left, and that another group's list opens at its first channel.

## Platforms

Focus and the overlay list are Apple TV only; iPhone, iPad and Mac pick a group with a tap or a click and have no focus columns. Logos and the chips row reach iPhone, iPad and Mac. The Apple TV guide grid has one group and draws seven rows, so it gains only the logo cache.
