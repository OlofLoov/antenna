# 0008. Apple TV zap bar and channel number entry

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: tvOS
- Builds on specs 0013 (position in group, digit matching, source group), 0014 (guide queries), 0015 (shell, full-screen playback), 0007 (overlay opens on select; 0007/AC-22 commits the current group).
- Blocked on the playback engine spec (not yet written) for an observable state and a `PresentationInfo` stream (video height, audio channels, audio codec). AC-7 and AC-14 are tested with a fake engine until then; the protocol change is a dependency, not made here.

## Design

Boards: `docs/design/boards/TV-ZapBar.dc.html` and the `TV-ZapBar-*.dc.html` state boards beside it.
Design rules that apply: DR-1, DR-3, DR-4, DR-7, DR-8, DR-11, DR-12, DR-13.
States on the boards: `TV-ZapBar.dc.html` is the bar visible over live video with identity, now playing (78%, 26 min left), next ("22:00 · Match of the Day"), badges ("LIVE", "1080p", "AAC 5.1"), catch-up footer and the hint "Press to browse channels", with the entry pill top left mid-entry drawn on the same frame. `TV-ZapBar.dc.html` is a composite for layout: the pill and the bar are never on screen together (AC-17) and the clock is never rendered in full-screen playback (AC-20); the state boards are authoritative for what is on screen. Digit entry is narrowed to hardware keyboards, as `docs/design/README.md` section 2 says.
State boards, one frame each, in the muted 22 pt style of the now section unless stated: hidden state, nothing but video (`TV-ZapBar-Hidden.dc.html`); "No programme information" (`TV-ZapBar-NoProgramme.dc.html`), "Loading guide…" (`TV-ZapBar-GuideLoading.dc.html`) and "Guide unavailable" (`TV-ZapBar-GuideUnavailable.dc.html`) bars, each with no progress bar, Next line or remaining text; now section with no Next line when 0014/AC-5 returns nothing, the remaining text kept at the right of its row (`TV-ZapBar-NoNext.dc.html`); footer without catch-up (`TV-ZapBar-NoCatchup.dc.html`); "Favorites · 4 of 9" (`TV-ZapBar-Favorites.dc.html`) and "All channels · 131 of 1312" (`TV-ZapBar-AllChannels.dc.html`) in the 20 pt position label of the base board; pill with no match (`TV-ZapBar-PillNoMatch.dc.html`) and zeros-only pill (`TV-ZapBar-PillZeros.dc.html`), 44 pt digits with the name empty, bar hidden per AC-17; "No channel 999" pill at 22 pt, same height as the digits pill (`TV-ZapBar-PillNoChannel.dc.html`); "Ends now" with the progress bar full (`TV-ZapBar-EndsNow.dc.html`); bar while buffering, no LIVE and no format badges, badge row kept at its height (`TV-ZapBar-Buffering.dc.html`); bar while `.playing` before `PresentationInfo` arrives, LIVE badge alone at 18 pt, badge row kept at its height (`TV-ZapBar-LiveOnly.dc.html`).
Deviations: the 132 by 88 identity tile uses radius 12, above the 6 to 8 logo-tile range, because it is the largest logo tile in the app.

## Problem

Flipping channels on a TV needs a glance of information without leaving the picture: what channel this is, what is on, how far in, what is next. Antenna's tvOS player shows nothing. TiviMate shows an info bar on every channel change and lets remotes with digits jump straight to a number.

## Scope

In:
- Zap bar shown on every channel change and on demand, auto-hiding.
- Contents: logo, number, name, group and position, current programme with times and progress, next programme, remaining time, badges.
- Channel up and down within the current group with swipe up and down while watching.
- Definition of the current group and its label.
- In full-screen live playback the play/pause button is consumed by the bar and never reaches the engine; a later playback spec may supersede this.
- Channel number entry from hardware keyboard digit key events, with editing and cancellation.
- Accessibility identifiers with prefix `zapBar.`.

Out (explicitly):
- The channel overlay (0007), guide (0009), shell (0015).
- Player transport controls, scrubbing, catch-up and start over.
- Audio and subtitle track selection.
- Error display for failed playback (playback spec).
- Number entry from HDMI-CEC remotes or game controllers.

## User flow

1. The user tunes to a channel by any means. The bar appears at the bottom and hides five seconds later.
2. While watching with the bar hidden, pressing play/pause shows the bar for five seconds without changing the channel. Menu hides it.
3. Swiping up or down while watching, bar visible or not, tunes to the next or previous channel in the current group; the bar shows for the new channel.
4. Select while the bar is visible hides the bar and opens the overlay (AC-18, 0007/AC-1).
5. On a hardware keyboard, pressing a digit shows the entry pill top left with the digits typed and the name of the best match. Two seconds after the last digit, or on Return, the match is tuned. With no match, the pill reads "No channel 999" for a second. Menu, Escape or Backspace edit or cancel it.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1 Shown on every channel change
Given a channel is playing with the bar hidden
When playback switches to another channel by any means
Then the bar (`zapBar.root`) shows the new channel's identity and now section before the engine's `load` returns and hides five seconds later on the injected clock; the timer restarts on any channel change (including AC-9 and AC-11) and on AC-2's press, and on nothing else (engine updates per AC-7, the minute refresh per AC-16).

