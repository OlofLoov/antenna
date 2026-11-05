# 0008. Apple TV zap bar and channel number entry

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0007, 0013, 0014, 0015, 0017
- Platforms: tvOS
- User stories: US-8, US-9

## Summary

This is for someone flipping channels on an Apple TV. Every time the channel changes, an info bar (the "zap bar") along the bottom of the picture says which channel this is, what is on, how far in it is and what comes next, then gets out of the way after a few seconds. Swiping up or down on the remote moves to the next or previous channel in the same group, and anyone with a keyboard that has number keys can type a channel number to jump straight to it. It does not add player controls, rewinding, catch-up, or typing channel numbers with anything but a keyboard.

## Design

Boards: `docs/design/boards/TV-ZapBar.dc.html`, `TV-ZapBar-Hidden.dc.html`, `TV-ZapBar-NoProgramme.dc.html`, `TV-ZapBar-GuideLoading.dc.html`, `TV-ZapBar-GuideUnavailable.dc.html`, `TV-ZapBar-NoNext.dc.html`, `TV-ZapBar-NoCatchup.dc.html`, `TV-ZapBar-Favorites.dc.html`, `TV-ZapBar-AllChannels.dc.html`, `TV-ZapBar-PillNoMatch.dc.html`, `TV-ZapBar-PillZeros.dc.html`, `TV-ZapBar-PillNoChannel.dc.html`, `TV-ZapBar-EndsNow.dc.html`, `TV-ZapBar-Buffering.dc.html`, `TV-ZapBar-LiveOnly.dc.html`.
Design rules that apply: DR-1, DR-3, DR-4, DR-7, DR-8, DR-11, DR-12, DR-13.
Not drawn: nothing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Flipping channels on a TV needs a glance of information without leaving the picture: which channel this is, what is on, how far in, what is next. Antenna's Apple TV player shows nothing. TiviMate shows an info bar on every channel change and lets remotes with number keys jump straight to a channel.

## Scope

In:
- An info bar on every channel change and on request, which hides by itself.
- What it shows: logo, number, name, group and position in it, the current programme with its times and progress, the next programme, time left, and picture and sound quality.
- Swiping up and down to change channel within the current group. The current group is the one the user last tuned from in the overlay, or the channel's own group after a fresh launch.
- Play/pause in full-screen live TV shows the bar instead of pausing (a later playback spec may change this).
- Typing a channel number on a hardware keyboard, with correcting and cancelling.

Out (explicitly):
- The channel overlay (0007), guide (0009) and Apple TV home screen (0015).
- Player controls, rewinding, catch-up and start over.
- Choosing audio and subtitle tracks.
- Messages for streams that fail (playback spec).
- Channel numbers from TV remotes or game controllers.
- Changing group by swiping left or right; groups change in the overlay (0007).

## User flow

1. The user changes channel by any means. The bar appears at the bottom and hides after five seconds.
2. With the bar hidden, play/pause shows it again without changing channel. Menu hides it.
3. Swiping up or down moves to the next or previous channel in the group, and the bar shows the new one.
4. Select while the bar shows hides it and opens the channel overlay (0007).
5. On a keyboard, typing a number shows a small box with the digits and the matching channel's name. Two seconds after the last digit, or on Return, Antenna tunes to it. If no channel has that number, the box says so for a second.

## Acceptance criteria

### AC-1 The bar appears on every channel change
Given a channel is playing with the bar hidden
When the channel changes by any means
Then the bar shows the new channel and what is on straight away, and hides five seconds after the last channel change.

### AC-2 Play/pause shows the bar
Given a channel is playing full screen
When the user presses play/pause
Then the bar shows, or stays five more seconds if it was already showing, and the video keeps playing; a half-typed channel number is dropped first.

### AC-3 Menu hides the bar
Given the bar is showing
When the user presses Menu
Then the bar hides, the video keeps playing full screen, and the press does not also take the user out of the player.

### AC-4 Which channel this is
Given channel 104 "Sport One" is the fourth of 42 in the group Sport
When the bar shows
Then it shows the logo (or initials), "104", "Sport One" and "Sport · 4 of 42"; in Favorites and All channels it names that list instead.

### AC-5 What is on and what is next
Given the guide has a programme on now for the channel
When the bar shows
Then it shows the programme's title, start and end times, how far in it is, the next programme's time and title, and time left ("26 min left", "1 h 34 min left", or "Ends now" in its last minute); when the guide has nothing for now, is still loading or failed, the bar reads "No programme information", "Loading guide…" or "Guide unavailable" (the same words as the guide grid) and shows no progress or next programme.

### AC-7 Picture and sound quality
Given a channel is playing
When the bar shows
Then a LIVE badge shows only while the stream is playing, and once the player reports them, the picture size (4K, 1080p, 720p) and the sound (for example "AAC 5.1"); while buffering, these badges are absent.

