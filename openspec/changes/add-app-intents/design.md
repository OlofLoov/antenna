# Design

## Context

Boards: none, no UI. Each action either opens a screen another change owns (`add-live-tv-on-iphone-ipad-mac`, `add-movies-and-series-browsing`, `add-search`) or answers with a spoken or written reply from Siri or Shortcuts.

Design-system requirements that apply: "Nothing fake and nothing bundled", "Nothing shows before the paywall".

## Goals / Non-Goals

**Goals:**
- Matching, references and reply text live in AntennaCore and are testable without the AppIntents framework.
- References saved in Shortcuts keep resolving across every app update.

**Non-Goals:**
- Spotlight indexing, which needs its own change and probably a cached catalogue.
- Acting on the last channel after the app stopped. Toggle Favorite acts only on a channel playing in this process.

## Decisions

- References: channel `"<sourceID>/<channelID>"` and title `"<sourceID>/<title id of kind vod or series>"`, split at the first "/". Once shipped, parsing keeps accepting every format ever shipped. AntennaCore adds `LastChannelKey.string` and `init?(parsing:)`, `TitleReference`, `Catalogue.channel(for:)` (exactly one channel with that source and id, else nil) and `channels(matching:limit:)`, with no AppIntents import, since AntennaCore imports Foundation only.
- Intent code lives in `Apps/Shared/Intents/` under `#if !os(tvOS)`, excluded from AntennaTV in `project.yml`, with a `check-rules.sh` grep for `AppIntent`, `AppEntity`, `AppEnum` and `AppShortcutsProvider`. A build check fails if the actions reach the tvOS target.
- The M3U parser stops putting the stream link into channel ids, because Shortcuts stores those ids and syncs them through iCloud.
- Matching: names use search's folding and bands with group-only matches excluded. Digits-only queries prefix-match numbers, ordered by number, then source, then position. Leading zeros in a number query are ignored. Benchmark: 50 000 channels under 50 ms on the reference machine, 250 ms on CI.
- `entities(for:)` never throws per id. Unparseable ids are omitted. Unavailable ones carry a failure (source gone, channel gone, title gone, credential missing, offline, still loading, source failed) that `perform` throws before any foreground request. Background loads fetch only the referenced source for id lookups, with a 10-second deadline from the query, never cancelled. Two requests at once share one library load.
- Modes: Tune and Play run in the background, then `.foreground(.dynamic)` with `continueInForeground(nil, alwaysConfirm: false)`, throwing `needsToContinueInForegroundError` when refused. Search is `.foreground(.immediate)`. Toggle Favorite is background only, with `mode` toggle, add or remove, returning the new state. Every `perform` is `@MainActor` and goes through an injectable `IntentCatalogueProvider`.
- Entitlement is read from the locally cached entitlement state without waiting on StoreKit. Keychain `errSecInteractionNotAllowed` before first unlock: Tune resolves and loads after coming forward; Toggle Favorite throws `needsUnlock` ("Unlock your iPhone once and try again", iPad or Mac by platform). `errSecDecode` reads as source failed.
- Reply wording, verbatim: "You're offline. Connect to the internet and try again."; "Antenna is still loading your library. Try again in a moment."; "Antenna couldn't reach <name>. Try again later."; "The login for <name> hasn't synced from iCloud to this device yet."; "That channel's source is no longer in Antenna."; "<name> is no longer in <source>."; "<name> is in a locked group. Unlock it in Antenna first."; "<name> is no longer available from <source>."; "<channel> is already a favorite."; "<channel> isn't a favorite."; "Which channel?". No URL, path, port, HTTP status or error code in any reply or its debug description.
- Siri phrases (five shortcuts): "Tune to / Watch / Put on <channel> in Antenna", "Play <title> in Antenna", "Search Antenna" and "Find a channel in Antenna", "Add this channel to favorites in Antenna" (mode add), "Remove this channel from favorites in Antenna" (mode remove). Shortcut parameters refresh after each catalogue rebuild and each favorites change.
- Entity display: channel subtitle "<number> · <group> · <source>", logo only from `https`; title subtitle "Movie · <source>" or "Series · <source>" with the poster, no extra network call per entity.
- Nothing is logged that contains an entity id or intent parameter. Favorites go through `FavoriteRecord`, new ones at the highest sort order plus one; removal deletes every duplicate.
- Caps: 200 suggested channels, 50 suggested titles, 20 matches per query. Movies and series browsing treats a play by title reference like a play from a search result. Group management's lock and hide checks return false until it lands.

## Risks / Trade-offs

- Open question: should a locked channel fail with a reply, so it never comes on screen from the lock screen, rather than open the app on group management's unlock prompt? Changes the unreachable-item requirement. Answer before the change is accepted.
- Open question: should hidden channels stay reachable from a saved shortcut while left out of suggestions, on the reading that hiding is about clutter? Changes the suggestions requirement. Answer before the change is accepted, against group management.
- Open question: should Open Search fail when not unlocked or without sources, rather than open the app on the paywall or setup? Changes the unlocked-and-set-up requirement. Answer before the change is accepted.
- Open question: should Tune Channel on iPhone go full screen rather than play inline? Would change the tune requirement.
- Open question: Toggle Favorite acting on the last channel instead would make it work after the app stopped, and would change the favorite requirement.
- Open question: a number-only query finds numbers, not names, so "24" does not find "Channel 24" numbered 7. Making names follow would change the name-or-number requirement.
- Open question: Spotlight, favorites and My list only, or nothing until a cached catalogue exists? Needs its own change.
- [200 suggested channels and 50 titles may be too few for Siri] → can be settled during implementation.
- [The 10-second background deadline is a guess] → can be settled during implementation.
- [Logos show only for `https` links, so `http` logos drop out of Shortcuts] → can be settled during implementation.
- [Stored reference formats cannot change once shipped] → a follow-up decision freezes them, and parsing accepts every format ever shipped.
