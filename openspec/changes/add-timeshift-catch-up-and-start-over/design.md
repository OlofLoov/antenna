# Design

## Context

See proposal.md for why. The buffer and catch-up sit on change `add-playback-engine`; the controls extend the zap bar, the channel overlay and the Live screen's strip.

Boards, under `openspec/specs/design-system/boards/`: `TV-ZapBar-Timeshift.dc.html`, `iPhone-Player-Timeshift.dc.html`, `Main.dc.html` (the Start over button in the overlay).

Not drawn: the two-row strip on iPad and Mac and in full screen; the notice pill; catch-up playback with its CATCH-UP badge; the gap after background; the rewind row at the live edge while playing.

Design-system requirements that apply: “Live video keeps playing under overlays”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “A current programme always shows its progress”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Text meets contrast minimums”. Opening the overlay while paused keeps the pause; “Live video keeps playing under overlays” forbids stopping, not an existing pause. On Apple TV the bar and its rewind row are never focusable, and Start over is reached through the overlay.

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
- Catch-up details: playlists carry `catchup`, `catchup-source`, `catchup-correction` and `catchup-days`. Xtream channels with `tv_archive` above 0 are `xc` style. The Xtream server time zone is fetched once per source load and asked for again on first need when missing. Placeholders: `{utc}`/`{start}`, `{utcend}`/`{end}`, `{lutc}`/`{now}`/`{timestamp}`, `{duration}`, `{duration:60}`, `{offset}`, `{offset:60}`, `{Y}` to `{S}`; `xc` path `/timeshift/<user>/<pass>/<minutes>/<date>/<id>.ts`. Worked examples and the refusal rows are under Catch-up addresses below.
- Core types in AntennaCore: `TimeshiftWindow`, `TimeshiftBuffer` (actor, pins the chunk last read and emits when eviction reaches it), `CatchupMode`, `CatchupURLBuilder`, `XtreamCatchupContext`, `StartOverPlanner`, `Platform`. `Channel` gains `catchupMode`, `catchupSource`, `catchupCorrectionHours` (in memory only). `XtreamAccountInfo` gains `serverInfo.timezone`. `XtreamClient` gains `timeshiftURL(streamID:start:durationMinutes:timeZone:)`.
- The buffer writes only at points playback can start from (PAT, PMT then an IDR frame). Buffer directory: `<Caches>/se.codecrave.antenna.timeshift/<sessionUUID>/`, files excluded from backup, names never derived from channel id or address. The old session directory is renamed away before the new load returns, then deleted.
- Engine additions owed by change `add-playback-engine`: `supportsTimeshift`, `canSeek`, a window stream, a playhead stream for catch-up, `seek(to: Date)`, `seekToLive()`, `attach(_:)`, an end-of-stream event; `.paused` is reused. A failed catch-up load reattaches the kept buffer.
- The player model tracks `userPaused`: set only by play/pause on the remote, the on-screen button, Space and remote-command pause or toggle; cleared by any play. Pauses from tab changes, interruptions and backgrounding never set it.
- The default template accepts `{name}` and `${name}`. Unix placeholders are not shifted by the correction. `{duration:60}` and `{offset:60}` round minutes up. Xtream with no known zone builds no address rather than guessing UTC. Fixtures include a 2027-03-28 DST case.
- Board deviations the owner accepted: the scrubber knob is accent-filled; the live dot turns muted while behind live; iPhone transport glyphs are 32 pt in 44 pt hit areas.
- UI tests pin the locale to `en_US_POSIX` and the time zone to UTC. Text formatting is asserted in core.
- The parser and Xtream mapping changes are added requirements on `m3u-playlists` and `xtream-live-source`.

## Catch-up addresses

Fixtures for `CatchupURLBuilder` and `XtreamClient.timeshiftURL`.

Parsing. An entry with `catchup="default" catchup-source="http://a/arc?utc={utc}&d={duration}" catchup-correction="-1.5" catchup-days="7"` gives `catchupMode` "default", that `catchupSource`, `catchupCorrectionHours` -1.5, `hasCatchup` true and `catchupDays` 7. An entry with none of the three new attributes has nil for all three. Xtream entries with `tv_archive` 1 map to `catchupMode` "xc"; `tv_archive` 0 or absent maps to nil. `catchupSource` and `catchupCorrectionHours` are always nil for Xtream channels.

