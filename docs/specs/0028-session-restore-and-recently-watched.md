# 0028. Session restore and recently watched channels

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0002, 0003, 0005
- Builds on specs: 0004, 0006, 0007, 0008, 0010, 0011, 0013, 0015, 0017
- Needs from other specs: 0001 takes the stream link out of M3U channel ids; 0013 adds a Recents group; 0015 reads the last channel from this store and notes its M3U restore is suspended until 0001; 0007 lists Recents after Favorites and opens on a given group; 0008 gives left and right swipes to this spec; 0010 lists Recents after Favorites and shows loading with the restored channel playing; 0011 leaves live before playing a movie or episode.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-17

## Summary

For viewers who keep coming back to the same few channels out of thousands. Once this ships, Antenna on iPhone, iPad and Mac opens where the user left it, on the same tab and group with the same channel playing, even after the system closed the app in the background. Every device gets a Recents group listing the channels watched lately, and on Apple TV a swipe left jumps back to the previous channel while a swipe right opens the channel list on Recents. Recents stay on the device they were watched on; they do not sync, and the user cannot clear them yet. Until 0001 takes the stream link out of M3U channel ids, channels from M3U playlists are not remembered.

## Design

Boards: `docs/design/boards/iPhone-Recents.dc.html`, `docs/design/boards/iPad.dc.html`, `docs/design/boards/Main.dc.html`, `docs/design/boards/iPhone-Loading.dc.html`, `docs/design/boards/iPad-Loading.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13.
Not drawn: the Recents row in the iPad and Mac sidebar; the Recents group row and header in the Apple TV overlay; the iPad Recents list header; the loading screen with the restored channel already playing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

On iPhone, iPad and Mac the app forgets everything at launch: the user lands with nothing playing, in All channels, and has to find the channel they were watching five minutes ago. On every device the channels a user returns to are buried among thousands, and Favorites only helps once the user has curated it. TiviMate users name its recently watched list among the things they like, and returning to the last channel is what every TV does.

## Scope

In:
- A Recents group on every device: the channels watched for at least ten seconds, newest first, up to 20.
- Recents in the group chips on iPhone, in the sidebar on iPad and Mac, and in the Apple TV channel overlay, between Favorites and All channels.
- Reopening iPhone, iPad and Mac where the user left off: the tab, the group and the playing channel, including after the system closed the app in the background.
- On Apple TV during full-screen playback: swipe left for the previous channel, swipe right for the channel overlay opened on Recents.
- Removing a deleted source's channels from Recents and from what is restored, whether it was deleted on this device or another.
- Moving the "last channel" that the Apple TV already restores at launch (0015) into the same on-device store.

Out (explicitly):
- Syncing recents or the restored session between devices.
- Apple TV launching into the last channel; 0015 owns that.
- Restoring the current group on Apple TV at launch.
- Clearing or editing recents, or turning recording off.
- Restoring Search, Settings or a movie detail page.
- Resuming a position inside a movie or episode (0011).
- Separate sessions per window on Mac and iPad; one session is kept, for the first window.
- Recent searches (0012, 0029).
- Top Shelf or Siri suggestions built from recents.
- Reloading channels when a source is added or edited.

## User flow

iPhone, iPad and Mac:
1. The user watches Sport One from the Sport group, switches to the Guide tab, then leaves the app. Hours later the system has closed it.
2. The user opens Antenna. The Guide tab is shown. Tapping Live shows the Sport group selected and Sport One playing, as it was.
3. The groups now read Favorites, Recents, All channels, Sport and so on. Recents lists the channels watched for at least ten seconds, most recent first, Sport One on top.
4. Tapping a row plays it. The list keeps its order while on screen; next time it is opened that channel is on top.

Apple TV:
1. The user has watched channel A, then B, each for more than ten seconds. While B plays full screen, swiping left goes to A; swiping left again goes back to B. Channels skipped past in under ten seconds do not count.
2. Swiping right opens the channel overlay with Recents selected and the first row highlighted.
3. Playing a channel from Recents does not change the group the user was in, so swiping up and down afterwards still steps through that group.

## Acceptance criteria

### AC-1 Recents keep the newest first, each channel once
Given a full Recents list of 20 channels
When the user watches a channel already in the list, and then one that is not
Then the first moves to the top without a duplicate, the second goes on top and the oldest falls off, and the list never holds more than 20.

### AC-2b A channel counts as watched after ten seconds
Given the user has tuned to a channel
When it plays without interruption for ten seconds
Then it appears at the top of Recents; switching channel, playing a movie, leaving the app or the stream stalling before then means it does not count until it plays ten more uninterrupted seconds.

### AC-4 Deleting a source clears its channels
Given recents and a saved session that include channels from a source
When that source is deleted, on this device or on another one through iCloud
Then its channels leave Recents, its channel is no longer restored at launch, a group from that source is no longer restored, and channels from other sources are untouched.

### AC-5 Recents sits between Favorites and All channels
Given the user has watched at least one channel that still exists in a loaded source
When they look at the groups on iPhone, iPad, Mac or in the Apple TV channel overlay
Then Recents appears after Favorites and before All channels, lists only channels that still exist, newest first; with nothing to list, Recents is not shown at all.

### AC-8a The list holds still while you use it
Given the Recents list is on screen
When the user plays a channel from it and keeps watching past ten seconds
Then the rows stay in the order they had, with the new channel highlighted; the next time Recents is opened, that channel is on top.

### AC-9 Playing from Recents keeps your group on Apple TV
Given the user was in group G on Apple TV and opens Recents in the channel overlay
When they play a channel from Recents
Then G stays the current group, so swiping up and down in full screen still steps through G.

### AC-11a Reopen on the same tab and group
Given the user last had a tab and a channel group open on iPhone, iPad or Mac
When they open Antenna again
Then the same tab is shown, and Live shows the same group.

### AC-12 The last channel plays again
Given a channel was playing on iPhone, iPad or Mac when the user left
When they open Antenna and go to Live, and the channel's source has loaded
Then that channel plays again and is highlighted in its list.

### AC-14 Restore survives the system closing the app
Given the user was watching a channel in a group with another tab open
When the system closes Antenna in the background and the user opens it again
Then the tab, the group and the channel come back as in AC-11a and AC-12.

### AC-16a Swipe left for the previous channel
Given full-screen playback on Apple TV with nothing else on screen and at least one other channel in Recents
When the user swipes left
Then the most recent other channel plays and its name shows in the zap bar; swiping left again goes back; with no other channel in Recents nothing happens.

### AC-17 Swipe right opens the channel list on Recents
Given full-screen playback on Apple TV with nothing else on screen
When the user swipes right
Then the channel overlay opens with Recents selected and its first row highlighted, playback carries on, and the current group is unchanged; without Recents the overlay opens as usual.

### AC-20 Links with passwords are never stored
Given an M3U channel whose internal id (Antenna's own reference to the channel) still contains its stream link, which for many providers includes a username and password
When the user watches it
Then it is neither added to Recents nor saved as the channel to restore, and no error is shown; channels from Xtream sources are unaffected.

## Edge cases

- Offline at launch: every source fails, the channel restore waits, and Retry after reconnecting completes it.
- A slow or very large source: the restored group and channel wait for it.
- The restored channel cannot be found: Live shows nothing playing.
- The restored channel's source failed or is waiting for its login to sync: Live shows nothing playing, and the channel plays once the source loads unless the user picked another channel first.
- The restored group no longer exists: Live shows All channels.
- The restored group's source is still loading: All channels shows until it arrives, then the group is selected unless the user picked one meanwhile.
- Last on Search or Settings, or on Movies or Series with no source that has them: Antenna opens on Live.
- The selected group disappears while Live is on screen: All channels is shown and the playing channel carries on.
- A provider changes a channel's identity: it drops out of Recents and ages out of the store.
- Two channels with the same identity in one source: neither is listed in Recents.
- Damaged stored data: Antenna starts with empty recents and no restore, without an error.
- Until the 0001 follow-up removes stream links from M3U channel identities, no M3U channel is listed in Recents or restored (AC-20).
- If the paid unlock lapses (ADR-0006), recents are kept and come back when it returns.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core |
| AC-2b | integration |
| AC-4 | core + integration |
| AC-5 | core + ui |
| AC-8a | ui |
| AC-9 | ui |
| AC-11a | ui |
| AC-12 | ui |
| AC-14 | ui |
| AC-16a | ui |
| AC-17 | ui |
| AC-20 | core |

## Open questions

- Recents do not sync, because two Apple TVs in one home would overwrite each other and M3U identities would carry credentials through iCloud. 0029 syncs recent searches; syncing recents too would change AC-1 and AC-5 and needs an ADR.
- Restore plays the channel at launch, including on cellular. Showing it selected with a play button instead would change AC-12. Answer before Accepted.
- Decided: the Recents group hides when empty rather than showing an empty state as Favorites does (AC-5).
- Swipe left toggles between two channels and swipe right opens Recents (AC-16a, AC-17). A long press, or stepping back through all of Recents, would change those criteria.
- AC-20 stops M3U channels being restored, on Apple TV too, until the 0001 follow-up. Storing a hash of the identity now would lift that and change 0015's stored value.
- Apple TV still forgets the current group at launch (0008). Restoring it needs a change to 0008.

## Notes for the plan

- Storage is on-device `UserDefaults`, no SwiftData, no sync (ADR-0005). Keys: `recents.list`, `recents.session`, and `shell.lastChannel` with exactly the payload 0015 asserts. `LastChannelKey` (source id, channel id) moves into AntennaCore. The session holds tab and group only; the last channel has one home.
- Every live tune on every device goes through one session tracker, which writes the last channel before the engine loads it and keeps it if the load fails; no other app code calls the engine's load. Playing a movie or episode is not a tune and cancels the ten-second count. Leaving the app, a new tune, or the engine leaving playing also cancel it.
- A source observer watches local saves and remote changes on the app container, diffs source ids, and for each removed id clears the store, stops the count if the playing channel was in it, then asks for a catalogue rebuild. Only an observed deletion counts, not a missing record.
- The store refuses any channel id containing `://` (AC-20). Remove the filter, and move AC-20 to Dropped, in the 0001 follow-up that hashes the stream URL out of `Channel.id`. Ids are never logged or put in an identifier, label or error (ADR-0003).
- Only a group the user picks is written to the session; groups the app selects as a fallback are shown but not written.
- Live sources start loading when the app's root appears, not when Live is first shown, so a session restored to another tab has channels ready.
- 0013 gains a Recents group kind and a way to replace it without rebuilding the catalogue, within 0013's time bound; a channel id matching two channels does not resolve.
- Details for the Needs from other specs amendments: Recents never becomes the current group in 0007; the previous-channel swipe keeps the current group in 0008; 0013's group counts include Recents. Recents shows its count on iPad, Mac and Apple TV.
- Adding Recents shifts the index-based identifiers of later groups by one; 0007 and 0010 UI tests run with empty recents. XCUITest cannot read the app's defaults, so a debug build mirrors last-channel writes to a file beside the fake engine log.
- VoiceOver reads the Recents group as "Recents, n channels". With Reduce Motion the swipes do not slide.

