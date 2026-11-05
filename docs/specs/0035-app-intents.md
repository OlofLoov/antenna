# 0035. App Intents: tune, play, search and favorites from Siri and Shortcuts

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Builds on specs: 0004, 0005, 0006, 0010, 0011, 0012, 0013, 0016, 0020, 0028, 0029
- Needs from other specs: 0001 takes the stream link out of M3U channel ids, because Shortcuts stores those ids and syncs them through iCloud; 0010 accepts requests to tune a channel and open Search on iOS, iPadOS and macOS; 0012 runs a preset query without the typing delay; 0011 plays a title by reference; 0020 supplies lock and hide checks.
- Blocked on: the ADR 0029 is blocked on, for watch progress and My list.
- Follow-up ADR: freezing the text formats of the channel and title ids stored in users' Shortcuts libraries, since they cannot change once shipped. Meanwhile the spec assumes the formats and the rule in Notes for the plan.
- Platforms: iOS, iPadOS, macOS. On the Mac the actions are in the Shortcuts app only; Siri phrases are not supported there. tvOS ships none (AC-20).
- User stories: US-22

## Summary

For people who know what they want to watch and do not want to open the app and browse for it. Once this ships, they can say "Tune to Sport One in Antenna" from the lock screen, "Play Dune in Antenna", "Search Antenna", or "Add this channel to favorites in Antenna", and build Shortcuts automations from the same four actions, such as putting the news on at 7. On a Mac the actions are available in the Shortcuts app. Apple TV gets none of this, because Apple does not support app shortcuts there, and nothing here adds Spotlight results, widgets or playback controls such as pause.

## Design

Boards: none, no UI. Each action either opens a screen another spec owns (0010, 0011, 0012) or answers with a spoken or written reply from Siri or Shortcuts.
Design rules that apply: DR-12, DR-14.

## Problem

A user who knows what they want has to open Antenna and browse for it. Asking Siri for a channel from the lock screen, an automation that puts the news on at 7, or a Back Tap that favorites the playing channel are all impossible, because Antenna offers nothing to Siri or Shortcuts. The catalogue, search and title specs now define what such a request can be matched against.

## Scope

In:
- Four actions: tune a channel, play a movie or series, open Search (optionally with a query), and add, remove or toggle a favorite.
- Five Siri phrases on iPhone and iPad, among them "Add this channel to favorites in Antenna" and "Remove this channel from favorites in Antenna".
- Picking a channel by name or number, and a movie or series by name, with Siri asking which when two match.
- Suggested channels and titles in Shortcuts: favorites, then other channels; titles in progress, then My list.
- Changing a favorite without opening the app, with a spoken reply.
- Plain replies for every failure: not unlocked, no sources, offline, still loading, login not on this device, phone not yet unlocked after a restart, locked group, and a channel, title or source that is gone.
- No action, reply or stored id exposes a stream link or password (ADR-0003).
- Shortcuts that users saved keep working across app updates.

Out (explicitly):
- Spotlight results for channels and titles.
- Widgets, Control Center controls, Live Activities, Focus filters and custom reply views.
- Episodes by name, such as "play season 2 episode 3".
- Guide programmes and reminders.
- Pause, resume, mute and volume.
- Handoff and setting up from the iPhone.
- The Apple TV Top Shelf (0034).
- Siri Suggestions learned from use.
- Any action or Siri phrase on Apple TV.
- Storing anything new, such as a copy of the channel list for offline use.

## User flow

iPhone and iPad:
1. The user says "Tune to Sport One in Antenna". Siri finds the channel without opening the app; if two sources have a Sport One, Siri lists both with their source and asks which. Antenna opens on Live with Sport One playing.
2. In Shortcuts the user adds "Tune Channel" to an automation and picks a channel from a list that starts with their favorites and searches by name or number as they type.
3. While a channel plays the user says "Add this channel to favorites in Antenna". Siri answers "Added Sport One to favorites." without opening the app.
4. The user says "Play Dune in Antenna". Antenna opens and the movie resumes where it was left.
5. The user says "Search Antenna" and Antenna opens on Search with the keyboard up.

Mac: the four actions appear in the Shortcuts app and behave the same, bringing Antenna forward for tune, play and search.

When something goes wrong, Siri or Shortcuts reads or shows a plain sentence, and the app does not open.

## Acceptance criteria

### AC-2 Shortcuts never hold a password
Given sources whose stream links, Xtream logins or even saved names contain a username and password
When the user picks one of their channels in Shortcuts, Siri describes it, or an action replies or fails
Then no id (the reference Shortcuts saves to remember which channel or title you picked) saved in the user's library, no description and no reply contains the username, password or stream link; a source named with a link is called "your source".

### AC-8 Ask for a channel by name or number
Given the user's channels
When they ask for a channel by name, in any case or with or without accents, or by its number
Then matching channels are offered, a single exact name match without a question, and a number finds channel numbers rather than names; with no match Siri asks "Which channel?".

### AC-9 Siri asks which when two channels match
Given two sources each have a channel called Sport One, or a channel with the same number
When the user asks for it
Then Siri offers both, each described with its number, group and source so the user can tell them apart, and plays the one they choose.