Shared request: start 2026-11-04T20:00:00Z, duration 3600, now 2026-11-04T20:40:00Z, device time zone UTC.

Default template. Channel with `catchupCorrectionHours` 1 and `catchupSource` `http://a/arc?s={utc}&e={utcend}&d={duration}&m={duration:60}&o={offset}&n={lutc}&t={Y}-{m}-{d}_{H}-{M}-{S}` gives `http://a/arc?s=1793822400&e=1793826000&d=3600&m=60&o=2400&n=1793824800&t=2026-11-04_21-00-00`.

| Placeholder | Value |
|---|---|
| `{utc}`, `{start}` | start as Unix seconds |
| `{utcend}`, `{end}` | stop as Unix seconds |
| `{lutc}`, `{now}`, `{timestamp}` | now as Unix seconds |
| `{duration}` | length in seconds |
| `{duration:60}` | length in minutes, rounded up |
| `{offset}` | now minus start, in seconds |
| `{offset:60}` | now minus start, in minutes, rounded up |
| `{Y}` `{m}` `{d}` `{H}` `{M}` `{S}` | start in the device time zone shifted by the correction, zero-padded |

Append and shift, with `streamURL` `http://a/live/7.ts`:
- "append" with `catchupSource` `?utc={utc}&lutc={lutc}`, and "shift" with `catchupSource` nil, both give `http://a/live/7.ts?utc=1793822400&lutc=1793824800`.
- With `streamURL` `http://a/live/7.ts?token=x` the appended query starts with `&`.
- "append" with `catchupSource` nil gives nil.

Flussonic ("flussonic" or "fs"), keeping any query on the stream URL:

| `streamURL` | Result |
|---|---|
| `http://a/ch/index.m3u8` | `http://a/ch/index-1793822400-3600.m3u8` |
| `http://a/ch/video.m3u8` | `http://a/ch/video-1793822400-3600.m3u8` |
| `http://a/ch/mono.m3u8` | `http://a/ch/mono-1793822400-3600.m3u8` |
| `http://a/ch/mpegts` | `http://a/ch/archive-1793822400-3600.ts` |
| any other last path component | nil |

Xtream source. Start 2026-11-04T20:00:00Z, duration 2700, credentials for `http://panel:8080` user `u` password `p`, server time zone `Europe/Stockholm`. `XtreamClient.timeshiftURL(streamID: 42, start:, durationMinutes: 45, timeZone:)` and `CatchupURLBuilder.url` for channel `xtream#panel#42` in "xc" mode both give `http://panel:8080/timeshift/u/p/45/2026-11-04:21-00/42.ts`. The stream id is the last `#` component of `Channel.id`. User and password are percent-encoded the way `xtream-vod-client` encodes them. `XtreamClient.timeshiftURL` with `timeZone` nil formats the start in UTC (`2026-11-04:20-00`); `CatchupURLBuilder` with a context whose `timeZone` is nil gives nil.

Server time zone. `player_api.php` with no action answering `{"user_info":{...},"server_info":{"timezone":"Europe/Stockholm"}}` decodes `serverInfo.timezone` as "Europe/Stockholm". A response without `server_info` decodes with `serverInfo` nil. `XtreamCatchupContext.timeZone` is `TimeZone(identifier:)` of the string, nil for an unknown identifier. The zone is kept in memory per `sourceID`; a failed `accountInfo()` leaves it nil and the channel load goes on.

M3U channel in "xc" mode (an `id` that does not start with `xtream#`). `streamURL` `http://a/live/u/p/42.ts`, correction 0, the Xtream request above, device time zone `Europe/Stockholm`, `xtream` nil, gives `http://a/timeshift/u/p/45/2026-11-04:21-00/42.ts`. User, password and id come from the stream URL path, and the start is formatted in the device time zone shifted by the correction. A path that is not `/live/<user>/<pass>/<id>.<ext>` gives nil.

Refusals. Each of these gives nil and requests nothing:
- `hasCatchup` false.
- `catchupMode` "vod" or an unknown string.
- "default" with a placeholder not in the table above, or with `catchupSource` nil.
- "xc" for an Xtream channel with no `XtreamCatchupContext` (credential not yet synced).
- "xc" for an Xtream channel whose context has no time zone (`accountInfo()` failed, has not run since launch, or named an unknown zone).
- A start after now, or a duration of 0 or less.
- A start earlier than now minus `catchupDays` days, when `catchupDays` is above 0.
- A template or stream URL that does not parse as an `http` or `https` URL.

