# 0035. App Intents: tune, play, search and favorites from Siri and Shortcuts

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005, 0006
- Platforms: iOS, iPadOS, macOS. tvOS ships no intents (AC-20). On macOS the intents are available in the Shortcuts app only, because App Shortcuts with Siri phrases are not supported there (HIG, App Shortcuts, platform considerations).
- Builds on specs 0013 (catalogue, favorites resolution, `RowKey`), 0028 (`LastChannelKey`, `RecentsStore`, last channel written on every tune on every platform), 0012 (matching rules, Search entry), 0016 (title ids), 0011 (playing a title, My list, continue watching), 0029 (`ActivityStore`, progress and list snapshots), 0010 (inline playback and the Live section on iPhone, iPad and Mac), 0005 (`FavoriteRecord`), 0004 (source loading, missing credential), spec 0006 (root chooser, offline wording). Spec 0020 (group management: hidden and locked groups) is not written yet; see "Required of other specs".
- Blocked on the 0001 follow-up that hashes `streamURL` out of `Channel.id`. Until it merges every M3U `Channel.id` carries the stream URL (`M3UParser` builds `<tvg-id>#<url>` and `m3u#<url>#<n>`), so `ChannelEntity.id`, which Shortcuts stores in the user's library and syncs through iCloud, and AC-21's `FavoriteRecord` would both carry credentials (ADR-0003). The implementing PR does not open before that merge. Also blocked on 0029's ADRs for `WatchProgressRecord` and `ListEntryRecord`, which AC-25 reads.
- No new SwiftData record and no new persisted data on this device: favorites use `FavoriteRecord` (0005), the current channel uses 0028's `RecentsStore`, entitlement uses ADR-0006's cached state.
- ADR needed: the id formats `LastChannelKey.string` and `TitleReference.string` are stored in users' Shortcuts libraries and synced through iCloud, so freezing them is a decision that cannot be reversed once shipped; the criteria assume the formats in AC-1 and the freeze rule in Scope.
- Roadmap item "App Intents" in `README.md`.

## Design

