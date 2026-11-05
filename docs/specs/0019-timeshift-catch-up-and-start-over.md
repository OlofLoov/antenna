# 0019. Timeshift buffer, catch-up and Start over

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Builds on specs: 0001, 0003, 0004, 0007, 0008, 0009, 0010, 0013, 0014, 0015, 0017, 0018
- Blocked on: ADR for where the timeshift buffer lives and how big it is. Assumed meanwhile: files in the app cache, 60 minutes, 4 GB Apple TV and Mac, 2 GB iPhone and iPad.
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-7, US-14

## Summary

This is for anyone, sports fans most of all, who wants to pause live TV, rewind a few minutes, or start a programme from the beginning. Once it ships, pressing pause on a live channel freezes the picture while the app keeps recording, so the user can resume, skip back and forward, scan (fast-forward or rewind while held), and jump back to live, up to an hour behind. Start over plays the current programme from its beginning, through the provider's catch-up (recent programmes the provider keeps on its servers) where the channel has one, or from the app's own recording otherwise. It does not let the user browse and play past programmes from the guide, and it does not keep recordings.

## Design

Boards: `docs/design/boards/TV-ZapBar-Timeshift.dc.html`, `docs/design/boards/iPhone-Player-Timeshift.dc.html`, `docs/design/boards/Main.dc.html` (the Start over button in the overlay).
Design rules that apply: DR-1, DR-3, DR-4, DR-5, DR-7, DR-11, DR-12, DR-13.
Not drawn: the two-row strip on iPad and Mac and in full screen; the notice pill; catch-up playback with its CATCH-UP badge; the gap after background; the rewind row at the live edge while playing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Live TV in Antenna cannot be paused, rewound or restarted. TiviMate holds about two minutes of pause and cannot skip inside it, and its users rank a real rewind buffer second on their wish list. Many providers offer catch-up (replaying recent programmes from their servers), and Antenna already reads which channels have it, but nothing plays it.

## Scope

In:
- Recording the playing live channel to a local buffer from the moment it is tuned, up to 60 minutes or a storage cap, whichever comes first.
- Pause, resume where paused, skip back 15 seconds and forward 30, scan by holding (Apple TV) or dragging (touch and mouse), and return to live.
- Reading the catch-up details playlists carry (`catchup`, `catchup-source`, `catchup-correction`) and Xtream's archive flag and server time zone.
- Building catch-up addresses for the common playlist styles (`default`, `append`, `shift`, `flussonic`, `xc`) and for Xtream accounts.
- Start over for the programme on air now, by catch-up first and the local buffer second.
- Skipping within a catch-up programme, and returning to live when it ends.
- What happens when the buffer fills, storage is short, catch-up fails, the app goes to the background, or the stream cannot be recorded.
- The rewind row in the Apple TV zap bar and a two-row control strip on iPhone, iPad and Mac.

Out (explicitly):
- Playing earlier programmes from the guide, the overlay's upcoming list or search, and the guide's own Start over: a catch-up browsing spec.
- Keeping recordings.
- The `vod` catch-up style and XMLTV (guide file) catch-up ids.
- Catch-up for Stalker, Jellyfin and Channels DVR.
- Player controls other than moving in time: 0018.
- Picture in Picture and background audio themselves: 0018.
- Skip lengths as a setting.
- Fast playback with sound (2x, 4x).

## User flow

Apple TV:
1. A channel plays full screen. The user presses play/pause. The picture freezes and the zap bar shows a rewind row; the marker drifts left as live TV moves on.
2. Play/pause again continues from where it froze. The bar says how far behind live the picture is.
3. Clicking left skips back 15 seconds, right forward 30. Holding scans fast until released. Reaching now returns to live.
4. Holding play/pause jumps to live.
5. The overlay shows Start over when the programme can be restarted. Selecting it plays the programme from the beginning.
6. Changing channel starts a fresh buffer for the new one.

iPhone, iPad and Mac:
1. Tapping pause shows a scrubber with the marker at the right.
2. Play resumes from the paused point. Skip buttons move 15 seconds back and 30 forward. Dragging the marker seeks on release.
3. Tapping LIVE while behind returns to live. Tapping Start over restarts the programme.
4. With a keyboard, Left and Right skip.