## Risks / Trade-offs

- [Buffer location and size are undecided] → the change is blocked on that decision; the assumed numbers live in `TimeshiftLimits` so they change in one place.
- [Providers in another time zone] → the playlist's hour correction fixes it; without one the hour is wrong.
- Open question: catch-up first, buffer second for Start over. The buffer is instant and cannot fail; catch-up keeps the user on one stream and frees the disk. Owner's call; flipping it changes the Start over requirements.
- Open question: holding play/pause for live on Apple TV has no system precedent. A focusable "Go live" item or a double press are the alternatives; this changes the back-to-live requirement.
- Open question: should providers in another time zone get a per-source time zone setting? A settings change; no requirement here changes.
- Open question: should a long absence behind a content tab (say ten minutes) still return to live after a user pause? This changes the interruptions requirement.
- Open question: should the CATCH-UP badge be filled so it is not mistaken for live? Can be decided during implementation.
- Open question: does Apple's player path record in the first slice, or report that it cannot record until later? Can be decided during implementation.

## Implementation decisions

Calls made while building, recorded here instead of asked.

- `CatchupMode` is an enum (`default`, `append`, `shift`, `flussonic`, `xc`, `unsupported(String)`). `catchup="fs"` reads as `flussonic`; `vod` and any other value is `unsupported` and builds no address. `catchup="0"` or empty gives no mode, as it already gave no catch-up.
- `Channel.CodingKeys` leaves out `catchupMode`, `catchupSource` and `catchupCorrectionHours`, so a channel that is ever encoded drops them and decodes with nil. Nothing encodes channels today; this keeps it so.
- `XtreamClient.liveLoad()` asks for the categories, the streams and the account information at once, and returns the channels with the time zone name. A failed account call leaves the zone nil. `SourceLoader` records the name in `XtreamTimeZones`, an actor shared by the app and kept in memory only. `Playlist` gains `serverTimeZone` so the screens can see it without the actor.
- `XtreamTimeZones.timeZone(for:fetch:)` asks the panel again only once after each load when no zone is known. Start over re-evaluates every few seconds; without this a panel with no zone would get an account call each time.
- The `xc` path writes the date part `yyyy-MM-dd:HH-mm` unencoded. Percent-encoding the colon, as the other path segments are, gave `%3A`, which the design's examples do not have.
- An M3U `xc` stream address must be exactly `/live/<user>/<pass>/<id>.<ext>` with no prefix path; the query is dropped.
- `TimeshiftBuffer` is a final class guarded by an `NSCondition`, not an actor. FFmpeg's read callback runs on the demuxing thread and has to block until bytes arrive, which it cannot do across an actor hop. The chunk rules (`TimeshiftIndex`) are a plain struct tested on their own.
- A chunk opens at a start point at least `chunkSpacing` (1 s) after the last one opened, so seeks land within about a second. Each chunk is stamped with the time its first byte was written, not the stream's clock. Chunks are dropped once their start is older than the hour, so the window never shows more than 60 minutes.
- A start point is a video packet that starts a PES with the random access flag set, or whose first bytes hold an H.264 IDR or SPS, an HEVC IRAP or parameter set, or an MPEG-2 sequence header. Radio counts each sound frame. Before the first start point nothing is kept. The recorder looks at the first 512 bytes before taking any: a stream that is not MPEG-TS (HLS, Matroska) is left on its connection and plays as before, and one with no start point in its first 8 MB is opened again without a buffer.
- The engine reports through `timeshift() -> AsyncStream<TimeshiftStatus>`: recording state (`off`, `recording`, `cannotRecord`, `storageShort`, `stopped`), the window, the playhead and the latest notice with a count. This stands in for the `supportsTimeshift`, `canSeek` and window stream in the decisions above. Apple's player yields `off`, which the app treats as cannot record.
- `PlaybackOptions.timeshift` asks for recording, so films, multi-view tiles and catch-up never record. The free space check runs once per new session; below `minimumUsable` the channel plays straight from its connection.
- Loading the same address again keeps its session and records after a gap; any other address, `stop` and a hand-over to Apple's player retire it. Retiring renames the folder at once and deletes it on a utility queue. Launch renames every leftover the same way before any session starts.
- When the recorder's connection ends while playback is at live, the engine reconnects as it did before and recording goes on after a gap. Paused or behind live, playback goes on from the buffer and the recorder reconnects on its own under a `ReconnectBudget`; when that runs out, playback reaches the end of the buffer and the engine's usual reconnect takes over.
- A failed write or read deletes the buffer, says the notice once, and plays live from a new connection.
- Fixed on the way: a film on the demuxing engine stayed `.paused` after `play()`; it now reports `.playing`.
- `TimeshiftModel` lives in `PlayerModel`, so the Apple TV shell and Live on iPhone, iPad and Mac share one set of rules. It owns `userPaused`, the preview time of a scan or drag, and the notice on screen for 4 seconds. Only the main player's loads ask for recording (`recordingLive()`).
- On Apple TV, left and right skip only while the rewind row shows (paused, behind live or scanning). At live they keep the zap bar's previous channel and Recents, which `tv-zap-bar-and-number-entry` already gives them.
- Holding play/pause, left or right is read by long-press recognizers on the window; SwiftUI's commands have no hold. A held arrow arrives as a click first, so a scan starts 15 seconds back. The release of a hold for live is ignored for 1.5 seconds so it does not also pause.
- The zap bar stays up for as long as the user's pause lasts and hides five seconds after play. Play/pause in full-screen live TV now pauses as well as showing the bar.
- Watch on the playing channel while it is paused still plays it, as `tv-channel-overlay/select-on-the-playing-channel-does-not-restart-it` says. That is the user's own play, so the proposal's "Watch respects a user pause" is read as "opening the overlay keeps the pause".
- Opening the Guide no longer plays a channel the user paused. A pause made by the content-tab timer, a call or leaving the app is an interruption: at live it comes back at live with a new buffer (the engine stops, which deletes the old buffer, and the channel loads again), and behind live it plays on from where it was.
- iPhone and iPad already keep Live playing in the background, so recording goes on there; the interruption rules apply to calls and Siri.
- The touch scrubber is one adjustable accessibility element whose value is the time and the behind text; increment and decrement skip. Left and Right keys skip while the filter field does not have the keyboard.
- UI tests script the buffer with `UITESTING_TIMESHIFT` (`buffer`, `none`, `short`, `full`, `fail`); each load starts with 20 minutes recorded.
- `tv-zap-bar-and-number-entry/play-pause-shows-the-bar` said the video keeps playing, which the pause requirements here cannot meet. This change now carries a MODIFIED delta for it: play/pause shows the bar and pauses or plays. Its UI tests press twice where they only wanted a fresh bar.
- Start over is worked out by `StartOverPlanner` every 2 seconds for the channel playing (`TimeshiftModel.startOver`). The overlay offers it only on the playing channel's panel, after Watch; the touch strip shows it in its slot. Kids-style channels with no guide data never get it.
- The engine parks the live buffer (`parkTimeshift`) before the catch-up load, so recording goes on and nothing is deleted; `dropParkedTimeshift` runs once catch-up plays, and `resumeParkedTimeshift(at:)` brings live back on a failed start. Only the demuxing engine records, so `RoutedEngine` parks there whichever engine plays catch-up. `stop` deletes a parked buffer; a hand-over to Apple's player does not.
- Catch-up plays with `isLive: false`. The scrubber then spans the programme's start to now, the playhead is the requested start plus the engine's position, and skips, scans and drags build a new address at the new start, waiting 400 ms for further skips. Play after a pause loads the address again at the paused time, since the demuxing engine reopens a non-seekable stream from its start. The end of the stream, or a skip past now, returns to live: the engine stops and the channel loads again, which gives it a new buffer.
- A catch-up start that fails shows no error: the player ignores failures from Start over until 2 seconds after it falls back, since the failed state reaches it after the fallback has begun.
- The CATCH-UP badge is filled in the accent color (the open question above), in place of LIVE on the zap bar and before the time on the touch strip. Start over shows the zap bar.
- Logins: catch-up addresses are built only when needed and passed straight to the engine, which logs the redacted address. UI tests check the accessibility hierarchy for the scripted address's login, the demuxing engine's tests check every log line, and an app test checks favorites and sources after starring catch-up channels. Favorites of M3U channels stored the stream address in `channelID`, so an M3U `xc` address there could hold the playlist's login. Change `fix-m3u-channel-ids` took the link out of M3U ids and rewrites those favorites when their playlist loads.
