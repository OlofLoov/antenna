# 0007. Apple TV channel overlay

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0008, 0012, 0013, 0014, 0015
- Platforms: tvOS
- User stories: US-8, US-9, US-12

## Summary

This is for someone watching live TV on an Apple TV who wants to see what else is on without stopping the picture. Pressing select on the remote opens a list over the video: channel groups on the left, the group's channels in the middle, and what is on now and next on the right. The user can tune to a channel, add it to favorites, or jump to search, and the video never stops while they look. It does not cover the info bar shown when changing channel (0008), the full guide grid (0009), or iPhone, iPad and Mac.

## Design

Boards: `docs/design/boards/Main.dc.html`, `Main-Favorites.dc.html`, `Main-FavoritesEmpty.dc.html`, `Main-Empty.dc.html`, `Main-NoProgramme.dc.html`, `Main-GuideLoading.dc.html`.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-6, DR-7, DR-8, DR-11, DR-12, DR-13.
Not drawn: the focused Search row, the focused Watch and favorite buttons, the unfocused catch-up mark and the focused "Loading guide…" row. Each is its drawn counterpart with the focus or muted color applied.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

On a TV, live viewing comes down to one question asked with one remote: what else is on right now? TiviMate answers it with a three-column list laid over the running picture. Antenna on Apple TV opens a plain list and a separate player, so the picture stops whenever the user goes looking for another channel.

## Scope

In:
- A list over the playing video with groups, channels and a now-and-next panel.
- The groups from 0013 with how many channels each has, plus a way into Search.
- The channels of the chosen group in 0013's order.
- What is on now and next for the highlighted channel, from the guide (0014).
- Tuning, closing without tuning, and remembering which group the user last tuned from.
- Adding and removing a favorite.
- A clock.

Out (explicitly):
- The info bar and typing a channel number (0008).
- The guide grid (0009) and the Apple TV home screen (0015).
- How search works (0012); the overlay only opens it.
- Start over and catch-up. The Start over button stays hidden until the catch-up spec is accepted.
- Player controls, error messages and choice of player (playback spec).
- Managing groups.
- iPhone, iPad and Mac browsing (0010).

## User flow

1. A channel plays full screen. The user presses select.
2. The list slides in from the left over the video, which keeps playing. The highlight starts on the channel that is playing.
3. Left moves to the groups, and moving through them changes the channel list. Right comes back to the channels, and moving through them changes the now-and-next panel.
4. Select on a channel tunes to it and closes the list. Right from a channel reaches Watch and the favorite button.
5. Menu closes the list without changing channel. The list never closes by itself.

## Acceptance criteria

### AC-1 The picture keeps playing
Given a channel is playing
When the user presses select
Then the overlay opens and the video carries on without pausing or restarting.

### AC-2 It opens where the user left off
Given a channel is playing and the user last tuned from a group
When the overlay opens
Then that group is chosen and the playing channel is highlighted, or the group's first channel if the playing one is not in it; if the playing channel is gone from the list altogether, All channels is chosen with its first channel highlighted.

### AC-3 Every group, with its size
Given the user has channels in groups and some favorites
When the overlay opens
Then the left column lists Favorites, All channels and every group in the channel list's order (0013), each with how many channels it holds, and ends with a way into Search.

### AC-4 Picking a group shows its channels
Given the highlight is in the group column
When the user moves to another group
Then the middle column shows exactly that group's channels, under a heading with the group's name and how it is sorted ("Your order" for Favorites, by number for the rest).

### AC-5 Each channel shows what is on
Given the overlay is open
When the user looks at the channel list
Then each channel shows its number, logo (or its initials when there is no logo), name, the programme on now with how far in it is, and a mark when catch-up is available; a channel with nothing in the guide says so, one whose guide is still loading says that instead.

### AC-8 Now and next for the highlighted channel
Given a channel is highlighted
When the user looks at the panel on the right
Then it shows the channel's logo, name, number and how many days of catch-up it has, the current programme with its times, time left, progress and description, and up to three programmes that follow; when the guide has nothing for now, the panel says so in place of the current programme.

