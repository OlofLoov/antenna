# Design

## Context

`M3UParser` builds a channel id as `<tvg-id>#<link>`, or `m3u#<link>#<position>` when the entry has no `tvg-id`. The id is what every saved reference to a channel stores: `FavoriteRecord.channelID` and `GroupMemberRecord.channelID` in the synced store, and `LastChannelKey` for Recents, the last channel and language picks in `UserDefaults`. An `xc`-style link is `/live/<user>/<pass>/<id>.ts`, so the id carries the login.

The other changes worked around it by refusing ids that contain `://`: `LastChannelKey.canStore` (Recents, last channel), `GroupRules.canSave` (own groups) and `ChannelLanguageStore.key(for:)` (language picks). Favorites never refused, so favorites of M3U channels already hold links, and with them logins, in iCloud.

Local file import (`add-local-m3u-file-import`) solved the file case: logins move to a per-source Keychain item, the synced text holds `{antenna.<token>.user.N}` placeholders, and `PlaylistImport.playlist(stored:restored:)` takes ids from the stored text and links from the restored text. File ids hold no login, but they still hold the link with its placeholders, and they change when the provider moves server.

No screen changes, so there is no board.

## Goals / Non-Goals

**Goals:**
- No M3U channel id holds a link, a host or a login, for link and file sources alike.
- Ids that survive what providers change most: passwords, servers, tokens in links, entry order.
- Every favorite and own-group channel saved with an old id keeps working, on every device, with one rewrite.
- The `://` refusals stop applying to M3U channels without per-feature work.

**Non-Goals:**
- Ids for Xtream, Stalker, Jellyfin or Channels DVR. None of them holds a link.
- Following a channel the provider renames.
- Scrubbing favorites of a source that was deleted before this version ran.

## Decisions

### What an M3U id is made of

Options considered:

1. **Guide id, name and group, with an ordinal for repeats.** Nothing from the link. Survives a new password, a new server, rotating tokens and reordering. Changes when the provider renames a channel or moves it to another group. Entries that share all three (a main and a backup stream) are told apart by their order among those entries only.
2. **The link with its logins stripped, as file import does, or a hash of it.** Survives a new password. Breaks on a server move or a token that changes per refresh, which many panels add to the query. A login in a form the stripper does not know (a token in the path, a custom query key) stays in the id, or in the hash input.
3. **A random id per entry, remembered in a lookup table.** Survives anything the table can match, but the table needs a key to match on, which brings back option 1 or 2, plus a new synced record.
4. **`tvg-id` alone.** Many playlists give the HD, SD and backup variants one `tvg-id`, so ids would collide.

Option 1 won. The things that change it are things the user sees change too, while option 2 breaks on changes the user never sees.

### The id's form

`m3u.<hash>` for the first entry with a given guide id, name and group, and `m3u.<hash>.<n>` for the n-th (n from 2). `<hash>` is 16 lowercase hex digits of 64-bit FNV-1a over the three fields, each written as `-` when absent or `=` followed by its text when present, joined by U+001F. Absent and empty stay different, as the parser keeps them different (an empty `group-title` is its own group).

- Hashed rather than readable, because some playlists put the link in the title or `tvg-name`, and a readable id would copy it. The hash protects nothing; in the usual case its input is public text.
- FNV-1a rather than SHA-256 (`Digest` has one), because the 50 000-entry parse budget is for a debug build, and pure-Swift SHA-256 per entry would use most of it. A 64-bit collision inside one playlist is unlikely, and if it happens the ordinal still keeps ids unique.
- The ordinal counts only entries with the same three fields, so inserting another channel does not shift it.
- The name is the parsed name: `tvg-name` when present and not empty, else the title.

### Old ids and the rewrite

`Playlist` gains `formerIDs: [String: String]`, earlier id to new id, filled by `M3UParser` while it parses: `<tvg-id>#<link>` or `m3u#<link>#<position>`, exactly as before. When two entries had one earlier id, it maps to the first. `Playlist` is not `Codable`, and the map is never logged or stored. For file sources, `PlaylistImport.playlist(stored:restored:)` takes both ids and `formerIDs` from the stored text, because that is the text earlier versions built file ids from.

