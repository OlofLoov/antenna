# Design

## Context

See proposal.md for why. The buffer and catch-up sit on change `add-playback-engine`; the controls extend the zap bar, the channel overlay and the Live screen's strip.

Boards, under `openspec/specs/design-system/boards/`: `TV-ZapBar-Timeshift.dc.html`, `iPhone-Player-Timeshift.dc.html`, `Main.dc.html` (the Start over button in the overlay).

Not drawn: the two-row strip on iPad and Mac and in full screen; the notice pill; catch-up playback with its CATCH-UP badge; the gap after background; the rewind row at the live edge while playing.

Design-system requirements that apply: “Live video keeps playing under overlays”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “A current programme always shows its progress”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”. Opening the overlay while paused keeps the pause; “Live video keeps playing under overlays” forbids stopping, not an existing pause. On Apple TV the bar and its rewind row are never focusable, and Start over is reached through the overlay.

Decisions this builds on: adr-0001 (hardware playback path for MPEG-TS), adr-0002 (SwiftData with private CloudKit for sync), adr-0003 (credentials in iCloud Keychain), adr-0005 (AntennaCore is UI-free).

On Apple TV, play/pause freezes the picture and the zap bar shows a rewind row whose marker drifts left as live moves on. Play/pause again continues. Left skips back 15 seconds, right forward 30, holding scans. Holding play/pause jumps to live. The overlay shows Start over when the programme can be restarted. Changing channel starts a fresh buffer.

On iPhone, iPad and Mac, pause shows a scrubber with the marker at the right. Skip buttons move 15 back and 30 forward, dragging seeks on release, LIVE returns to live, Start over restarts the programme, and Left and Right skip with a keyboard.

## Goals / Non-Goals

**Goals:**
- All tunable numbers in one place.
- Catch-up address building is pure and tested over every style.

**Non-Goals:**
- Browsing past programmes, keeping recordings, the `vod` style, XMLTV catch-up ids, and catch-up for other source types.
- A per-source time zone setting.

## Decisions

- Numbers live in `TimeshiftLimits`: window 3600 s; byte cap 4 GiB tvOS and macOS, 2 GiB iOS and iPadOS; keep 1 GiB free; below 64 MiB usable, no timeshift; live-edge tolerance 10 s; skip back 15 s, forward 30 s; scan 60x; click under 0.3 s; hold for live 0.5 s; catch-up skips within 400 ms coalesce into one load; on a write failure drop the oldest 10% once and retry.
- Catch-up details: playlists carry `catchup`, `catchup-source`, `catchup-correction` and `catchup-days`. Xtream channels with `tv_archive` above 0 are `xc` style. The Xtream server time zone is fetched once per source load and asked for again on first need when missing. Placeholders: `{utc}`/`{start}`, `{utcend}`/`{end}`, `{lutc}`/`{now}`/`{timestamp}`, `{duration}`, `{duration:60}`, `{offset}`, `{offset:60}`, `{Y}` to `{S}`; `xc` path `/timeshift/<user>/<pass>/<minutes>/<date>/<id>.ts`. Worked examples and the refusal rows are in the old AC-2 to AC-6 of `docs/specs/0019-timeshift-catch-up-and-start-over.md` at 0bce26a.
- Core types in AntennaCore: `TimeshiftWindow`, `TimeshiftBuffer` (actor, pins the chunk last read and emits when eviction reaches it), `CatchupMode`, `CatchupURLBuilder`, `XtreamCatchupContext`, `StartOverPlanner`, `Platform`. `Channel` gains `catchupMode`, `catchupSource`, `catchupCorrectionHours` (in memory only). `XtreamAccountInfo` gains `serverInfo.timezone`. `XtreamClient` gains `timeshiftURL(streamID:start:durationMinutes:timeZone:)`.
- The buffer writes only at points playback can start from (PAT, PMT then an IDR frame). Buffer directory: `<Caches>/se.codecrave.antenna.timeshift/<sessionUUID>/`, files excluded from backup, names never derived from channel id or address (adr-0003). The old session directory is renamed away before the new load returns, then deleted.
- Engine additions owed by change `add-playback-engine`: `supportsTimeshift`, `canSeek`, a window stream, a playhead stream for catch-up, `seek(to: Date)`, `seekToLive()`, `attach(_:)`, an end-of-stream event; `.paused` is reused. A failed catch-up load reattaches the kept buffer.
- The player model tracks `userPaused`: set only by play/pause on the remote, the on-screen button, Space and remote-command pause or toggle; cleared by any play. Pauses from tab changes, interruptions and backgrounding never set it.
- The default template accepts `{name}` and `${name}`. Unix placeholders are not shifted by the correction. `{duration:60}` and `{offset:60}` round minutes up. Xtream with no known zone builds no address rather than guessing UTC. Fixtures include a 2027-03-28 DST case.
- Board deviations the owner accepted: the scrubber knob is accent-filled; the live dot turns muted while behind live; iPhone transport glyphs are 32 pt in 44 pt hit areas.
- UI tests pin the locale to `en_US_POSIX` and the time zone to UTC. Text formatting is asserted in core.
- The parser and Xtream mapping changes are added requirements on `m3u-playlists` and `xtream-live-source`.

## Risks / Trade-offs

- [Buffer location and size are undecided] → the change is blocked on that decision record; the assumed numbers live in `TimeshiftLimits` so they change in one place.
- [Providers in another time zone] → the playlist's hour correction fixes it; without one the hour is wrong.
- Open question: catch-up first, buffer second for Start over. The buffer is instant and cannot fail; catch-up keeps the user on one stream and frees the disk. Owner's call; flipping it changes the Start over requirements.
- Open question: holding play/pause for live on Apple TV has no system precedent. A focusable "Go live" item or a double press are the alternatives; this changes the back-to-live requirement.
- Open question: should providers in another time zone get a per-source time zone setting? A settings change; no requirement here changes.
- Open question: should a long absence behind a content tab (say ten minutes) still return to live after a user pause? This changes the interruptions requirement.
- Open question: should the CATCH-UP badge be filled so it is not mistaken for live? Can be decided during implementation.
- Open question: does Apple's player path record in the first slice, or report that it cannot record until later? Can be decided during implementation.
