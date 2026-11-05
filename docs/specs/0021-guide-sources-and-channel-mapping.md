# 0021. Guide sources per playlist and manual channel-to-guide mapping

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Blocked on: a new ADR for how a source's guide settings are stored and synced (one record per source is assumed here; a different shape reopens this spec).
- Builds on specs: 0004, 0006, 0007, 0009, 0010, 0012, 0013, 0014, 0015, 0023
- Needs from other specs: 0001 (the follow-up that takes the stream link out of M3U channel ids; until it ships, AC-17, AC-11, AC-12 and AC-13e cannot save a hand-picked match for an M3U channel, because the saved id would carry the provider login).
- Supersedes: 0014's rule for which guide links a source downloads.
- Amends on acceptance: 0014 (progress, failures and channel lookup per guide), 0023 (a Guide row in each playlist's details)
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-24, US-7

## Summary

For viewers whose guide shows "No programme information" on channels that should have one. Once this ships, each playlist can use several guide files (the XMLTV files that list programmes per channel), in an order the user picks, and the user can add a guide link, turn one off or remove it. For any channel without a guide, Antenna says why in plain words and lets the user pick the right entry from the guide by hand; that choice syncs to their other devices. It does not match channels by name automatically, borrow a guide from a different playlist, or merge two guides' programmes for the same channel.

## Design

Boards: `docs/design/boards/iPad-GuideSources.dc.html` (iPadOS, macOS), `iPhone-GuideSources.dc.html` and `iPhone-GuideSources-Diagnosis.dc.html` (iOS), `TV-GuideSources.dc.html` (tvOS). Reused from other screens: `TV-Onboard-3-M3U.dc.html` and `iPhone-Onboard-2-M3U.dc.html` (the add-link form), `iPad-Search-Capped.dc.html` (the "Showing 200 of n" row), `iPad-Focus.dc.html` (keyboard focus ring).
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-8, DR-11, DR-12, DR-13, DR-15.
Not drawn: the empty channel list ("every channel has a guide"); waiting for the guide; channels not loaded; the add-link form on each platform; guide actions on iPad, Mac and Apple TV, and swipe actions on iPhone; the search with no result or no guide; the search cap row; the offline, turned-off, waiting-for-login and reading status lines; the Re-enter link action; every reason card other than "Guide id not in the guide"; the "Guide from" card with Remove match; the collapsed list with "Show n channels"; drag handles and the context menu.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Missing guide data is the most common support topic for IPTV players, and users blame the app when the grid says "No programme information". Antenna today downloads one guide per playlist and matches a channel only by the exact guide id the playlist gives it (`tvg-id`). A channel with no id, an id spelled differently from the guide's, or a guide that is missing half the channels leaves the user with no way to find out why and no way to fix it short of editing the playlist.

## Scope

In:
- Several guides per playlist: the links the playlist itself names, the guide link saved with the source, the provider's own guide for an Xtream login, and links the user adds.
- A Guide row in each playlist's details in Sources and Settings, showing how many channels have no guide, opens the Guide sources screen.
- The Guide sources screen: the guides with their status, add, reorder, turn off, remove and retry. Guides from the playlist or the provider can only be turned off, not removed; a turned-off guide is not downloaded.
- On a device the login of a guide link cannot reach, the guide's row offers to enter the link again.
- When two guides cover the same channel, the higher one in the list wins.
- A list of the playlist's channels that have no guide, each with a short reason.
- For a selected channel: why it has no guide, and a search over the guide's entries to pick the right one by hand.
- Removing a hand-picked match.
- Syncing guide settings and matches across the user's devices through iCloud.
- Keeping passwords in guide links private.

Out (explicitly):
- Merging programmes for one channel from several guides by time.
- Matching a channel to a guide entry of another playlist.
- Automatic matching by name when the playlist gives no guide id.
- Marking a channel "no guide, stop asking".
- Guide links in onboarding beyond its single guide field (0006).
- The button from "No programme information" in the overlay, guide and browse screens into this screen.
- Where programmes are stored between launches, and how often guides refresh (0014).
- Choosing the language of a guide that names channels in several languages.
- Cleaning up settings left behind by long-deleted playlists.

## User flow

iPad and Mac:
1. Sources & Settings, pick a playlist, then Guide. The middle column shows the guides with their status, Add guide URL, and "Channels without guide" with a count.
2. Selecting a guide shows its actions: Move up, Move down, Turn off, Retry now, Remove. Rows also drag to reorder. Add guide URL asks for one link.
3. Selecting a channel shows why it has no guide and a search field filled in with the channel's name, over matching guide entries.
4. Picking an entry fixes the match. The channel leaves the list and the count drops by one.

iPhone: Settings tab, playlist, Guide. One scrolling screen; tapping a channel opens its reason and the search, and picking an entry returns to the list.

Apple TV: from the settings sheet, playlist, then Guide. The screen slides over the live picture, which keeps playing. The same three columns work with the remote; the search field opens the system keyboard. Menu goes back to the settings sheet.

## Acceptance criteria

Ids keep their numbers from the earlier draft, so some numbers are missing and the order is not numeric.

### AC-1 Every guide a playlist names is used
Given a playlist that names guide links in its header, a guide link saved with the source, or an Xtream login
When its guides load for the first time
Then each of those guides is listed and downloaded once, and a link named twice is used once.

### AC-2 Add a guide link
Given the Guide sources screen for a playlist
When the user enters a guide link and saves it
Then it joins the end of the list and starts downloading.

### AC-3 Choose which guide wins
Given two loaded guides that both have programmes for the same channel
When the user moves the lower one above the other
Then that channel shows the programmes of the guide now on top, within seconds and without downloading anything again.

### AC-4 Turn off or remove a guide
Given several loaded guides for a playlist
When the user turns one off, or removes one they added
Then its programmes leave every screen, and other guides fill the channels they also cover.

### AC-26 One broken guide does not break the others
Given a playlist with two guides, one of which fails (server error, a web page instead of a guide, a corrupt file, or no network)
When the guides load
Then that guide's row says what went wrong, and channels covered by the other guide still show their programmes.

### AC-14 See why a channel has no guide
Given a channel with no current programme
When the user selects it on the Guide sources screen
Then the screen says why in plain words: the playlist is still loading, there is no guide, the login has not synced yet, the device is offline, every guide failed, the playlist gives no guide id, the guide does not list that id, the guide lists it with no programmes, its programmes have run out, or a hand-picked entry has no programmes.

### AC-15 Find the channels without a guide
Given a playlist where some channels have no current programme
When the user opens the Guide sources screen
Then those channels are listed in All channels order with a count and a short reason each, and on iPhone, iPad and Mac a filter narrows it by name or number.

### AC-17 Pick the right guide entry by hand
Given a channel without a guide and at least one loaded guide
When the user searches the guide's entries, starting from the channel's name, and picks one
Then the channel shows that entry's programmes everywhere in the app within seconds, leaves the list of channels without a guide, and its reason changes to "Mapped by you", even when the playlist gives the channel no guide id at all.

### AC-11 Undo a hand-picked match
Given a channel the user matched by hand
When the user removes the match
Then the channel goes back to the playlist's own guide id, and returns to the list of channels without a guide if that id still finds nothing.

### AC-12 Matches survive a playlist refresh
Given channels the user matched by hand
When the playlist refreshes and a channel is renamed or renumbered
Then the match still applies, and a match for a channel that left the playlist applies to nothing and is kept.

### AC-13e Settings follow you to every device
Given the user adds a guide, reorders guides or matches a channel on one device
When their other device, signed into the same iCloud account, receives the change
Then it shows the same guides in the same order and the matched channel's programmes within seconds.

### AC-22 Passwords in guide links stay private
Given the user adds a guide link that contains a username, password or token
When the guide list is shown on any device and the app writes its logs
Then the link appears with those parts hidden, and they are kept only in the Keychain, never in the synced settings or a log.

## Edge cases

- An Xtream provider's own guide starts turned off when the user saved a guide link of their own; the user can turn it on.
- A link that is not a web address, or one already in the list, is refused with a message.
- No channel without a guide: the list says every channel has one.
- Offline: adding, reordering, turning off and matching all work and sync later; a new guide's row says it will retry when the device is back online; the search uses whatever guide this device already holds.
- A provider login or a guide link's password that has not synced to this device: that guide's row says it is waiting for the login, and on Apple TV, where Keychain items do not sync, it offers to enter the link again there.
- A playlist that has not loaded any channels: the guide list still works and the channel list says channels have not loaded.
- Every channel in a huge playlist shares the same reason (the guide is still downloading, say): the screen shows that reason once with a "Show n channels" button instead of a long list.
- Two devices matching different channels at the same moment: both matches are kept when the duplicate settings merge.
- A playlist that reorders the guide links in its header moves which guide sits at each position.
- The playlist is deleted on another device while this screen is open: the screen closes.
- More matches than the synced settings can hold: matches for channels that left the playlist are dropped first, then the user is asked to remove some.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core |
| AC-2 | ui |
| AC-3 | core |
| AC-4 | integration |
| AC-26 | integration |
| AC-14 | core |
| AC-15 | ui |
| AC-17 | ui |
| AC-11 | integration |
| AC-12 | core |
| AC-13e | device |
| AC-22 | integration |

## Open questions

- One synced record per playlist (assumed) or one per match and per added link? The ADR decides; one per playlist can lose a change when two devices edit at once. Can be decided in the plan once the ADR lands.
- Decided: the provider's own guide stays off when the user saved their own guide link, to keep traffic as it is today. The owner can reverse it.
- Should guide links from the playlist header be tracked by link rather than by position, so a reordered header does not shuffle them? Can be decided in the plan.
- The reviewer asked to split multiple guides and hand-matching into two specs. Kept as one because the reasons need per-guide status and the search needs every guide's channel list. The owner can still split before acceptance.

## Notes for the plan

- The previous revision of this spec (git history) holds the agreed texts: guide status lines, each reason's title and body, row labels, empty and waiting states, and the search ranking bands. Use them rather than writing new ones.
- Record (pending ADR, ADR-0002 rules): one guide-settings record per source holding the encoded guide order and on/off flags, added links, matches, and removal tombstones so a merge can tell a removal from an edit the other device never saw. Duplicate records merge per entry by the later timestamp, then are written back as one. Nothing is written until the user changes something; a record that does not decode is treated as empty and left alone.
- Settings per playlist have a size cap; past it, matches for channels no longer in the playlist go first.
- Added links: the username, password, path and query go to the Keychain (ADR-0003), except a plain link with no password or query and a one-segment `.xml`, `.xml.gz` or `.gz` path, which is stored whole. Every link is shown through 0014's `redacted(_:)`; no secret part reaches an identifier, label or log line.
- A channel id is never shown or logged while M3U ids embed the stream URL. Until the 0001 follow-up, M3U channels without `tvg-id` get position-based ids and their matches break on reorder.
- A 0014 revision lands first as its own PR: the guide list per source replaces 0014's single-link resolver; progress and failures are per guide; every lookup of a channel's guide goes through one store function that applies matches; caches are keyed by a hash of the guide reference, never the link text.
- Winning rule: per guide id, the highest enabled guide with at least one programme for it supplies all of that channel's programmes. A guide that lists an id with no programmes does not win it.
- Parse results of every enabled guide are kept for the life of the process so reorder and turn-on need no download; the storage ADR may change this.
- The search reuses 0012's folding and token rules, runs on each keystroke, and offers only entries of the same playlist's guides.
- Deleting a source deletes its guide settings and their Keychain items in the same save. A settings record whose source is missing is ignored, never deleted, because the source may still be syncing.

## Dropped

- Moved to the implementation plan: AC-1a, AC-2c, AC-4b, AC-8, AC-13b, AC-13c, AC-13d, AC-14c, AC-15c, AC-15d, AC-15e, AC-15f, AC-16a, AC-16b, AC-16c, AC-16d, AC-16e, AC-18a, AC-18b, AC-18c, AC-18d, AC-18e, AC-18f, AC-18g, AC-19, AC-20, AC-21, AC-22b, AC-24, AC-25, AC-27, AC-27a, AC-28, AC-29, AC-30, AC-31, AC-32.
- Moved to Edge cases: AC-2a, AC-2b, AC-15a.
- Merged into AC-2: AC-2d.
- Merged into AC-3: AC-6.
- Merged into AC-4: AC-4a, AC-5.
- Merged into AC-11: AC-17a.
- Merged into AC-13e: AC-13a.
- Merged into AC-14: AC-10a, AC-14a.
- Merged into AC-15: AC-14b, AC-15b.
- Merged into AC-17: AC-9, AC-10, AC-10b, AC-16, AC-17b.
- Merged into AC-22: AC-22a.
- Merged into AC-26: AC-7, AC-23.
- AC-27b (sweep settings orphaned for 30 days): out of scope, because it could delete a record whose source is still syncing.
- Split earlier (kept for history): AC-18 into AC-18a, AC-18b, AC-18c and AC-18d.
- Clauses split off earlier (kept for history): AC-2d from AC-2, AC-4a and AC-4b from AC-4, AC-13c and AC-13d from AC-13b, AC-13e from AC-13a, AC-14a, AC-14b and AC-14c from AC-14, AC-15b and AC-15c from AC-15, AC-16d and AC-16e from AC-16, AC-17b from AC-17, AC-18e, AC-18f and AC-18g from AC-18c.
