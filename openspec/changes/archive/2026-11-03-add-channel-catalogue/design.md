## Context

No board and no UI. The screens that render the catalogue cite it: `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-tv-guide-grid`, `add-live-tv-on-iphone-ipad-mac`, `add-search` and `tvos-shell`. Design-system requirement that applies: "Channels without a logo show initials". Follows decision adr-0002 (SwiftData with private CloudKit for sync), decision adr-0003 (credentials in iCloud Keychain) and decision adr-0005 (AntennaCore is UI-free).

## Goals / Non-Goals

**Goals:**
- Every screen on every platform shows the same groups, numbers and favorites.
- Deterministic output for identical input.

**Non-Goals:**
- Touching SwiftData; the catalogue is generic over a record token.

## Decisions

- Binding interface:

  ```swift
  extension Channel {
      static func tagged(_ channels: [Channel], sourceID: UUID) -> [Channel]
      static func initials(for name: String) -> String
  }
  struct RowKey: Hashable, Sendable { let sourceID: UUID; let id: String; let position: Int; init?(_ channel: Channel) }
  struct Catalogue<Token: Hashable & Sendable> {
      init(channels: [Channel], groupOrder: [UUID: [String]], favorites: [FavoriteSnapshot<Token>])
      var groups: [CatalogueGroup]
      func count(of:) ; func rows(in:) ; func channel(for:) ; func number(for:)
      func sourceGroup(of:) ; func position(of:in:) ; func match(digits:)
      func isFavorite(_:) ; func favoritesToRemove(for:) ; func addFavorite(_:)
      var unresolvedFavorites: [FavoriteSnapshot<Token>]
      func replacingFavorites(_:) -> Catalogue
  }
  ```

- `CatalogueGroup` is `.favorites`, `.all`, `.named(sourceID, name)` or `.ungrouped(sourceID)`; the UI supplies labels.
- `FavoriteSnapshot<Token>` holds `channelID`, `sourceID`, `sortOrder` and `recordToken: Token?`. The app uses `PersistentIdentifier` as the token; tests use `Int`.
- `position` is 0-based and separate from the M3U parser's 1-based fallback index.
- Source order is first appearance of `sourceID` in the input; the caller concatenates per-source lists in source sort order.
- `groupOrder` maps a source id to its provider category order (`get_live_categories` for Xtream).
- `RowKey`, `FavoriteSnapshot` and `Channel` are never logged or put in error messages, and `RowKey` is never persisted while `Channel.id` embeds the stream URL (decision adr-0003).
- Benchmarks (build under 200 ms, favorite replacement under 20 ms) run only with `ANTENNA_BENCHMARKS=1`.
- Split during review: number fallback into two base cases, sorting into in-group and All channels, the favorite rules into rows, removal set and predicate, and row keys into distinctness and determinism.

## Risks / Trade-offs

- A favorite with no source resolves to the first copy but matches every copy, so a channel can show the favorite badge while another copy holds the Favorites row.
- A source whose credential is missing adds no channels and no groups; the catalogue has no notion of a hidden source.
- Open question: should fallback numbers freeze once shown during a partial load, at the cost of a second numbering pass?
- Open question: favorites are bound to a source id, and sources cannot be edited, so deleting and re-adding a playlist orphans every favorite. Should a favorite whose source matches no loaded source fall back to matching by channel id alone? That needs the set of known source ids passed in.