## Dropped

- Split earlier (kept for history), each to separate scenarios that fail for different reasons: AC-2 into AC-2a, AC-2b, AC-2c, AC-2d, AC-2e and AC-2f; AC-8 into AC-8a and AC-8b; AC-11 into AC-11a, AC-11b, AC-11c, AC-11d, AC-11e, AC-11f and AC-11g; AC-13 into AC-13a and AC-13b; AC-16 into AC-16a, AC-16b, AC-16c and AC-16d; AC-18 into AC-18a and AC-18b.
- Trimmed earlier: AC-10's "never written only on termination" was untestable; AC-17's surface color and AC-20's "nothing is logged" were left to review.
- Merged into AC-2b: AC-2c, AC-2e, AC-2f.
- Merged into AC-4: AC-21.
- Merged into AC-5: AC-6a, AC-6b, AC-6c, AC-7.
- Merged into AC-8a: AC-8b.
- Merged into AC-11a: AC-10.
- Moved to Edge cases: AC-11b, AC-11c, AC-11d, AC-11e, AC-11f, AC-13a, AC-13b, AC-15.
- Merged into AC-12: AC-2a.
- Merged into AC-16a: AC-16b, AC-16c.
- Moved to the implementation plan: AC-2d, AC-3, AC-11g, AC-16d, AC-18a, AC-18b, AC-19.