### AC-9 Select changes channel
Given a channel other than the playing one is highlighted
When the user presses select or chooses Watch
Then that channel starts playing, the overlay closes, the info bar appears, and channel up and down now move through that channel's group.

### AC-9a Select on the playing channel does not restart it
Given the playing channel is highlighted
When the user presses select or chooses Watch
Then the overlay closes and the stream carries on without restarting; a paused stream resumes, and one that failed or never started is loaded again.

### AC-10 Menu closes without changing anything
Given the overlay is open
When the user presses Menu
Then the overlay closes, the same channel keeps playing, channel up and down keep their group, and the press does not also take the user out of the player.

### AC-11 Add or remove a favorite
Given the favorite button is highlighted for a channel
When the user presses select
Then the channel is added to favorites if it was not one, or removed if it was, the button's label says what the next press will do, and the Favorites count goes up or down by one.

### AC-13 Empty groups tell the user what to do
Given the user has no favorites, or no channels at all
When Favorites or All channels is shown
Then the channel column explains how to add a favorite or a source, the panel stays empty, and the highlight cannot move into the empty column.

### AC-23 A way into Search
Given the Search entry is highlighted
When the user presses select
Then the overlay closes, the Search tab opens ready to type, the video carries on as it was, and Menu in Search does not reopen the overlay.

## Edge cases

- 20 000 channels in All channels: the overlay still opens quickly (number in Notes for the plan).
- The same channel or group name in two sources: both are listed, in source order.
- A source whose password is missing on this device adds no channels and no groups.
- Opened while a stream is loading or has failed: the overlay opens over whatever the player shows.
- Removing a favorite while looking at Favorites removes it from the list; the highlight moves to a neighbor, or to the group when none is left.
- Channels or favorites change while the overlay is open: lists and counts update in place, and the highlight stays on the same channel if it still exists, else on the group's first channel; if the group itself is gone, All channels is chosen.
- A programme ends while the overlay is open: the row and panel move on to the next one.
- Very long channel names are cut short with an ellipsis.
- Play/pause while the overlay is open pauses or resumes the video; the overlay stays.
- With Reduce Motion on, the overlay appears without sliding.
- VoiceOver reads a row once as number, name, programme and time left.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | ui |
| AC-3 | ui |
| AC-4 | ui |
| AC-5 | ui |
| AC-8 | ui |
| AC-9 | ui |
| AC-9a | ui |
| AC-10 | ui |
| AC-11 | integration |
| AC-13 | ui |
| AC-23 | ui |

## Open questions

- Hide All channels above some number of channels, as TiviMate users do by hand? Can be decided in the plan.
- A long press on a channel for a menu (favorite, hide, move), or everything through the panel? Can be decided in the plan.
- Remember the last group across launches? Today it resets on a cold launch, as in 0008. Can be decided in the plan.

## Notes for the plan

- Owner's budget: with 20 000 channels in All channels, rows are visible within one second of select on an Apple TV 4K (3rd generation). Manual device check; 0013 bounds the catalogue build.
- Playback criteria are asserted on a fake `PlaybackEngine` injected under a launch argument, which records `load(_:)` calls to a temp file.
- `Channel.streamURL` is never logged, used in an identifier or accessibility label, or shown (ADR-0003).
- Rows are keyed by 0013's `RowKey`, so duplicate channel ids stay distinct.
- Start over stays hidden; panel focus order is Watch then favorite until the catch-up spec lands.
- Remaining-time text uses 0008's formatter; the next list is 0014's query after the current programme's stop, or after now.
- Design deviations: selected-but-unfocused group row on the 0.12 surface at weight 600; muted text on the focused white card uses the "Text muted on focus" token; the accent "Now" eyebrow extends DR-3.
- Exact copy and the full row and panel rules are in this spec as of 5ac1fd1.

## Dropped

- Moved to the implementation plan: AC-14, AC-15, AC-16, AC-17.
- Merged into AC-2: AC-2a.
- Merged into AC-4: AC-12.
- Merged into AC-5: AC-6, AC-7, AC-18, AC-21.
- Merged into AC-8: AC-19, AC-20.
- Merged into AC-9: AC-22.
- Merged into AC-13: AC-2b.
