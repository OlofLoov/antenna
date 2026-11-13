# Design

## Context

On Apple TV the channel overlay (`add-tv-channel-overlay`) already lists Favorites as its first group, built from the same catalogue as iPhone, iPad and Mac: favorites filtered to the current profile, sorted by their saved order, with channels in locked groups left out. Tuning from Favorites makes it the group channel up and down and the Guide follow (`add-tv-guide-grid`, "One row per channel in the current group"). The only way to change a favorite on a TV is the star in the overlay's panel, which `ShellView.toggleFavorite` handles with `FavoriteRecord.toggle` and a focus move when the removed row was in Favorites.

Most of the parity with iPhone is already in the code. What is missing is the held-select menu that matches the touch-and-hold menu on the other platforms, the spec saying Apple TV shows favorites, and an empty Favorites line that names the faster way.

Boards:
- `Main.dc.html` and `Main-Favorites.dc.html` (overlay with a group and with Favorites shown): a note on the channel column for the held-select menu.
- `Main-FavoritesEmpty.dc.html`: the empty line now reads "No favorites yet. Hold select on a channel to add it."
- `TV-Guide.dc.html`: a note on the grid for the menu.

Design-system requirements followed: "Accessibility identifiers follow the board", "Visual changes update the boards in the same change", "Live video keeps playing under overlays" (the menu opens over the overlay or the Guide, and the picture carries on), "Focus is the lifted white card" (the system menu keeps its own focus look).

Not drawn: the menu is the system context menu, so the boards carry a note, as `add-favorite-from-channel-rows` did on iPhone and iPad.

## Goals / Non-Goals

**Goals:**
- A TV user can add or remove a favorite from any channel row in the overlay, or from the Guide, without moving to the panel.
- The favorites spec describes what Apple TV does.

**Non-Goals:**
- A Favorites tab on Apple TV. The tab bar is Live, Guide, Movies, Series and Search (`tvos-shell`, "The tabs, in order"), and Live is the overlay, which lists Favorites.
- A group filter in the Apple TV Guide.

## Decisions

- **Favorites group on TV: keep what the overlay does.** Options: (a) a new Favorites tab, (b) hide the group when empty, (c) keep the group always listed with an empty line. The overlay boards draw (c) (`Main-FavoritesEmpty`), iPhone's group chip also stays when empty, and a group that appears and disappears moves `overlay.group.<index>` and the user's muscle memory. Chosen: (c). The empty line changes to name the held-select menu, which is now the quickest way, while the star still works.
- **Held select opens a context menu.** Options: (a) SwiftUI `contextMenu` on the row's button, (b) a custom long-press gesture that toggles at once, (c) nothing, as `add-favorite-from-channel-rows` decided. tvOS opens `contextMenu` on a held select on a focused button, which is how Apple's own tvOS apps offer actions on an item, and a short press still runs the button. A gesture that toggles at once has no confirmation and no wording, and the picture's own long press (info panel) already uses (b) for a different job. Chosen: (a). The decision in `add-favorite-from-channel-rows` to leave the TV out was about the boards having no menu, which this change adds.
- **One menu item, same wording.** `Browse.FavoriteMenuButton` ("Add to Favorites" / "Remove from Favorites", `star` / `star.slash`) already compiles on every platform. The overlay and the Guide reuse it, so the TV menu reads the same as the iPhone menu. The panel star keeps its sentence-case label "Add to favorites", which `ChannelOverlayUITests` reads.
- **Overlay rows use the shell's toggle.** The menu calls the overlay's existing `toggleFavorite(channel, key)`, so removing a row while Favorites is shown moves focus to a neighbor, the same rule as the star. The overlay inside multi-view's picker gets the menu too, because it is the same view.
- **The Guide gets its own toggle closure.** The overlay's toggle moves focus into the overlay when the overlay model's group is Favorites, which is wrong while the overlay is closed and the Guide has focus. `GuideScreen` takes `toggleFavorite: (Channel) -> Void`, which `ShellView` builds from `FavoriteRecord.toggle` with the current profile and no focus move. The Guide's highlight stays on its row index, clamped by `GuideModel.highlightedRow`; when the last row leaves Favorites, focus moves to the day chips the way an empty group opens.
- **The Guide menu is on the grid holder.** The grid is one focusable button that the model steers (`add-tv-guide-grid` design), so the menu attaches to it and reads the highlighted cell's channel each time the body renders. With no highlighted channel the menu is empty and tvOS does not open it.
- **VoiceOver.** A `contextMenu` on tvOS is not offered as a VoiceOver action, so the overlay rows and the Guide holder add an `accessibilityAction(named:)` with the same title, as the Guide cells on iPhone do.
- **Changing another active change.** `add-tv-channel-overlay` removes "Apple TV shows no favorites". That removal moves here, and its favorites delta file is deleted, so whichever change archives second does not fail on a missing requirement. Its design's empty-Favorites line is updated to the new wording.

Identifiers:

| Identifier | Where |
|------------|-------|
| `overlay.menu.favorite` | Held-select menu item on an overlay channel row |
| `guide.menu.favorite` | Held-select menu item on the Apple TV Guide grid, the same identifier the iPhone Guide uses |

## Risks / Trade-offs

- A user who holds select out of habit to tune now sees a menu. Menu closes it and nothing changes; a short press still tunes.
- The menu shows the state when it opened. A sync that lands while it is open makes the item stale, and choosing it then toggles from the current state, as on iPhone.
- XCUITest drives a held select with `XCUIRemote.press(.select, forDuration:)`; if the simulator's menu timing is flaky, the UI test may need a longer hold.