Boards: none, no UI. Every intent either opens the app into a screen another spec owns (0010, 0011, 0012) or answers with a dialog. No intent shows a snippet view. The identifier prefix `intents.` is reserved for a snippet if one is added later and is not added to DR-11's list by this spec.
Design rules that apply: DR-12 (dialog and error copy may name the platform, never the user's device or the user), DR-14 (nothing works without an entitlement; AC-13).

### Interface

Names are binding; signatures show intent and may gain labels or `Sendable` constraints in the implementing PR.

AntennaCore (ADR-0005: no AppIntents import; the framework types live in Apps):

```swift
/// 0028's type. This spec adds the string form used as an entity id.
extension LastChannelKey {
    /// "<sourceID.uuidString>/<channelID>", split at the first "/" when parsing.
    public var string: String { get }
    public init?(parsing: String)
}

/// Identity of a movie or series on one source, for entity ids.
public struct TitleReference: Hashable, Sendable, Codable {
    public var sourceID: UUID
    public var titleID: String          // 0016 title id of kind .vod or .series
    public var string: String           // "<sourceID.uuidString>/<titleID>", same parsing rule
    public init?(parsing: String)
}

extension Catalogue {
    /// 0013/AC-15's rule with the position unknown: exactly one channel with that
    /// sourceID and id, else nil. The same rule 0028/AC-5 uses.
    func channel(for key: LastChannelKey) -> Channel?
    /// Name and number matches only, at most `limit`. Order in AC-4a and AC-4b.
    func channels(matching query: String, limit: Int) -> [RowKey]
}
```

Apps/Shared/Intents/, compiled under `#if !os(tvOS)`:

- `ChannelEntity: AppEntity` with `id == LastChannelKey.string` and `unavailable: IntentFailure?`; `ChannelQuery: EntityStringQuery`.
- `TitleEntity: AppEntity` with `id == TitleReference.string` and `unavailable: IntentFailure?`; `TitleQuery: EntityStringQuery`.
- `entities(for:)` never throws for a per-id condition. It returns one entity per parseable id, in the order given, and omits ids that do not parse. When the catalogue or title index cannot supply the item, `unavailable` is set to `sourceGone`, `channelGone`, `titleGone`, `credentialMissing`, `offline`, `stillLoading` or `sourceFailed`, and the entity's title is the display name Shortcuts passes with the stored entity when it does, else the id string. `perform` throws `unavailable` before any foreground request. Only `notEntitled`, `noSources`, `noCurrentChannel`, `lockedGroup` and `needsUnlock` originate in `perform`.
- Every `perform` is `@MainActor`, so intent code, the provider and the shared `ModelContainer`'s main context run on one actor; loads the provider starts run off the main actor as 0013 does.
- `TuneChannelIntent`, `PlayTitleIntent`, `OpenSearchIntent`, `ToggleFavoriteIntent` (parameter `mode: FavoriteAction`, an `AppEnum` with `toggle`, `add`, `remove`, default `toggle`; optional parameter `channel`).
- `AntennaShortcuts: AppShortcutsProvider` (AC-30).
- `IntentFailure: Error, CustomLocalizedStringResourceConvertible` with the cases and wording in the table below (AC-32).
- `IntentCatalogueProvider`, a `@MainActor` protocol the app implements and tests fake: `isEntitled`, read from ADR-0006's cached entitlement without awaiting StoreKit (AC-33); `sources` (id, name, kind, whether the credential is readable, loading state per 0010/AC-16); `catalogue(deadline:)` and `catalogue(for sourceID:, deadline:)`; `titles(deadline:)` and `titles(for sourceID:, deadline:)`; `playingChannel: LastChannelKey?`, non-nil only while the engine state is `.playing` in this process; `isLocked(_ key: LastChannelKey) -> Bool` and `isHidden(_:)`; `tune(_:)`, `play(_: TitleReference)`, `showSearch(query:)`, `favoritesChanged()`, `shortcutParametersChanged()`. The app's `shortcutParametersChanged()` calls `AntennaShortcuts.updateAppShortcutParameters()`.

| `IntentFailure` case | Wording |
|------|---------|
| `notEntitled` | "Antenna isn't unlocked on this device yet. Open Antenna to continue." |
| `noSources` | "Antenna has no sources yet. Open Antenna to add one." |
| `offline` | "You're offline. Connect to the internet and try again." (spec 0006/AC-8) |
| `stillLoading` | "Antenna is still loading your library. Try again in a moment." |
| `sourceFailed(name)` | "Antenna couldn't reach <name>. Try again later." |
| `credentialMissing(name)` | "The login for <name> hasn't synced from iCloud to this device yet." |
| `needsUnlock` | "Unlock your iPhone once and try again." ("iPad" on iPadOS, "Mac" on macOS) |
| `sourceGone` | "That channel's source is no longer in Antenna." |
| `channelGone(name, source)` | "<name> is no longer in <source>." |
| `lockedGroup(name)` | "<name> is in a locked group. Unlock it in Antenna first." |
| `titleGone(name, source)` | "<name> is no longer available from <source>." |
| `noCurrentChannel` | "Antenna isn't playing a channel right now. Say which channel instead." |

Sample source names in this spec are "Home" and "Work". Where a wording takes a source name and the saved name parses as a URL with a scheme, the wording uses "your source" instead (AC-2b).

## Problem

A user who knows what they want to watch should not have to open the app and browse for it. "Tune to Sport One in Antenna" from the lock screen, a Shortcuts automation that puts the news on at 7, a Back Tap that favorites the channel playing: none of this is possible, because Antenna exposes nothing to Siri or Shortcuts. The roadmap names App Intents and the catalogue, search and title specs now define what an intent can resolve against.

## Scope

In:
- `LastChannelKey.string` and `init?(parsing:)`, `TitleReference`, and the two `Catalogue` methods above, in AntennaCore.
- `ChannelEntity` and `ChannelQuery`: resolution by id, by name or number string, suggestions.
- `TitleEntity` and `TitleQuery` over 0016's movies and series.
- `TuneChannelIntent`: resolve in the background, continue in the foreground, tune per 0010.
- `PlayTitleIntent`: a movie per 0011/AC-10a or a series per 0011/AC-9b.
- `OpenSearchIntent`: open 0012's Search with an optional query.
- `ToggleFavoriteIntent`: add, remove or toggle a favorite for the playing channel or a named one, in the background, with a dialog.
- Five App Shortcuts with Siri phrases (AC-30).
- Which mode each intent runs in and what the user sees when the app is in the background or the foreground on each platform.
- Entitlement, no-source, offline, still-loading, credential-missing, locked-device, locked-group and gone cases as `IntentFailure` with plain wording.
- No intent, entity, dialog or error exposes a stream URL or a credential (ADR-0003).
- The id formats `LastChannelKey.string` and `TitleReference.string` are frozen once shipped: a later version may add formats but `init?(parsing:)` keeps accepting every format ever shipped, because the strings live in users' Shortcuts libraries.
- tvOS: the App Intents framework compiles on tvOS 16 and later, but the HIG states under App Shortcuts, platform considerations, "Not supported in tvOS"; tvOS has no Shortcuts app; `IndexedEntity` is not available on tvOS. There is no entry point, so the code is excluded with `#if !os(tvOS)` rather than shipped unreachable (AC-20).

Out (explicitly):
- Spotlight indexing of channels and titles through `IndexedEntity` (open question; a follow-up spec).
- Widgets, controls, Live Activities, Focus filters, interactive snippets (later specs, each with its own boards).
- Episodes as entities and "play season 2 episode 3" (series detail spec, 0011's out list).
- Guide programmes as entities and reminders (guide spec follow-up).
- Playback transport intents (pause, resume, mute) and volume (playback engine spec).
- Handoff and the iPhone-as-setup-device flow (roadmap, separate spec).
- Top Shelf on tvOS (0015 out list; separate spec).
- Donating intents or `relevantShortcuts` for Siri Suggestions (0028 lists it out as well).
- A Siri phrase or Shortcuts entry point on tvOS (AC-20).
- Any new persisted data, including a cached catalogue for offline intent resolution (source refresh spec).

Required of other specs:
- 0028: `LastChannelKey` gains `string` and `init?(parsing:)` (this spec's AC-1); `currentChannel` is not read from the store, `playingChannel` comes from the engine state, so 0028's store is read-only for this spec.
- 0010: the root view on iOS, iPadOS and macOS accepts programmatic requests to tune a channel (AC-12c) and to show Search with a query (AC-29), as 0015/AC-14a and AC-14c do on tvOS.
- 0012: a Search entry that takes a preset query and runs it without the AC-17 debounce (AC-29).
- 0011: playing a movie or series by `TitleReference` from outside the section counts as "a search result" in 0011/AC-10a and 0011/AC-9b (AC-26, AC-27).
- 0020: a catalogue predicate for a channel whose group is locked or hidden. Until it lands the app's `isLocked(_:)` and `isHidden(_:)` return false; AC-7, AC-8 and AC-19 are tested against the fake provider and hold whatever shape 0020 chooses.

## User flow

iOS and iPadOS:
1. The user says "Tune to Sport One in Antenna". Siri resolves the channel without opening the app. If two channels match, Siri lists them with their source and asks which. The app opens on Live with Sport One playing inline.
2. In Shortcuts, the user adds "Tune Channel" to an automation and picks a channel from the list, which shows favorites first and searches by name or number as they type.
3. The user says "Add this channel to favorites in Antenna" while a channel plays. Siri answers "Added Sport One to favorites." The app does not open; if it is open, the star fills.
4. The user says "Play Dune in Antenna". The app opens and the movie resumes where it was left.
5. The user says "Search Antenna" and the app opens on Search with the keyboard up.

macOS: the four intents appear as actions in the Shortcuts app on Mac and run the same way, with the app brought forward for tune, play and search. Siri phrases are not available (HIG).

tvOS: none. The intents are not compiled into the tvOS app (AC-20).

Failure wording comes from the table above and is read by Siri or shown by Shortcuts; the app does not open for a failure.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Key and reference round trip
Given a `LastChannelKey` with `sourceID` S and `channelID` "xtream#h#42", a `TitleReference` with S and "xtream#h#vod#55", and the strings "<S>/xtream#h#42", "<S>/m3u#a/b/c", "<S>/", "<S>", "/x", "not-a-uuid/x" and ""
When `string` is read and `init?(parsing:)` runs on each string for both types
Then the key's `string` is "<S>/xtream#h#42" and the reference's is "<S>/xtream#h#vod#55"; parsing the first string gives S and "xtream#h#42", the second gives S and "m3u#a/b/c" (split at the first "/" only), and the remaining five give nil; `TitleReference(parsing:)` also gives nil when the part after "/" is not a 0016 title id of kind `.vod` or `.series` (0016/AC-13a).

### AC-2 Entity ids and text carry no stream URL or credential
Given an M3U channel without `tvg-id` and one with `tvg-id`, both with `streamURL` `http://h/get.php?username=alice-7f3e&password=s3cr3t-9b2a`, tagged with source S, and an Xtream channel from credentials `alice-7f3e` / `s3cr3t-9b2a`
When `LastChannelKey(sourceID:channelID:).string`, `ChannelEntity.id`, `ChannelEntity.displayRepresentation` (title, subtitle, image URL), every `IntentFailure` wording built for those channels, and the `ToggleFavoriteIntent` dialogs are read
Then none of them contains `alice-7f3e`, `s3cr3t-9b2a`, `get.php`, `player_api.php` or `streamURL.absoluteString`. The M3U half of this criterion fails until the 0001 follow-up in the header merges; the test is added in the implementing PR, which opens after it.

### AC-2b Source names that are URLs
Given an M3U source whose saved name is `http://h/get.php?username=alice-7f3e&password=s3cr3t-9b2a` and whose `SourceRecord.url` is the same string
When a `ChannelEntity` for one of its channels is built and `credentialMissing`, `sourceFailed` and `channelGone` are built for it
Then the entity subtitle and every wording use "your source" in place of the name, and none contains the URL, `alice-7f3e` or `s3cr3t-9b2a`.

### AC-3 Lookup by key
Given a catalogue with channel C (`sourceID` A, `id` "x", `position` 3), a second channel with `id` "x" in source B, and a key K = (A, "x")
When `channel(for: K)` runs
Then it returns C: exactly one loaded channel has K's `sourceID` and `id` (0013/AC-15 with the position unknown); when two channels in A share `id` "x" it returns nil, as 0028/AC-5's resolution does; for a `sourceID` with no loaded channel it returns nil.

### AC-4a Name matching
Given channels "Sport One" (104, group "Sport"), "Sport Two" (105), "Eurosport 1" (210), "News 24" (24, group "Sport Report") and "Northern News" (1040), all in source A
When `channels(matching: q, limit: 20)` runs with q = "sport", "SPÖRT one" and "report"
Then "sport" returns Sport One, Sport Two (0012/AC-4b band 1, alphabetical), then Eurosport 1 (band 3), and not News 24, because group-only matches (band 5) are excluded; "SPÖRT one" returns Sport One only (0012/AC-2 folding and tokens); "report" returns nothing.

### AC-4b Number matching
Given the channels of AC-4a
When `channels(matching: q, limit: 20)` runs with q = "104", "10", "0104" and "24"
Then a query of digits only matches assigned numbers by prefix and never names: "104" returns Sport One then Northern News; "10" returns Sport One, Sport Two, Northern News; "0104" equals "104" (0012/AC-3 strips leading zeros); "24" returns News 24 only. Results are ordered by number ascending, so 104 before 1040, then source order, then `position` (0013/AC-12's tie-break). This deviates from 0012/AC-4b's alphabetical rule because a number query is a number lookup.

### AC-4c Empty query and limit
Given the channels of AC-4a and, separately, 30 channels named "Sport 1" to "Sport 30"
When `channels(matching:limit:)` runs with "" and " " at limit 20, and with "sport" at limit 20 over the 30
Then the first two return nothing and the third returns exactly 20.

### AC-5 Matching is fast
Given 50 000 channels in 400 groups
When `channels(matching: "spo", limit: 20)` runs after the catalogue is built
Then it completes in under 50 ms on the reference machine named in the test (the 0010/AC-22 filter bound), run with the 0016/AC-9 mechanism; on CI the same test fails above 250 ms.

### AC-6 Channel entity display
Given channel "Sport One", number 104, group "Sport", `logoURL` `http://h/logo.png`, from source "Home"; and a channel with `group` nil and `logoURL` nil from the same source
When their `ChannelEntity` values are built
Then the first has title "Sport One", subtitle "104 · Sport · Home" and no image, because `logoURL` is `http`; with `logoURL` `https://h/logo.png` it has an image from that URL; the second has subtitle "<number> · Home" and no image; the source name is always the last segment; `typeDisplayRepresentation` is "Channel"; the number is 0013's assigned number; `unavailable` is nil.

### AC-7 Suggested channels
Given a catalogue in the running app with 300 channels, favorites F1 and F2 (0013/AC-8 order F2, F1), one channel for which `isLocked` is true and one for which `isHidden` is true
When `ChannelQuery.suggestedEntities()` runs
Then it returns F2, F1, then the remaining channels in All channels order, 200 entities in total, without the locked and hidden channels; with no favorites it starts at the first channel in All channels order; with an empty catalogue it returns an empty array; with no catalogue in the running app it returns an empty array and the fake loader records no load, because suggestions are refreshed from the next in-app load through `shortcutParametersChanged()` (AC-30).

### AC-8 String query
Given the channels of AC-4a plus "Sport One HD" and a locked channel named "Sport Locked"
When `ChannelQuery.entities(matching: "sport")` and `entities(matching: "sport one")` run
Then the first returns `ChannelEntity` values for AC-4a's result plus Sport One HD in AC-4a's order, at most 20, without Sport Locked; the second returns Sport One alone, because when exactly one result's folded name equals the folded query the query returns only that entity, so Siri resolves it without a question; `entities(for: [ids])` returns an entity per parseable id in the order given, through AC-3, and omits ids that fail to parse.

### AC-9 Ambiguous name
Given "Sport One" in source A (104, group "Sport") and "Sport One" in source B (7, group "Sport")
When `entities(matching: "Sport One")` runs
Then it returns two entities in AC-4a order whose `displayRepresentation.subtitle` values differ ("104 · Sport · Home", "7 · Sport · Work", AC-6), so the framework's disambiguation shows two distinct rows; the spoken disambiguation itself is AC-31's device check.

### AC-10 Ambiguous number
Given channel 104 in sources A and C, and channel 105 in source A only
When `entities(matching: "104")` and `entities(matching: "105")` run
Then the first returns two entities with differing subtitles, in source order; the second returns one entity.

### AC-11 No match
Given no channel matches "zzz"
When `ChannelQuery.entities(matching: "zzz")` runs and `TuneChannelIntent.$channel.requestValueDialog` is read
Then the query returns an empty array and the dialog reads "Which channel?".

### AC-12a Tune: transition order
Given `TuneChannelIntent.supportedModes == [.background, .foreground(.dynamic)]`, an entitled user, a loaded catalogue and a resolved channel C with `unavailable` nil
When `perform` runs from the background with `systemContext.currentMode.canContinueInForeground` true
Then the fake provider's event log reads [resolve, foregroundRequest, tune(C's key)], with one `continueInForeground(nil, alwaysConfirm: false)` and one `tune`. That every failure check runs before the transition is asserted by the failure criteria, each of which records no foregroundRequest.

### AC-12b Tune: foreground refused or already there
Given the state of AC-12a
When `perform` runs with `canContinueInForeground` false
Then it throws `needsToContinueInForegroundError` and `tune(_:)` is not called.

### AC-12d Tune: already in the foreground
Given the state of AC-12a with `currentMode` already foreground
When `perform` runs
Then the event log reads [resolve, tune(C's key)] with no foregroundRequest.

### AC-12c Tune: outcome in the app
Given the app launched with a `tune(C)` request firing on appear, where C's source group is not the Live section's current group
When the request runs
Then the Live section is shown with All channels selected (0012/AC-6c's rule) and `browse.row.<C>` highlighted; inline playback is 0010/AC-6 and the last-channel write is 0028/AC-2a, both tested there.

### AC-13 Not entitled
Given `isEntitled` false
When each of the four intents runs with any parameters
Then each throws `IntentFailure.notEntitled` before any catalogue load, foreground request, `tune`, `play`, `showSearch` or record change.

### AC-14 No sources
Given `sources` is empty and `isEntitled` true
When `ChannelQuery.suggestedEntities()`, `ChannelQuery.entities(matching: "a")`, `TitleQuery.entities(matching: "a")` and each of the four intents run
Then the queries return empty arrays without a network request; each intent throws `IntentFailure.noSources` before any foreground request or `showSearch` call.

### AC-15 Credential missing on this device
Given an Xtream source "Work" whose Keychain item is absent on this device (0004/AC-10) and a stored `ChannelEntity` id for one of its channels
When `ChannelQuery.entities(for: [id])` runs, then `TuneChannelIntent.perform` and `ToggleFavoriteIntent.perform` run with the returned entity
Then the query returns one entity with `unavailable == .credentialMissing("Work")`; both intents throw `IntentFailure.credentialMissing("Work")` and make no foreground request, `tune(_:)` call or record change.

### AC-15b Keychain not readable in the background
Given an Xtream source "Work" whose fake credential store returns `errSecInteractionNotAllowed` (the status a `kSecAttrAccessibleAfterFirstUnlock` item gives before the first unlock after a restart) and no catalogue in the running app
When `TuneChannelIntent` runs with one of its ids, `ToggleFavoriteIntent` runs with the same, and both run again with the store returning `errSecDecode`
Then with `errSecInteractionNotAllowed`, `entities(for:)` returns the entity with `unavailable` nil, the event log reads [resolve, foregroundRequest, load, tune], and `ToggleFavoriteIntent`, which has no foreground mode, throws `IntentFailure.needsUnlock` with no record change; with `errSecDecode` both intents throw `IntentFailure.sourceFailed("Work")`. On macOS the first case arises only before the first login after a restart.

### AC-16 Referenced source offline or failed
Given no catalogue in the running app, a stored id from source "Home", Home failing with a `URLError` of the 0006/AC-8 set (or 0016/AC-10's `.transport` of those codes), and a second source "Work" that loads
When `ChannelQuery.entities(for: [id])` runs
Then only Home is loaded (`catalogue(for: Home)`), the entity's `unavailable` is `.offline`; when Home's failure is any other error it is `.sourceFailed("Home")`; Work's outcome never affects the result; when the running app already holds a catalogue in which Home is terminal, the entity resolves from it and the fake loader records no load.

### AC-17 Background load deadline
Given no catalogue in the running app, source A finishing after 2 s and source B still loading at 10 s on the injected clock
When `entities(for:)` runs with an id from A, then with an id from B, `ChannelQuery.entities(matching: "sport")` runs with a match in A and one in B, and `TitleQuery.entities(matching:)` runs while every title list is still loading at 10 s
Then the A entity resolves once A has finished; the B entity has `unavailable == .stillLoading`; the channel string query returns A's match only; the title query throws `IntentFailure.stillLoading` because no source finished; each at the 10 s deadline measured from the query call that started the load; `perform` starts no second deadline; the fake loader's `cancelCount` for B is 0.

### AC-18 Channel or source gone
Given a stored id whose `sourceID` matches no `SourceRecord`, and another whose source "Home" loaded without that `channelID`, passed with the stored display name "Sport One"
When `ChannelQuery.entities(for:)` runs with each, then `TuneChannelIntent.perform` runs with each entity
Then the first entity has `unavailable == .sourceGone` and title equal to its id string; the second has `unavailable == .channelGone("Sport One", "Home")`; `perform` throws each case and makes no foreground request.

### AC-19 Locked group
Given `isLocked(L)` true and `isHidden(H)` true on the provider
When `ChannelQuery.entities(for:)` runs with L's and H's ids, and `TuneChannelIntent` and `ToggleFavoriteIntent` run with L
Then both ids resolve with `unavailable` nil (a stored shortcut keeps its entity); both intents throw `IntentFailure.lockedGroup("<L's name>")` before any foreground request or record change; `TuneChannelIntent` with H follows AC-12a, because hiding a group removes clutter from lists and is not a privacy control. This criterion is provisional until 0020 is written; if 0020 makes hiding a privacy control, H follows L.

### AC-20 tvOS ships no intents
Given `project.yml` and the sources of the AntennaTV target
When `scripts/check-rules.sh` runs and the tvOS build runs
Then `project.yml` excludes `Apps/Shared/Intents` from AntennaTV, the check fails when any file in AntennaTV's sources outside that folder declares a conformance to `AppIntent`, `AppEntity`, `AppEnum` or `AppShortcutsProvider`, and the tvOS build succeeds. A Siri Remote voice request for Antenna is therefore unsupported on tvOS.

### AC-21 Add a favorite for the playing channel
Given `ToggleFavoriteIntent.supportedModes == .background`, `playingChannel` equal to C's key, `isFavorite(C)` false, favorites whose highest `sortOrder` is 4, and `mode` `toggle` (0013/AC-10: a new favorite gets the highest `sortOrder` plus one)
When `perform` runs with `channel` nil
Then one `FavoriteRecord` is inserted with `channelID == C.id`, `sourceID == C.sourceID`, `sortOrder == 5` (0013/AC-10), the result dialog reads "Added <C's name> to favorites.", the returned value is `true`, no foreground request is made, and `favoritesChanged()` is called once after the insert.

### AC-22 Remove a favorite
Given `isFavorite(C)` true with two snapshots resolving to C (a sync duplicate, 0013/AC-9a) and `mode` `toggle`
When `perform` runs for C
Then every record in `favoritesToRemove(for: C)` is deleted (both), no other record changes, the dialog reads "Removed <C's name> from favorites.", the returned value is `false`, and `favoritesChanged()` is called once.

### AC-23 Explicit mode and explicit channel
Given `mode` `add` with `isFavorite(C)` true, then `mode` `remove` with `isFavorite(C)` false, then `channel` set to D while `playingChannel` is C, then `channel` nil with `playingChannel` nil (nothing playing, or the app not running)
When `perform` runs each case
Then the first makes no record change and the dialog reads "<C's name> is already a favorite." with value `true`; the second makes no change and reads "<C's name> isn't a favorite." with value `false`; the third acts on D, not C; the fourth throws `IntentFailure.noCurrentChannel`.

### AC-24 Title entity and query
Given a loaded title index for source "Home" (id S) with movie "Dune" (`xtream#h#vod#55`, poster `https://h/p.jpg`) and series "Dark" (`xtream#h#series#7`, no poster), and the id strings "<S>/xtream#h#55", "<S>/xtream#h#episode#9", "<S>/m3u#x"
When `TitleEntity` values are built, `TitleQuery.entities(matching: "d")` runs, and `entities(for:)` runs with every id
Then "Dune" has id "<S>/xtream#h#vod#55", subtitle "Movie · Home" and an image from the poster; "Dark" has subtitle "Series · Home" and no image; `typeDisplayRepresentation` is "Title"; no `vodInfo` or `seriesInfo` call is made to build an entity; the string query returns both in 0012/AC-4d order (title-prefix first, then alphabetical, interleaved) using 0012/AC-2 folding, at most 20; `entities(for:)` returns Dune and Dark and omits the three strings that do not parse as `TitleReference` (AC-1).

### AC-25 Suggested titles
Given `ActivityStore` (0029) with progress snapshots for two titles in the 0011/AC-4 window, list entries for three titles, one title in both, one entry whose title is not in the loaded index, and a title index in the running app
When `TitleQuery.suggestedEntities()` runs
Then it returns the continue-watching titles in 0011/AC-4 order, then the remaining My list titles in 0011/AC-14 order, each once, without the unresolved one, at most 50; with no records, or with no title index in the running app, it returns an empty array and the fake loader records no load.

### AC-26 Play a movie
Given `PlayTitleIntent.supportedModes == [.background, .foreground(.dynamic)]`, an entitled user, a loaded title index and the movie "Dune" with `unavailable` nil
When `perform` runs with that title from the background
Then the AC-13, AC-14 and AC-17 checks run first; then `continueInForeground(nil, alwaysConfirm: false)` is awaited once; then `play(Dune's reference)` is called once and the intent returns without a dialog. Resume from the saved position is 0011/AC-10a and the URL is built by 0016/AC-7 at that moment, both tested there.

### AC-27 Play a series
Given the series "Dark"
When `perform` runs with that title
Then after the foreground transition `play(Dark's reference)` is called once and the intent returns without an error; episode choice and the zero-episode alert are 0011/AC-9b.

### AC-28 Title gone
Given a stored `TitleEntity` id whose title is absent from the loaded lists of its source "Home", passed with the stored name "Dune", and one whose `sourceID` matches no `SourceRecord`
When `TitleQuery.entities(for:)` runs, then `PlayTitleIntent.perform` runs with each entity
Then the first entity has `unavailable == .titleGone("Dune", "Home")` and the second `.sourceGone`; `perform` throws each case and makes no foreground request.

### AC-29 Open Search
Given `OpenSearchIntent.supportedModes == .foreground(.immediate)`, an entitled user with sources, and an optional `query` parameter
When `perform` runs with `query` "north", then with nil, then with "   "
Then `showSearch(query:)` is called once per run with "north", nil and nil (a query that is only whitespace becomes nil); in the app, launched with the same request on appear, the Search tab (iPhone) or section (iPad, Mac) is shown, `search.field` holds "north" and `search.results` is non-empty before 0012/AC-17's debounce interval has passed on the injected clock, and with nil `search.field` is empty, has focus, and shows recents per 0012/AC-11.

### AC-30 App Shortcuts
Given `AntennaShortcuts.appShortcuts`
When the array is read
Then it has five entries, under the HIG limit of ten: `TuneChannelIntent` with phrases "Tune to \(\.$channel) in \(.applicationName)", "Watch \(\.$channel) in \(.applicationName)" and "Put on \(\.$channel) in \(.applicationName)"; `PlayTitleIntent` with "Play \(\.$title) in \(.applicationName)"; `OpenSearchIntent` with "Search \(.applicationName)" and "Find a channel in \(.applicationName)"; `ToggleFavoriteIntent` preconfigured with `mode` `add` and "Add this channel to favorites in \(.applicationName)"; `ToggleFavoriteIntent` preconfigured with `mode` `remove` and "Remove this channel from favorites in \(.applicationName)"; every phrase contains `\(.applicationName)`; the app calls `shortcutParametersChanged()` once after each catalogue rebuild and once after each `favoritesChanged()`, recorded on the fake.

### AC-31 Siri phrase on device
Given an iPhone with Antenna installed, entitled, with a source whose channels include "Sport One" among the suggested entities, and a second source with another "Sport One"
When the user says "Tune to Sport One in Antenna" from the lock screen
Then Siri asks which, showing both rows with their source, and opens Antenna on Live with the chosen channel playing; "Add this channel to favorites in Antenna" while it plays answers "Added Sport One to favorites." without opening the app.

### AC-32 Error wording
Given every `IntentFailure` case built with the sample values of this spec
When `localizedStringResource` is resolved in the base locale
Then it equals the table in Design for that case; none contains a URL, a path, a port, an HTTP status, a `URLError` code or an `OSStatus`; a source's saved display name may appear verbatim; `String(reflecting:)` of each case meets the same rule.

### AC-33 Entitlement on a cold background launch
Given the app launched in the background by an intent, a StoreKit fake that has not answered, and ADR-0006's cached entitlement set to unlocked, then absent
When `isEntitled` is read
Then it returns true at once for the cached unlock without awaiting the fake, and false when no cache exists; with false the intent throws `notEntitled` (AC-13).

### AC-34 Shortcuts on Mac
Given a Mac with Antenna installed, entitled, with one source
When the user runs "Tune Channel", "Play Title", "Open Search" and "Toggle Favorite" from the Shortcuts app with Antenna not running, then running with a channel playing
Then the first three bring Antenna forward to the channel, title or Search; "Toggle Favorite" fails with `noCurrentChannel` while Antenna is not running, and answers with AC-21's dialog without bringing Antenna forward while it plays.

## Edge cases and failure modes

- Offline with the app running and a catalogue loaded earlier: intents resolve from it and tune; the engine then fails as the playback spec says. Offline with nothing loaded: AC-16.
- Slow or huge source: AC-17's deadline; a 50 000-channel source that takes longer than 10 s fails with `stillLoading` on every attempt until the load completes in the app or is cached by the source refresh spec (open question). Loading only the referenced source (AC-16) keeps other sources' size out of the deadline for id resolution; string queries need every source.
- Malformed data: rows 0016/AC-4 skips are absent from the title index; a title id for a skipped row is `titleGone`. Channels with an empty name get 0013's fallback name; duplicate numbers cannot occur because 0013 assigns them.
- iCloud has synced sources but this device's first CloudKit import has not finished: `sources` is empty and intents throw `noSources`. Accepted; the wording tells the user to open Antenna, which completes the import.
- A source deleted and added again gets a new `SourceRecord.id`, so shortcuts that stored its entities fail with `sourceGone` and must be picked again.
- Offline with nothing loaded and a string query: every source fails, so `entities(matching:)` throws `offline` when every failure is of the spec 0006/AC-8 set, else `sourceFailed` for the first source in source order.
- Memory: a background launch loads no more than the in-app catalogue holds (0013); the background memory budget is checked on device with the 50 000-channel fixture alongside AC-31.
- Credential arrives after a `credentialMissing` failure: the next run loads the source and succeeds; nothing is cached between runs.
- A credential is read in the background only to load a source's channel or title list (0003's `player_api.php` needs it); the playable URL is built after the foreground transition and stored nowhere. Before the first unlock after a restart that read fails: AC-15b.
- First launch with an empty store: AC-14; the app opened by `OpenSearchIntent` shows the paywall or onboarding, never Search.
- Two intents at once (an automation firing while Siri resolves): the second awaits the same in-flight load through the provider; both see the same catalogue value.
- `FavoriteRecord` duplicates from a sync race: AC-22 removes all of them; AC-21 inserts at most one per run.
- Provider renames a channel: the id is unchanged, the entity's title updates on the next `entities(for:)`.
- A stored shortcut from another device whose `sourceID` is a source this device holds but has not loaded: AC-16 or AC-17 depending on the state.
- Intents run in the app process launched in the background; they share the `ModelContainer` (ADR-0002) and the Keychain read path (ADR-0003).
- Logging: entity ids, `LastChannelKey.string`, `TitleReference.string` and intent parameters are not logged. Until the 0001 follow-up lands, an M3U `channelID` carries the stream URL, which is the reason for the block in the header.
- Siri recognises parameter values from `suggestedEntities()` (AC-7, AC-25); a channel outside the 200 is reachable by the typed Shortcuts picker and by Siri's follow-up question, which goes through `entities(matching:)`.
- Two Xtream sources on one host (0016/AC-13's accepted collision): `TitleReference` carries the `sourceID`, so entities and 0029's (`titleID`, `sourceID`) keys stay distinct.
- Reduce Motion, VoiceOver, Dynamic Type: no UI of this spec's own; Siri and Shortcuts render dialogs.
- macOS: no Siri phrases (HIG); `AntennaShortcuts` compiles and is inert there; the four actions appear in the Shortcuts app and bring the app forward for tune, play and search.

## Test plan

Core criteria are swift-testing tests in AntennaCore over the 0013 fixtures. Integration tests host in the iOS app target and call each intent's `perform()` and each query's methods directly with a fake `IntentCatalogueProvider` (recorded `tune`, `play`, `showSearch`, `favoritesChanged`, `shortcutParametersChanged`; injected sources, catalogue, title index, entitlement, lock and hidden predicates, loading schedule and clock), an in-memory `ModelContainer` and an injected `UserDefaults` suite. Foreground transition calls are observed through a recording wrapper around `continueInForeground` and `needsToContinueInForegroundError`. The UI parts of AC-12c and AC-29 launch the app with `-antenna.uiTest` and an argument that runs the provider request on appear, as 0015's navigator tests do. No identifiers are introduced; the UI assertions use 0010's `browse.*` and 0012's `search.*`. `project.yml` has no test targets today; the implementing PR adds `AntennaTests` (hosted in Antenna) and `AntennaTVTests` (hosted in AntennaTV) for the integration rows, unless an earlier implementing PR has added them.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | core (parameterised over strings and both types) | TBD |
| AC-2 | core (keys and ids) + integration (entity, dialogs, errors) | TBD; the implementing PR opens after the 0001 follow-up merges |
| AC-3 | core | TBD |
| AC-2b | integration | TBD |
| AC-4a | core (parameterised over queries) | TBD |
| AC-4b | core (parameterised over queries) | TBD |
| AC-4c | core | TBD |
| AC-5 | core benchmark, `ANTENNA_BENCHMARKS=1`, 250 ms bound on CI | TBD |
| AC-6 | integration | TBD |
| AC-7 | integration | TBD |
| AC-8 | integration | TBD |
| AC-9 | integration | TBD |
| AC-10 | integration | TBD |
| AC-11 | integration | TBD |
| AC-12a | integration (fake provider, recorded transition) | TBD |
| AC-12b | integration (two system contexts) | TBD |
| AC-12c | ui (iPhone and iPad) | TBD |
| AC-12d | integration | TBD |
| AC-13 | integration (four intents) | TBD |
| AC-14 | integration | TBD |
| AC-15 | integration (fake credential store) | TBD |
| AC-15b | integration (fake credential store returning a read error) | TBD |
| AC-16 | integration (parameterised over error codes) | TBD |
| AC-17 | integration (injected clock and loading schedule) | TBD |
| AC-18 | integration | TBD |
| AC-19 | integration (fake predicates) | TBD |
| AC-20 | integration (`scripts/check-rules.sh` and the tvOS build in CI) | TBD |
| AC-21 | integration (in-memory ModelContainer) | TBD |
| AC-22 | integration | TBD |
| AC-23 | integration (parameterised, one row per case) | TBD |
| AC-24 | integration | TBD |
| AC-25 | integration (in-memory ModelContainer with 0029's records) | TBD |
| AC-26 | integration (recorded transition) | TBD |
| AC-27 | integration | TBD |
| AC-28 | integration | TBD |
| AC-29 | integration + ui (iPhone and iPad) | TBD |
| AC-30 | integration (phrases read from `appShortcuts`; update calls recorded) | TBD |
| AC-31 | device | manual on iPhone; Siri speech cannot run in CI |
| AC-32 | integration (parameterised over cases) | TBD |
| AC-33 | integration (StoreKit fake) | TBD |
| AC-34 | device | manual on a Mac |

## Dropped

- AC-4 Name and number matching: split into AC-4a, AC-4b and AC-4c, because it held eight queries and left the number prefix rule unstated.

## Open questions

- Spotlight: adopt `IndexedEntity` (iOS 18, macOS 15; not tvOS) for favorites and My list only, re-indexed when they change, and never for the full catalogue because tens of thousands of entries churn on every refresh? Or index nothing until the source refresh spec caches the catalogue? Needs its own spec either way.
- Caps of 200 suggested channels and 50 suggested titles: enough for Siri recognition, or should favorites be the whole suggestion list?
- Is 10 s the right background deadline (AC-17)? A cached catalogue (source refresh spec) would make the deadline matter only on first use.
- Should `TuneChannelIntent` on iPhone enter full screen (0010/AC-17) rather than inline Live?
- Locked group (AC-19): decided to fail with a message rather than open the app and let 0020's unlock prompt run, so a locked channel never comes on screen from a lock-screen request. Revisit when 0020 is written.
- `OpenSearchIntent` when not entitled or with no sources: decided to throw like the other three (AC-13, AC-14) instead of opening the app on the paywall or onboarding.
- Hidden channels: decided reachable by a stored id and absent from suggestions and string queries (AC-7, AC-8, AC-19), on the reading that hiding is about clutter. 0020 may overturn it.
- `ToggleFavoriteIntent` acts only on a channel playing in this process (AC-23). The alternative, acting on 0028's last channel, would let "add this channel" work from the lock screen on iPhone after the app stopped; the wording would then change to "hasn't played a channel yet".
- Splitting this spec into channel intents and title intents, so the channel half does not wait on 0011, 0016 and 0029: the reviewer proposed it. Kept as one spec because the provider, failure table and shortcuts list are shared; the title criteria (AC-24 to AC-28) can ship as a later PR of the stack.
- Digit-only queries match numbers only (AC-4b), so "24" does not find a channel named "Channel 24" numbered 7. Should name matches follow number matches?
- Channel logos are shown only for `https` URLs (AC-6). Is dropping `http` logos acceptable, given many providers serve them?