The app rewrites after each successful load in `SourceRefresher.load`, which both Live on iPhone, iPad and Mac and the Apple TV shell use. A new dependency, `migrateIDs`, gets the source id and the map; `AntennaApp` sets it to `ChannelIDMigration.apply(_:source:in:)` on the main context. It:

- picks the `FavoriteRecord`s whose `channelID` contains `://` and whose `sourceID` is the source or nil, and the `GroupMemberRecord`s of the source whose `channelID` contains `://`;
- rewrites each one that the map names, keeping sort order, profile and group;
- deletes it instead when a record for the new id already exists with the same profile and source (favorites) or the same group (members), so a channel is not listed twice;
- saves once, and does nothing when no record matches.

A rewritten id has no `://`, so the second load and every other device find nothing to do. Two devices rewriting the same record write the same value, so CloudKit's merge is harmless. A favorite saved twice ends up once by the delete rule, or, if both copies sync in before either device sees the other, by the catalogue's existing one-row-per-channel rule.

Options considered for the rewrite: a pass at launch (it cannot run without the playlist, which only a load provides); matching both id forms in the catalogue for good (the login would stay in iCloud); rewriting on load (chosen).

### What needs no rewrite

- Recents, the restored session and the last channel: `LastChannelKey` has refused `://` ids since before Recents existed, and so did the old `LastChannelStore`. The session stores a group, never a channel.
- Language picks: `ChannelLanguageStore` refused `://` ids.
- Reminders: `ReminderRecord` keys on the guide id and holds no channel id.
- Own-group members: `GroupRules.canSave` refused `://` ids, so none should exist. The rewrite covers them anyway, since it costs one more fetch.

### The `://` guards stay

`LastChannelKey.canStore`, `GroupRules.canSave` and `ChannelLanguageStore.key(for:)` keep refusing ids that contain `://`. New M3U ids never do, so M3U channels pass. The guard still keeps a stored value from holding a link if a future source puts one in an id, and it rejects stored values written by earlier versions.

## Risks / Trade-offs

- [A renamed channel or one moved to another group gets a new id] → its favorite shows as missing, as it did before when the link changed. The rename is visible to the user, unlike a password change.
- [A device still on an earlier version sees rewritten favorites it cannot match] → they show as missing there until it updates. Nothing is deleted.
- [A favorite of a deleted source keeps its link and login] → nothing can map it. The source-deletion rule already keeps such favorites; removing them needs a decision on deleting user data.
- [A favorite whose channel was gone before the update keeps its old id] → the rewrite only maps channels in the playlist. When the channel returns, the next load rewrites it.
- [Backup streams swap order in the playlist] → their ordinals swap and a favorite moves to the other stream of the same channel, with the same name and group.

## Implementation decisions

- When a rewritten record duplicates one already saved with the new id, the one already saved stays, with its sort order. In an own group that can leave a gap in the sort orders, which the group list ignores.
- Only loads through `SourceRefresher` rewrite. The scripted loader of the `-ui-testing-live` launches and unit tests that build a Live model without a refresher do not.
- The screenshot seed (`UITestingScreenshots.favoriteIDs`) named favorites by `tvg-id`, which never matched an M3U id, so its Favorites row was always empty. It now takes the ids from the parsed playlist.
- `RowKey`'s doc comment no longer says the id can hold a link. `FavoriteSnapshot`'s still does, because a favorite not rewritten yet can.
- Spec conflict: change `add-profiles` modifies the same `tvos-shell` requirement, "Back to the last channel on launch", and keeps the scenario that an M3U channel is not remembered. Whichever change archives second has to merge the two blocks: the profile wording from `add-profiles`, the M3U scenarios from this change.
- The 50 000-entry benchmark went from 1.3 s to about 2 s in a debug build on this Mac. A first version that built the hash input as a string took 5.6 s under load, so the hash now reads the three fields' bytes directly and keeps repeat counts by hash value.
- Groups 1 and 2 ship in one pull request, as separate commits. The id change alone would leave every M3U favorite unmatched on main until the rewrite landed.