## Acceptance criteria

### AC-1 Catch-up asks the provider the way it expects
Given channels with each supported catch-up style (default, append, shift, flussonic, xc, Xtream archive)
When Start over plays catch-up for the current programme
Then the app requests the programme's start and length in that style, in the provider's time zone where it gives one; with details missing, malformed, out of the kept days, or a login or time zone not yet known, it requests nothing and Start over falls back to the buffer.

### AC-10 Pause live TV and pick up where you left off
Given a live channel playing at now on a stream that can be recorded
When the user presses pause (remote, on-screen button or lock-screen control), waits, and presses play
Then the picture freezes while recording goes on, the bar or strip shows the paused time, "<n> min behind" (rounded up) and a marker placed between the start of the buffer and now; it stays visible while paused; the programme shown is the one at the picture's time, paused or playing behind live; play continues from the frozen frame with no reload.

### AC-12 Skip, scan and drag
Given a channel playing ten minutes behind live
When the user clicks left or right on the Apple TV remote, holds left or right, taps the skip buttons, drags the marker, or presses the arrow keys with the player focused
Then a click or tap moves 15 seconds back or 30 forward; holding scans at 60 times real time and seeks once on release; dragging moves the shown time with the finger and seeks once on release; nothing goes before the start of the buffer; reaching now returns to live as in AC-13; on Apple TV, while the overlay, number entry or guide is open, left and right keep their usual meaning.

### AC-13 Back to live
Given a channel playing or paused behind live, or a catch-up programme playing
When the user holds play/pause for half a second on Apple TV, taps the LIVE badge elsewhere, or skips, scans or drags to now
Then the picture is live, the LIVE badge shows its red dot and the "behind" text is gone; from catch-up it reloads the live channel and starts a new buffer; while behind live the Apple TV zap bar hint reads "Hold play/pause for live" and the LIVE badge elsewhere is tappable.

### AC-14 When the buffer runs out
Given a channel paused or playing behind live
When the pause outlasts the hour, or the storage cap pushes the start of the buffer up to the paused point
Then playback resumes from the earliest point still kept, the marker sits at the left end, and a notice says "Buffer full. Playing from the earliest point".

### AC-19 Start over shows only when it can work
Given the Apple TV overlay focused on the playing channel, or the touch control strip, and a programme on air now
When it is shown
Then Start over appears when a catch-up address can be built or the buffer reaches back to the programme's start, and is absent with no programme, no catch-up and too short a buffer, or for any channel other than the one playing; it appears or disappears within five seconds when the buffer, the programme, the login or the server time zone changes.

### AC-20 Start the programme from the beginning
Given Start over shown for programme P
When the user selects it
Then with catch-up the catch-up address plays, the bar shows a "CATCH-UP" badge and P's start time moving on, skips reload the catch-up address at the new time, and the live buffer is dropped once catch-up plays; without catch-up the buffer jumps to P's start with no reload; at the end of the catch-up stream, or a skip past now, it returns to live by itself.

### AC-33 When the provider's catch-up fails
Given Start over through catch-up for programme P
When the catch-up stream fails to start
Then the live channel returns with its buffer, at P's start if the buffer has it, otherwise saying "Start over isn't available for this programme".

### AC-24 Changing channel starts fresh
Given a channel paused or playing behind live
When the user changes channel by any means
Then the new channel plays at live with its own new buffer, the old buffer is deleted without slowing the change, and buffers left over from an earlier run of the app are deleted at launch without being read.

### AC-25 Leaving the app, calls and other interruptions
Given a channel on any platform
When the app goes to the background without Picture in Picture or background audio, a call or Siri interrupts, the Mac sleeps, or another tab in the app pauses playback
Then a pause the user made keeps its place, and if the recording has a gap the picture plays to the gap and then jumps to live with "Skipped ahead to live"; a channel that was playing at live comes back at live with a fresh buffer and no notice; a channel playing behind live by the user's choice continues from where it was.

### AC-26 When the stream cannot be recorded
Given a stream that cannot be recorded, a device with too little free storage at tune time, or a recording that fails to write or read partway
When the user presses pause, or the failure happens
Then pause still freezes the picture and play returns to live with no rewind row; the first pause on a short device says "Not enough free storage to rewind live TV"; a failure partway returns to live without stopping playback and says once "Storage is full. Back to live TV" or "Rewind stopped working. Back to live TV" (without "Back to live TV" when already live); every notice is also read aloud by VoiceOver.