### AC-2 Shown on demand
Given a channel is playing
When the user presses play/pause
Then with the bar hidden it is shown for the current channel and hides five seconds later; with the bar visible the five seconds restart and nothing else changes; with the pill visible, the pill is removed first without tuning and the bar is then shown for the current channel; the engine state is unchanged in every case.

### AC-3 Menu hides
Given the bar is visible
When the user presses Menu
Then `zapBar.root` is absent, the engine state is unchanged, the app stays in full-screen playback, and Menu is consumed (0015/AC-3 does not fire).

### AC-4 Identity section
Given channel 104 "Sport One", fourth of 42 in current group "Sport" (0013/AC-13)
When the bar is rendered
Then `zapBar.logo` shows the logo or initials tile (0013/AC-7), `zapBar.number` "104", `zapBar.name` "Sport One" and `zapBar.position` "Sport · 4 of 42"; in Favorites the label reads "Favorites · n of m", in All channels "All channels · n of m".

### AC-5 Now playing section
Given a current programme 20:00 to 22:00 and now 21:34
When the bar is rendered
Then `zapBar.title` shows the title, `zapBar.times` the start and stop in the locale short time style separated by an en dash, `zapBar.progress` a fraction equal to elapsed over duration within 0.01 (0.78), clamped to 0...1 and full for a zero or negative duration, `zapBar.next` "Next" with the next programme's locale start time, " · " and title (absent when 0014/AC-5 returns nothing), and `zapBar.remaining` the core formatter's text for `stop − now`: 60 s or more, minutes rounded up, "26 min left", and from 60 minutes "1 h 34 min left"; under 60 s, including zero and negative, "Ends now". 0007/AC-19 uses the same formatter.

### AC-6a No programme
Given a channel whose `loadingState` is `.loaded` or `.noData` with `current(for:at:)` nil, or `.unavailable`
When the bar is rendered
Then the now section shows "No programme information", no progress bar, no Next line and no remaining text.

### AC-6b Guide loading
Given a channel whose `loadingState` is `.loading`
When the bar is rendered
Then the now section shows "Loading guide…" with no progress bar, Next line or remaining text.

### AC-6c Guide failed
Given a channel whose `loadingState` is `.failed`
When the bar is rendered
Then the now section shows "Guide unavailable" (same text as 0009/AC-12) with no progress bar, Next line or remaining text.

### AC-7 Badges from the engine
Given the engine's state and `PresentationInfo`
When the bar is rendered
Then `zapBar.badge.live` is present only while the engine state is `.playing`; `zapBar.badge.resolution` reads the core mapping of the reported height (at least 2160 "4K", at least 1080 "1080p", at least 720 "720p", lower absent); `zapBar.badge.audio` reads the channel-count mapping (8 "7.1", 6 "5.1", 2 "Stereo", 1 "Mono", any other count absent) prefixed with the codec name when known ("AAC 5.1"); before `PresentationInfo` arrives both format badges are absent, and their arrival does not restart AC-1's timer.

### AC-8 Catch-up footer
Given `hasCatchup` true with `catchupDays` 7
When the bar is rendered
Then `zapBar.catchup` shows the catch-up glyph and "Catch-up 7 days"; with `hasCatchup` true and `catchupDays` nil or 0 it shows "Catch-up"; with `hasCatchup` false the footer shows only `zapBar.hint` "Press to browse channels".

### AC-9 Channel up and down
Given the fourth of 42 channels in the current group is playing
When the user swipes up
Then playback switches to the fifth channel and the bar shows "5 of 42" (AC-1); swiping down from the first channel wraps to the last and swiping up from the last wraps to the first; a swipe while a tune is still loading cancels that load and starts the next; a swipe while the pill is visible removes the pill first.

### AC-10 Digit entry shows the pill
Given a hardware keyboard sends the digit "1"
When the key is pressed
Then `zapBar.entryPill` appears top left with `zapBar.entryPill.digits` "1" and a cursor and `zapBar.entryPill.name` the name of 0013/AC-12's match, empty when there is no match or only zeros are typed; a digit beyond the length of the longest channel number in 0013's index (never fewer than four) is ignored and the typed digits stay.

### AC-11 Digit entry tunes after a pause
Given the pill shows "104" and 0013/AC-12 matches channel 104
When two seconds pass on the injected clock with no further digit
Then playback switches to channel 104, the pill is removed, and AC-1 shows the bar.

### AC-12 Return or select tunes immediately
Given the pill shows "10" and 0013/AC-12 matches channel 10
When the user presses Return or select
Then playback switches to the match, the pill is removed without waiting, and select is consumed (0007/AC-1 does not fire).

### AC-13 No such channel
Given the pill shows "999" and 0013/AC-12 returns nil
When two seconds pass or the user presses Return or select
Then the pill reads "No channel 999" for one second on the injected clock (±100 ms), is then removed, and the playing channel and engine state are unchanged.

