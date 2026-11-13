# Design

## Context

`LiveChannelList` shows `Browse.EmptyGroup` with "No favorites yet. Tap the star on a channel to add it." when Favorites is open, empty and unfiltered. The star left the rows when favorites moved to the row menu and the swipe (`favorites/favorite-from-a-channel-s-menu`, `favorites/swipe-a-channel-into-favorites`). The full-screen controls on iPhone still have a star, but only for the playing channel.

## Boards

- `iPhone-EmptyFavorites.dc.html`: the text changes to the iPhone wording. Layout, type and color stay.
- `Main-FavoritesEmpty.dc.html` (Apple TV) is unchanged.
- No iPad or Mac board draws empty Favorites. They use the same `Browse.EmptyGroup` as iPhone, with the wording below.

Design-system requirements followed: the existing empty-state component, no new type or color.

## Decisions

### Wording per platform

`Browse.EmptyGroup.noFavorites` holds the text, chosen at compile time:
- iOS (iPhone and iPad): "No favorites yet. Touch and hold a channel, or swipe it right, to add it." Both gestures work on both devices, and "touch and hold" is Apple's term for the menu gesture.
- macOS: "No favorites yet. Right-click a channel to add it." A Mac list has no swipe.

Options considered:
- One sentence for every platform, such as "Open a channel's menu to add it" (rejected): it does not say how to open the menu, which is the part a new user is missing.
- Name the full-screen star (rejected): it only adds the playing channel and is hidden until the controls show.
- A different sentence per platform (chosen), as Apple TV already has its own.

### Where the text lives

A static on `Browse.EmptyGroup`, so the screen and the preview read the same string and the UI test checks the platform's wording.
