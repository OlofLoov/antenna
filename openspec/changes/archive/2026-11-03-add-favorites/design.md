## Context

No board; the tab predates the design boards. No design-system requirement applies. Follows decision adr-0002 (SwiftData with private CloudKit for sync). Runs on iOS, iPadOS, macOS and tvOS. On tvOS the rows are plain text and not focusable, so a list longer than the screen cannot be scrolled.

## Goals / Non-Goals

**Goals:**
- A synced list of favorites with a stable order.

**Non-Goals:**
- Any way to add, remove or reorder a favorite.

## Decisions

- `FavoriteRecord` follows decision adr-0002: every stored property optional or defaulted, no unique attributes, so duplicates are possible and listed twice.
- UI tests find the screen by `favorites.emptyState` and `favorites.list`. Debug builds launched with `-ui-testing-favorites <sortOrders>` start on an in-memory store holding one favorite per listed sort order, with channel id `channel-<n>`. Nothing reaches iCloud.
- The UI tests run on an iPhone simulator and open the tab by its "Favorites" label, an exception to the identifier rule until the shell gives the tab bar identifiers.
- Sync between devices is a manual two-device check; CloudKit cannot run in CI.

## Risks / Trade-offs

- Favorites for M3U entries without `tvg-id` break when the playlist order changes, because those ids are positional.
- Two M3U entries with the same `tvg-id` and URL share an id, so a favorite for either is ambiguous.
- Open question: which screens get the add and remove action, the channel row's context menu, the player overlay, or both?
- Open question: should a favorite keep a snapshot of the display name so it renders before its source has loaded?
- Open question: how should favorites for positional M3U ids become durable, by storing the stream URL as well or by requiring `tvg-id`?