### AC-14 Digit entry does not stop video
Given a channel is playing
When digits are entered and the pill is visible
Then the engine state stays `.playing` and no `pause()` is called until the new channel is tuned.

### AC-15a Current group after an overlay tune
Given the current group is G
When the user tunes from the overlay's column for group H (0007/AC-22)
Then the current group becomes H.

### AC-15b Current group after other tunes
Given the current group is G
When the user tunes by number, search, guide or onboarding to a channel not in G
Then the current group stays G, `zapBar.position` reads "All channels · n of m" and AC-9 steps through All channels; for a channel in G the position reads against G.

### AC-15c Current group at launch
Given a cold launch playing channel C
When the bar is rendered
Then the current group is `sourceGroup(of: C)` (0013/AC-16), so a nil-group channel reads against its source's Ungrouped group.

### AC-16 Minute refresh
Given the bar is visible across a minute boundary
When the injected clock advances one minute
Then the remaining text and progress fraction update within one second.

### AC-17 Digits hide the bar
Given the bar is visible
When a digit is pressed
Then the bar is hidden and the pill is shown.

### AC-18 Select while visible
Given the bar is visible
When the user presses select
Then the bar is hidden before the overlay is presented, the engine state is unchanged, and 0007/AC-1 applies as if the bar had been hidden.

### AC-19 Pill cancellation and editing
Given the pill shows "10"
When the user presses Menu or Escape
Then the pill is removed, no tune occurs and Menu is consumed (0015/AC-3 does not fire); Backspace removes the last digit and restarts the two seconds, and an empty pill is removed.

### AC-20 No clock in full screen
Given full-screen playback with or without the bar
When rendered
Then no clock is shown; the clock belongs to the overlay (0007/AC-15) and the shell (0015/AC-7).

## Edge cases and failure modes

- Programme boundary while visible: the now section switches to the programme now current, or AC-6a, within five seconds.
- Group with one channel: swipe up or down re-shows the bar for the same channel.
- Current channel removed from its group by a refresh: AC-15b's All channels reading applies.
- Leading zeros: "0104" matches 104 (0013/AC-12).
- Pill while the overlay (0007) or guide (0009) is open: digits are ignored.
- Rapid channel flipping: the bar updates in place; one timer.
- Failed or buffering tune: the bar still shows with metadata; LIVE and format badges are absent until the engine reports `.playing` (AC-7).
- Zero channels loaded: digit entry always ends in AC-13.
- Prefix matching and position lookup run against 0013's precomputed index.
- The bar and pill are never focusable; focus stays on the player. Swipe and directional click are equivalent.
- `Channel.streamURL` is never shown, logged or used in an identifier (ADR-0003).
- Show and hide: the bar slides in and out at the bottom edge over 0.25 s; the pill fades; Reduce Motion replaces both with no animation.
- VoiceOver: the bar is announced once when shown with channel, programme and remaining time.

## Test plan

Remaining-time text, progress fraction and the badge mappings are pure functions in AntennaCore. Timers use an injected clock. Digit handling lives in a `@MainActor` entry model with injected key events and clock (XCUITest cannot type into a non-text view on tvOS); UI tests assert the pill's presence and contents. Identifiers: `zapBar.root`, `zapBar.logo`, `zapBar.number`, `zapBar.name`, `zapBar.position`, `zapBar.title`, `zapBar.times`, `zapBar.progress`, `zapBar.next`, `zapBar.remaining`, `zapBar.badge.live`, `zapBar.badge.resolution`, `zapBar.badge.audio`, `zapBar.catchup`, `zapBar.hint`, `zapBar.entryPill`, `zapBar.entryPill.digits`, `zapBar.entryPill.name`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1 | ui (injected clock) | TBD |
| AC-2 | ui (fake engine) | TBD |
| AC-3 | ui | TBD |
| AC-4 | ui | TBD |
| AC-5 | core (formatter, fraction) + ui | TBD |
| AC-6a | ui (fake GuideStore) | TBD |
| AC-6b | ui | TBD |
| AC-6c | ui | TBD |
| AC-7 | core (mappings) + ui (fake engine) | TBD |
| AC-8 | ui | TBD |
| AC-9 | ui | TBD |
| AC-10 | integration (entry model) + ui | TBD |
| AC-11 | integration (injected clock) | TBD |
| AC-12 | integration | TBD |
| AC-13 | integration (injected clock) | TBD |
| AC-14 | integration (fake engine) | TBD |
| AC-15a | core (current-group rule) + ui | TBD |
| AC-15b | core + ui | TBD |
| AC-15c | core + ui | TBD |
| AC-16 | ui (injected clock) | TBD |
| AC-17 | integration + ui | TBD |
| AC-18 | ui | TBD |
| AC-19 | integration | TBD |
| AC-20 | ui | TBD |

## Open questions

- Should the auto-hide delay be a setting? If synced, it is a `SettingsRecord` field and requires an ADR (ADR-0002).
- Should swiping left or right change the current group?
