# Design

## Context

Boards: `openspec/specs/design-system/boards/iPhone-Recents.dc.html`, `iPad.dc.html`, `Main.dc.html`, `iPhone-Loading.dc.html`, `iPad-Loading.dc.html`.

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Channel rows share one anatomy", "A current programme always shows its progress", "Channels without a logo show initials", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums".

Not drawn yet: the Recents row in the iPad and Mac sidebar, the Recents group row and header in the Apple TV overlay, the iPad Recents list header, and the loading screen with the restored channel already playing.

## Goals / Non-Goals

**Goals:**
- One on-device store for recents, the session and the last channel, shared by every platform.
- One session tracker that every live tune passes through.

**Non-Goals:**
- Syncing recents. Two Apple TVs in one home would overwrite each other, and M3U identities would carry credentials through iCloud.
- Restoring the Apple TV's current group at launch.

## Decisions

- Storage is on-device `UserDefaults`, no SwiftData, no sync. Keys: `recents.list`, `recents.session`, and `shell.lastChannel` with exactly the payload `tvos-shell` asserts. `LastChannelKey` (source id, channel id) moves into AntennaCore. The session holds tab and group only, so the last channel has one home.
- With profiles (change `add-profiles`), each key is per profile: the keys above for the first profile, the same key with `.<profile id>` appended for the others.
- Every live tune on every device goes through one session tracker, which writes the last channel before the engine loads it and keeps it if the load fails. No other app code calls the engine's load. Playing a movie or episode is not a tune and cancels the ten-second count. Leaving the app, a new tune, or the engine leaving playing also cancel it.
- A source observer watches local saves and remote changes on the app container, diffs source ids, and for each removed id clears the store, stops the count if the playing channel was in it, then asks for a catalogue rebuild. Only an observed deletion counts, not a missing record.
- The store refuses any channel id containing `://`. The `m3u-playlists` follow-up that hashes the stream URL out of `Channel.id` removes the filter and drops the requirement on links with passwords. Ids are never logged or put in an identifier, label or error.
- Only a group the user picks is written to the session. Groups the app selects as a fallback are shown but not written.
- Live sources start loading when the app's root appears, not when Live is first shown, so a session restored to another tab has channels ready.
- `channel-catalogue` gains a Recents group kind and a way to replace it without rebuilding the catalogue, within the favorites time bound. A channel id matching two channels does not resolve.
- Recents never becomes the current group in the channel overlay. The previous-channel swipe keeps the current group. Group counts include Recents, and Recents shows its count on iPad, Mac and Apple TV.
- The Recents group hides when empty rather than showing an empty state as Favorites does.
- Adding Recents shifts the index-based identifiers of later groups by one. Overlay and phone live UI tests run with empty recents. XCUITest cannot read the app's defaults, so a debug build mirrors last-channel writes to a file beside the fake engine log.
- With Reduce Motion the swipes do not slide.

## Risks / Trade-offs

- Open question: syncing recents would change the Recents requirements and needs its own decision. `add-watch-progress-sync` syncs recent searches only.
- Open question: restore plays the channel at launch, including on cellular. Showing it selected with a play button instead would change the last-channel requirement. Answer before the change is accepted.
- Open question: swipe left toggles between two channels and swipe right opens Recents. A long press, or stepping back through all of Recents, would change those requirements.
- Open question: storing a hash of the identity now would lift the M3U restore block, and change the value `tvos-shell` stores.
- Open question: Apple TV still forgets the current group at launch. Restoring it needs a change to `add-tv-zap-bar-and-number-entry`.
- [No M3U channel appears in Recents or is restored until the `m3u-playlists` follow-up] → the filter is silent, and the follow-up removes it.

## Implementation decisions

- The list, session and channel key are value types in AntennaCore (`RecentChannels`, `LiveSession`, `LastChannelKey`). Reading and writing `UserDefaults` stays in the app's `RecentsStore`, because `openspec/config.yaml` says only the app touches `UserDefaults`.
- The last channel is written once its stream loads, not before the load starts. `tvos-shell` "What is remembered" says a stream that fails to load leaves the last channel as it was, and writing first would break that.
- `SessionTracker.load(_:on:options:)` is the one place a live channel loads, on both `LiveModel` and `ShellModel`. Movies and episodes load through `ShelfPlayback` as before; they are not tunes.
- The ten-second count starts when the engine reports playing and stops on any other state, on a new tune, when a movie starts and when the scene goes to the background. Coming back to the app restarts it from zero if the channel still plays. On Mac only the background phase stops it, so a window that loses focus keeps counting.
- Deleting a source clears its channels for every profile on the device, not only the current one.
- The source observer is a view modifier, `SourceDeletions`, on the same `@Query` of source records that feeds Live and the Apple TV shell. It diffs record ids between updates, so a deletion saved here and one imported from iCloud take the same path, and a source missing at launch clears nothing. Tests cover the store and the models it calls; no test drives an iCloud import.
- Recents on screen holds still by keeping two lists: the one the catalogue lists and the newest stored one. On iPhone, iPad and Mac the newer list takes over the next time any group is shown; on Apple TV it takes over unless the overlay is open on Recents.
- Only Recents gets the spoken label "Recents, n channels"; the other group rows keep the labels they had, so existing tests and VoiceOver output for them do not change.
- UI tests start with empty recents in their own defaults suite, and the ten-second count never finishes unless `UITESTING_WATCH_SECONDS` is set, so other screens' tests keep their index-based group identifiers. `UITESTING_RECENTS` seeds recents, and `UITESTING_RECENTS_FILE` and `UITESTING_LAST_CHANNEL_FILE` mirror what the app stores.
- Sources already load from `LiveSync` at the window root, above the tab bar and the columns, so 5.2 needed no move. The last channel plays once Live is on screen and its source has loaded; a session restored to Movies does not start a channel behind it.
- The session's tab is written whenever the tab bar or the iPad and Mac sidebar changes section, and read once when that view first appears. Movies and Series count as present when a stored source is Xtream, read from the source records rather than the shelves, which fill in a moment later.
- The restored group is the last one the user tapped. Search showing All channels to reach a channel, and the fallback to All channels when a group goes, are not written.
- The restore UI tests run on iPhone. The iPad and Mac sidebar uses the same model code, covered by `LiveRestoreTests`; there is no Mac UI test target.
- The Apple TV swipes act only while the full-screen picture has focus, the same place up and down change channel. On the error screen left and right do nothing. Swipe left picks the newest Recents row that is not the playing channel, so two channels watched long enough toggle back and forth. Swipe right brings Recents up to date before the overlay opens, then holds it still while it is open.
- With Reduce Motion nothing slides because the swipes add no animation of their own; the zap bar and the overlay keep the transitions they already had.
- `ShellView` moved to `ShellViewParts.swift` so `ShellView.swift`, which holds `ShellScreen`, stays under the 500-line limit.
- Not drawn: Recents uses the `clock.arrow.circlepath` symbol where Favorites has the star, and the Apple TV channel column says "Newest first" under its heading.