### AC-28 Logins stay private
Given an Xtream catch-up address, an M3U `xc` stream address and a catch-up template that all contain a username and password
When the app plays catch-up or live, shows a notice, sets an accessibility value or writes a log line, and when every saved iCloud record is read
Then no notice, label, identifier or log line contains the username, password, template or either address (logs carry only the redacted address, source id and error name), and no saved record holds the template, the login, the Xtream server time zone or the hour correction, which live only in memory.

## Edge cases

- A stalled or offline source stops recording while time moves on; the gap shows on the scrubber and recording resumes without a new buffer when data returns.
- A slow catch-up start shows the CATCH-UP badge at the programme start and 0018's spinner; the live buffer is kept until catch-up plays.
- Pause and play during catch-up pause the catch-up stream; there is no buffer and no notice.
- With no guide data there is no programme, so Start over is absent and the bar shows 0008's guide-missing text.
- A login not yet synced means no Xtream catch-up address; Start over uses the buffer or stays hidden until the login arrives.
- An M3U `xc` channel from a provider in another time zone plays the wrong hour unless the playlist sets the correction.
- Other screens (tabs, guide, overlay) never resume a pause the user made.
- With Picture in Picture or background audio, or when a Mac window is merely hidden, recording just continues.
- Trying a failed channel again keeps its buffer.
- Skipping back past the start of a catch-up programme lands on its start. Start over closes the Apple TV overlay.
- Daylight-saving changes are handled; times are absolute and date parts use the named zone.
- Opening the overlay while paused keeps the pause (DR-1 forbids stopping, not an existing pause).
- On Apple TV the bar and its rewind row are never focusable; Start over is reached through the overlay.
- Reduce Motion: the marker jumps instead of sliding and notices appear without animation.
- VoiceOver on iPhone, iPad and Mac reads the scrubber as an adjustable control with the time and "behind" text; swiping up and down skips.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core (parser, Xtream mapping, address builder over every style and the refusal rows) + integration (one time-zone request per load) |
| AC-10 | integration (fake engine, simulated clock) + ui (tvOS, iPhone) |
| AC-12 | integration + ui (tvOS hold, iPhone drag, macOS keys) |
| AC-13 | integration + ui |
| AC-14 | integration (simulated clock and cap) + ui (notice) + device (4K stream filling the cap) |
| AC-19 | core (start-over planner) + integration (re-evaluation) + ui (tvOS overlay) |
| AC-20 | integration (fake engine log) + ui (badge) |
| AC-33 | integration (fake engine failing the catch-up load) + ui (notice) |
| AC-24 | integration (simulated file system) |
| AC-25 | integration (simulated app, audio and sleep events) + ui (tvOS Home) |
| AC-26 | integration (simulated free space and failing buffer) + ui + device (iPhone with little free space) |
| AC-28 | integration (log and hierarchy scan, in-memory SwiftData container) |

## Open questions

- Catch-up first, buffer second for Start over. The buffer is instant and cannot fail; catch-up keeps the user on one stream and frees the disk. Owner's call; flipping it changes AC-19 and AC-20.
- Holding play/pause for live on Apple TV has no system precedent. A focusable "Go live" item or a double press are the alternatives; changes AC-13.
- Should providers in another time zone get a per-source time zone setting? A settings spec; no criterion here changes.
- Should a long absence behind a content tab (say ten minutes) still return to live after a user pause? Changes AC-25.
- Should the CATCH-UP badge be filled so it is not mistaken for live? Can be decided in the plan.
- Does Apple's player path record in the first PR, or report "cannot record" (AC-26) until later? Can be decided in the plan.

## Notes for the plan