### AC-7 Shortcuts suggests what you watch
Given the user is choosing a channel or a title in Shortcuts while Antenna has its library loaded
When the list of suggestions appears
Then channels start with the user's favorites in their order, followed by the other channels, and titles show those in progress, then My list, each once; locked and hidden channels and titles that no longer exist are left out.

### AC-12a Tune a channel by voice or shortcut
Given the user is unlocked with a source and asks for a channel that is available
When Siri or a shortcut runs "Tune Channel", with Antenna closed, in the background or already open
Then Antenna comes forward on Live with the channel highlighted and playing, switching to All channels if needed; if the system will not bring Antenna forward, nothing is tuned.

### AC-21 Change a favorite without opening the app
Given a channel is playing in Antenna, or the user names one
When they say "Add this channel to favorites in Antenna" or "Remove this channel from favorites in Antenna", or run Toggle Favorite
Then Add adds it at the end of Favorites, Remove removes it with any duplicates, and Toggle Favorite does whichever applies; Siri replies "Added <channel> to favorites.", "Removed <channel> from favorites.", "<channel> is already a favorite." or "<channel> isn't a favorite."; the app stays in the background; with nothing playing and no channel named, Siri replies "Antenna isn't playing a channel right now. Say which channel instead."

### AC-26 Play a movie or series
Given a movie or series from the user's sources
When they say "Play <title> in Antenna" or run "Play Title"
Then Antenna comes forward and the movie resumes where it was left, or the series opens on the episode 0011 picks.

### AC-29 Open Search
Given the user is unlocked with a source
When they say "Search Antenna" or run "Open Search" with or without a query
Then Antenna opens on Search, either with the query typed and results showing straight away, or with an empty field focused and recent searches listed; a query of only spaces counts as none.

### AC-13 Nothing works until Antenna is unlocked and set up
Given Antenna is not unlocked on this device (0024), or has no sources
When any action runs, even when the system starts Antenna in the background to run it
Then it changes and opens nothing and replies "Antenna isn't unlocked on this device yet. Open Antenna to continue." or "Antenna has no sources yet. Open Antenna to add one."

### AC-15 A clear reply when a channel or title cannot play
Given the channel or title the user asked for cannot be reached: its login has not synced to this device, the device is offline and Antenna has not loaded that source, the source is still loading or failed, the channel is in a locked group, or the channel, title or source is gone
When the action runs
Then it opens nothing and changes nothing, and Siri or Shortcuts says which in one plain sentence naming the source or channel, never a link, code or technical error; a shortcut that names a missing item keeps working once it comes back.

### AC-20 Apple TV ships no actions
Given the Apple TV app
When it is built
Then it contains none of these actions or phrases, so Siri on Apple TV offers nothing for Antenna.

### AC-34 Shortcuts on the Mac
Given a Mac with Antenna unlocked and one source
When the user runs Tune Channel, Play Title, Open Search and Toggle Favorite from the Shortcuts app, first with Antenna closed and then with a channel playing
Then the first three bring Antenna forward to the channel, title or Search, and Toggle Favorite says nothing is playing while Antenna is closed and changes the favorite without bringing Antenna forward while it plays.

## Edge cases