### AC-8 Catch-up hint
Given the channel offers catch-up for 7 days
When the bar shows
Then the footer reads "Catch-up 7 days" ("Catch-up" when the provider gives no number); without catch-up, the footer only says "Press to browse channels".

### AC-9 Swipe up and down to change channel
Given the fourth of 42 channels in the current group is playing
When the user swipes up
Then the fifth channel plays and the bar reads "5 of 42"; swiping past either end wraps round to the other.

### AC-10 Typing a number shows the match
Given a channel is playing and a hardware keyboard is connected
When the user types a digit
Then the bar hides, a small box shows the digits typed and the name of the channel they match (blank when nothing matches), and the video keeps playing.

### AC-11 The typed channel tunes
Given the box shows "104" and channel 104 exists
When two seconds pass without another digit, or the user presses Return or select
Then channel 104 plays, the box goes away, and the bar shows the new channel.

### AC-13 No channel with that number
Given the box shows "999" and no channel has that number
When two seconds pass or the user presses Return or select
Then the box reads "No channel 999" for a second and goes away, and the same channel keeps playing.

### AC-19 Correct or cancel a number
Given the box shows "10"
When the user presses Backspace, or Menu or Escape
Then Backspace removes the last digit and gives two more seconds (an empty box goes away), and Menu or Escape closes the box without tuning or leaving the player.

## Edge cases

- A programme ends while the bar shows: the bar moves on to the next one.
- A group with one channel: swiping shows the bar again for the same channel.
- Swiping again while a channel is still loading skips straight to the next one. Swiping while the number box shows closes the box first.
- The playing channel leaves its group after a refresh: the bar counts it within All channels.
- Leading zeros: "0104" finds channel 104.
- Typing digits while the overlay or guide is open does nothing.
- Fast channel flipping: the bar updates in place and hides five seconds after the last change.
- A stream that fails or keeps buffering: the bar still shows the channel and programme, without the LIVE and quality badges.
- No channels at all: any typed number ends as "No channel n".
- Reduce Motion: the bar and the number box appear without animation.
- VoiceOver reads the channel, programme and time left once when the bar appears.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | ui |
| AC-3 | ui |
| AC-4 | ui |
| AC-5 | core + ui |
| AC-7 | core + ui |
| AC-8 | ui |
| AC-9 | ui |
| AC-10 | integration |
| AC-11 | integration |
| AC-13 | integration |
| AC-19 | integration |

## Open questions

- Should the five-second delay be a setting? If it syncs, it needs a `SettingsRecord` field and an ADR (ADR-0002). Can be decided in the plan.
- Decided: swiping left or right does not change the group; the user changes group in the channel overlay (0007).

## Notes for the plan

- Needs 0017 for an observable engine state and a `PresentationInfo` stream (video height, audio channels, codec). Until then AC-7 runs against a fake engine.
- Remaining-time text, progress fraction (clamped to 0...1, full for a zero or negative duration) and the badge mappings are pure AntennaCore functions; 0007's panel uses the same formatter. Minutes round up; under 60 s, including zero and negative, is "Ends now".
- Resolution: at least 2160 "4K", 1080 "1080p", 720 "720p", lower absent. Audio: 8 "7.1", 6 "5.1", 2 "Stereo", 1 "Mono", other counts absent, codec prefix when known. Their arrival does not restart the hide timer.
- Current group: a tune from the overlay's column for group H makes H current (0007). Tuning by number, search, guide or onboarding to a channel outside the current group keeps the group and the position reads "All channels · n of m". At cold launch the current group is 0013's `sourceGroup(of:)`.
- Number entry: digits beyond the longest channel number in 0013's index (never fewer than four) are ignored; matching uses 0013's index. "No channel n" lasts one second ±100 ms on the injected clock.
- Select while the bar or box shows is consumed: the bar hides before the overlay opens, and select in the box tunes.
- No clock in full-screen playback; the clock belongs to the overlay and the shell. Remaining text and progress refresh each minute.
- The bar and box never take focus. `Channel.streamURL` is never shown, logged or used in an identifier (ADR-0003).
- Design: `TV-ZapBar.dc.html` is a composite; the box and bar are never on screen together, and the state boards are authoritative. The 132 by 88 identity tile uses radius 12, above the logo-tile range. Digit entry is narrowed to hardware keyboards per `docs/design/README.md` section 2.
- Digit handling lives in a model with injected key events and clock, since XCUITest cannot type into a non-text view on tvOS.

## Dropped

- Moved to the implementation plan: AC-15b, AC-16, AC-18, AC-20.
- Merged into AC-5: AC-6a, AC-6b, AC-6c.
- Merged into AC-9: AC-15a, AC-15c.
- Merged into AC-10: AC-14, AC-17.
- Merged into AC-11: AC-12.
