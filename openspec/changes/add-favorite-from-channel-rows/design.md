# Design

## Context

Favorites are written today by the star on the now-playing line (iPhone) and in the details panel (iPad, Mac), by the Apple TV overlay's favorite button, and by the Shortcuts action. All of them call `FavoriteRecord.toggle`, which adds a favorite after the last one or removes every record in the channel's removal set (`channel-catalogue`). This change adds three more entry points on iPhone, iPad and Mac and calls the same toggle.

Boards:
- `iPhone.dc.html` and `iPad.dc.html` (Live list): a note on the channel list for the menu and the swipe.
- `iPhone-Guide.dc.html` and `iPad-Guide.dc.html` (Guide channel column): a note for the menu.
- `iPhone-FullScreen.dc.html`: the star after the LIVE badge.

Design-system requirements followed: "Accessibility identifiers follow the board", "Targets are large enough to hit" (the star is a 44 pt target like its neighbors), "One accent color" (filled star and swipe tint use the accent), "Visual changes update the boards in the same change".

Not drawn: the menus and the swipe button are system controls, so the boards carry a note, not a drawing. The filled star in full screen uses the same glyph and accent as the now-playing star on `iPhone.dc.html`.

## Goals / Non-Goals

**Goals:**
- A user who touches and holds, right-clicks or swipes a channel finds the favorite action without playing it first.
- Favorites can change while the picture is full screen.

**Non-Goals:**
- Apple TV. `TV-ZapBar-Favorites.dc.html` and the overlay (`add-tv-channel-overlay`) already add and remove favorites; the boards draw no long-press menu on a TV, so nothing is added there.
- New wording for the empty Favorites group. Its text is a scenario in `add-live-tv-on-iphone-ipad-mac`.

## Decisions

- **One toggle.** Every new entry point calls `FavoriteRecord.toggle(channel, in: live.catalogue, profile:, context:)`. No new stored data, no schema change, no migration.
- **Menu wording.** "Add to Favorites" and "Remove from Favorites", with `star` and `star.slash`, in title case like system menu items. The existing star button keeps its sentence-case VoiceOver label "Add to favorites"; changing it would break `LiveUITests` and is not what the user asked for.
- **One menu per row.** The Mac Live row already had a `contextMenu` with the multi-view item. SwiftUI shows only one context menu per view, so the row gets a single `LiveFavoriteMenu` modifier that lists the favorite item first and takes the multi-view item as trailing content. `liveMultiViewMenu` goes away.
- **Swipe from the leading edge.** Trailing swipes are the system's delete gesture, and removing a favorite is not deleting a channel. Leading, full swipe allowed, tinted with the accent. iOS only, because a Mac List has no swipe actions. The Guide has no swipe: its rows scroll sideways on iPhone and form a grid on iPad and Mac, where a sideways swipe already scrolls.
- **VoiceOver.** SwiftUI offers a List row's swipe actions as VoiceOver custom actions, so the iPhone and iPad Live rows get the action that way. The Mac Live rows and the Guide's channel cells add a named `accessibilityAction` instead, where there is no swipe to provide one.
- **Full-screen star.** A new component, `Browse.PlayerFavoriteButton`, drawn like the other strip buttons (plain glyph, 44 pt target, accent when on). `LivePicture` adds it as the first of the strip's extras only while `live.fullScreen` is true; outside full screen the now-playing line or details panel already shows a star, and two stars on screen would read as two different things.
- **Components stay pure.** `Browse.FavoriteMenuButton` and `Browse.PlayerFavoriteButton` take `isFavorite` and a closure. The modifiers that read `LiveModel`, the model context and the profile live in `Views/Live`.
- **Changing another active change.** `add-tv-channel-overlay` modifies "Favorites list is read-only" to scope it to iPhone, iPad and Mac. This change removes that requirement, so the MODIFIED block is dropped from that change's delta; otherwise archiving it later would fail on a missing requirement.

Identifiers:

| Identifier | Where |
|------------|-------|
| `browse.menu.favorite` | Live row context-menu item |
| `browse.swipe.favorite` | Live row leading swipe button (iPhone, iPad) |
| `guide.menu.favorite` | Guide channel cell context-menu item |
| `browse.player.favorite` | Star in the full-screen player controls |

## Risks / Trade-offs

- A full leading swipe on a Favorites row removes it at once. The trailing-delete convention makes this less surprising than a trailing swipe would, and the menu or a second swipe adds it back.
- The menu shows the state when it opened. A sync from another device while the menu is open can make the item stale; choosing it then toggles from the current state, which matches what the star does.