- Before the first unlock after a restart, Tune and Play work once Antenna comes forward; changing a favorite asks the user to unlock once and try again.
- Offline with Antenna running and its library loaded: the request is matched and tuned; playback then fails as the player spec says.
- A source too large to load within 10 seconds in the background keeps replying "still loading" until Antenna has loaded it once.
- Sources synced through iCloud but not yet downloaded to this device count as no sources; opening Antenna fixes it.
- A source deleted and added again breaks shortcuts that stored its channels; the user picks them again.
- A login that arrives after a failure: the next run succeeds.
- Two requests at once share one library load.
- A renamed channel keeps working in saved shortcuts and shows its new name.
- Channels outside the 200 suggestions can still be found by typing or by Siri's follow-up question.
- Two Xtream sources on one host keep separate titles.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-2 | core + integration |
| AC-8 | core + integration |
| AC-9 | integration + device (Siri's spoken question) |
| AC-7 | integration |
| AC-12a | integration + ui + device (Siri on an iPhone lock screen) |
| AC-21 | integration + device |
| AC-26 | integration |
| AC-29 | integration + ui |
| AC-13 | integration |
| AC-15 | integration |
| AC-20 | integration (build check and tvOS build in CI) |
| AC-34 | device (Shortcuts on a Mac) |

## Open questions

- Spotlight: index favorites and My list only, or nothing until a cached catalogue exists? Needs its own spec.
- 200 suggested channels and 50 titles: enough for Siri, or should favorites be the whole list? Can be decided in the plan.
- Is 10 seconds the right background deadline? Can be decided in the plan.
- Should Tune Channel on iPhone go full screen rather than play inline? That would change AC-12a.
- Should a locked channel fail with a reply, so it never comes on screen from the lock screen, rather than open the app on 0020's unlock prompt? Changes AC-15; answer before Accepted.
- Should hidden channels stay reachable from a saved shortcut while left out of suggestions, on the reading that hiding is about clutter? Changes AC-7; answer before Accepted, against 0020.
- Should Open Search fail when not unlocked or without sources, rather than open the app on the paywall or setup? Changes AC-13; answer before Accepted.
- Toggle Favorite acts only on a channel playing in this process. Acting on the last channel instead would make it work after the app stopped, and would change AC-21.
- A number-only query finds numbers, not names, so "24" does not find "Channel 24" numbered 7. Should names follow? Would change AC-8.
- Channel logos show only for `https` links. Is dropping `http` logos acceptable? Can be decided in the plan.

## Notes for the plan

- Ids: channel `"<sourceID>/<channelID>"` and title `"<sourceID>/<0016 title id of kind vod or series>"`, split at the first "/". Once shipped, parsing keeps accepting every format ever shipped. AntennaCore adds `LastChannelKey.string` and `init?(parsing:)`, `TitleReference`, `Catalogue.channel(for:)` (exactly one channel with that source and id, else nil) and `channels(matching:limit:)`; no AppIntents import (ADR-0005). Intent code lives in `Apps/Shared/Intents/` under `#if !os(tvOS)`, excluded from AntennaTV in `project.yml`, with a `check-rules.sh` grep for `AppIntent`, `AppEntity`, `AppEnum`, `AppShortcutsProvider`.
- Matching: names use 0012's folding and bands with group-only matches excluded; digits-only queries prefix-match numbers, ordered by number, then source, then position. Benchmark: 50 000 channels under 50 ms on the reference machine, 250 ms on CI.
- `entities(for:)` never throws per id; unparseable ids are omitted, unavailable ones carry a failure (source gone, channel gone, title gone, credential missing, offline, still loading, source failed) that `perform` throws before any foreground request. Background loads fetch only the referenced source for id lookups, with a 10-second deadline from the query, never cancelled.
- Modes: Tune and Play are background then `.foreground(.dynamic)` with `continueInForeground(nil, alwaysConfirm: false)`, throwing `needsToContinueInForegroundError` when refused; Search is `.foreground(.immediate)`; Toggle Favorite is background only, with `mode` toggle, add or remove, returning the new state. Every `perform` is `@MainActor` and goes through an injectable `IntentCatalogueProvider`.
- Entitlement is read from ADR-0006's cached state without waiting on StoreKit. Keychain `errSecInteractionNotAllowed` before first unlock: Tune resolves and loads after coming forward; Toggle Favorite throws `needsUnlock` ("Unlock your iPhone once and try again", iPad or Mac by platform). `errSecDecode` reads as source failed.
- Reply wording, verbatim: "You're offline. Connect to the internet and try again."; "Antenna is still loading your library. Try again in a moment."; "Antenna couldn't reach <name>. Try again later."; "The login for <name> hasn't synced from iCloud to this device yet."; "That channel's source is no longer in Antenna."; "<name> is no longer in <source>."; "<name> is in a locked group. Unlock it in Antenna first."; "<name> is no longer available from <source>."; "<channel> is already a favorite."; "<channel> isn't a favorite."; "Which channel?". No URL, path, port, HTTP status or error code in any reply or its debug description.
- Siri phrases (five shortcuts): "Tune to / Watch / Put on <channel> in Antenna", "Play <title> in Antenna", "Search Antenna" and "Find a channel in Antenna", "Add this channel to favorites in Antenna" (mode add), "Remove this channel from favorites in Antenna" (mode remove). Refresh shortcut parameters after each catalogue rebuild and each favorites change.
- Entity display: channel subtitle "<number> · <group> · <source>", logo only from `https`; title subtitle "Movie · <source>" or "Series · <source>" with the poster, no extra network call per entity.
- Nothing is logged that contains an entity id or intent parameter. Favorites go through `FavoriteRecord` (0005), new ones at the highest sort order plus one; removal deletes every duplicate.
- Caps: 200 suggested channels, 50 suggested titles, 20 matches per query; leading zeros in a number query are ignored. 0011 treats a play by title reference like a play from a search result; 0020's lock and hide checks return false until it lands. A build check fails if the actions reach the tvOS target.

## Dropped

- Split earlier (kept for history): AC-4 into AC-4a, AC-4b and AC-4c, because it held eight queries and left the number rule unstated.
- Merged into AC-2: AC-2b.
- Merged into AC-7: AC-25.
- Merged into AC-8: AC-4a, AC-4b, AC-4c, AC-11.
- Merged into AC-9: AC-6, AC-10.
- Merged into AC-12a: AC-12b, AC-12c, AC-12d, AC-31.
- Merged into AC-13: AC-14, AC-33.
- Moved to Edge cases: AC-15b.
- Merged into AC-15: AC-16, AC-17, AC-18, AC-19, AC-28, AC-32.
- Merged into AC-21: AC-22, AC-23.
- Merged into AC-26: AC-24, AC-27.
- Moved to the implementation plan: AC-1, AC-3, AC-5, AC-30.