- Owner's numbers live in one place (`TimeshiftLimits`): window 3600 s; byte cap 4 GiB tvOS and macOS, 2 GiB iOS and iPadOS; keep 1 GiB free; below 64 MiB usable, no timeshift; live-edge tolerance 10 s; skip back 15 s, forward 30 s; scan 60x; click under 0.3 s; hold for live 0.5 s; catch-up skips within 400 ms coalesce into one load; on a write failure drop the oldest 10% once and retry.
- Catch-up details: playlists carry `catchup`, `catchup-source`, `catchup-correction` and `catchup-days`; a correction that is not a number is ignored without dropping the channel; Xtream channels with `tv_archive` above 0 are `xc` style; the Xtream server time zone is fetched once per source load and asked for again on first need when missing. Placeholders: `{utc}`/`{start}`, `{utcend}`/`{end}`, `{lutc}`/`{now}`/`{timestamp}`, `{duration}`, `{duration:60}`, `{offset}`, `{offset:60}`, `{Y}` to `{S}`; `xc` path `/timeshift/<user>/<pass>/<minutes>/<date>/<id>.ts`. The old AC-2 to AC-6 have worked examples and the refusal rows.
- Core types from the old Interface section: `TimeshiftWindow`, `TimeshiftBuffer` (actor, pins the chunk last read and emits when eviction reaches it), `CatchupMode`, `CatchupURLBuilder`, `XtreamCatchupContext`, `StartOverPlanner`, `Platform`, all in AntennaCore. `Channel` gains `catchupMode`, `catchupSource`, `catchupCorrectionHours` (in memory only); `XtreamAccountInfo` gains `serverInfo.timezone`; `XtreamClient` gains `timeshiftURL(streamID:start:durationMinutes:timeZone:)`.
- The buffer writes only at points playback can start from (PAT, PMT then an IDR frame). Buffer directory: `<Caches>/se.codecrave.antenna.timeshift/<sessionUUID>/`, files excluded from backup, names never derived from channel id or address (ADR-0003). The old session directory is renamed away before the new load returns, then deleted.
- Engine additions owed by 0017: `supportsTimeshift`, `canSeek`, a window stream, a playhead stream for catch-up, `seek(to: Date)`, `seekToLive()`, `attach(_:)`, an end-of-stream event; `.paused` is reused. A failed catch-up load reattaches the kept buffer.
- The player model tracks `userPaused`: set only by play/pause on the remote, the on-screen button, Space and remote-command pause or toggle; cleared by any play. Pauses from tab changes, interruptions and backgrounding never set it.
- The default template accepts `{name}` and `${name}`; Unix placeholders are not shifted by the correction; `{duration:60}` and `{offset:60}` round minutes up. Xtream with no known zone builds no address rather than guessing UTC. Test fixtures include a 2027-03-28 DST case.
- Refinements owed to other specs on acceptance: 0018 drops its transport strip and keyboard seek keys, and its buffering and error screens show during catch-up loads; 0007 (Start over visible, focus order, Watch respects a user pause), 0008 (play/pause reaches the engine, hint "Hold play/pause for live" while behind, LIVE "behind" state, left and right skip), 0009 and 0015 (no `play()` over a user pause), 0010 (two-row strip, LIVE as a button while behind), 0013 (favourite snapshots copy no catch-up fields), 0001, 0003 and 0004 (new attributes, `serverInfo`, one `accountInfo()` per load). The design README gains the buffered-fill token and the LIVE "behind" state.
- Board deviations the owner accepted: the scrubber knob is accent-filled; the live dot turns muted while behind live; iPhone transport glyphs are 32 pt in 44 pt hit areas.
- UI tests pin the locale to `en_US_POSIX` and the time zone to UTC; text formatting is asserted in core.

## Dropped

- Merged into AC-1: AC-1a, AC-2, AC-3, AC-4, AC-5, AC-5a, AC-5b, AC-5c, AC-6.
- Merged into AC-10: AC-11, AC-16, AC-16a, AC-17, AC-18.
- Merged into AC-12: AC-12a, AC-12b, AC-12c, AC-12d.
- Merged into AC-14: AC-15.
- Merged into AC-19: AC-9, AC-19a, AC-19b.
- Merged into AC-20: AC-21, AC-23.
- Merged into AC-33: AC-22.
- Merged into AC-24: AC-8a, AC-29.
- Merged into AC-25: AC-25a, AC-25b, AC-25c, AC-27, AC-27a, AC-27b.
- Merged into AC-26: AC-8b, AC-30, AC-32.
- Merged into AC-28: AC-31.
- Moved to the implementation plan: AC-7, AC-8.
