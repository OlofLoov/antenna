# 0018. Player controls and playback errors on every platform

- Status: Draft
- Review: three spec-reviewer rounds. The second round's findings were lost when that attempt stopped; the third returned ACCEPT WITH EDITS and every finding is applied (see PR #41).
- Date: 2026-11-04
- Depends on ADRs: 0001, 0002, 0003, 0005
- Platforms: iOS, iPadOS, macOS, tvOS
- Builds on specs 0017 (playback engine: state machine, failure type, tracks, presentation info, PiP capability), 0008 (zap bar owns play/pause and the badges in full-screen live), 0010 (places play/pause, progress, clock, LIVE, PiP and full screen on iPhone, iPad and Mac), 0015 (tvOS shell, Menu), 0007 (overlay), 0009 (guide PiP box), 0014 (guide queries for the Info segment), 0013 (initials), 0006 (offline wording, tvOS sign-in step), 0004 (source names).
- 0017 is written in parallel with this spec. Citations of the form `0017/AC-n (subject)` name the criterion by subject; `n` is filled in when 0017 merges. The interface this spec assumes from it is listed under "Assumed engine interface". Anything 0017 does not provide is listed under "Required of other specs".
- Blocked on 0019 (timeshift, unwritten) for AC-8a to AC-8c and AC-15, which read its position model. Blocked on 0017 building the Xtream stream URL at load time for AC-21a and AC-21b and the `.credentialMissing` rows of AC-18; until then `.credentialMissing` is unreachable. The blocked criteria are not part of this spec's definition of done; the spec can move to Implemented with them marked blocked, and they ship with 0019 and 0017.
- No ADR needed for player preferences: macOS volume and mute are per-device and stored in `UserDefaults`, as 0015 stores the last channel. Nothing here adds a SwiftData or CloudKit field (ADR-0002) or a secret (ADR-0003).

## Design

Boards: `docs/design/boards/TV-Player.dc.html`, `TV-Player-Tracks.dc.html`, `TV-Player-Error.dc.html`, `TV-Player-Buffering.dc.html` (tvOS, 1920 by 1080); `iPad-Player.dc.html`, `iPad-Player-Tracks.dc.html`, `iPad-Player-Error.dc.html` (iPadOS and macOS, regular width, 1194 by 834); `iPhone-Player.dc.html`, `iPhone-Player-Tracks.dc.html`, `iPhone-Player-Error.dc.html` (iOS and compact width, 390 by 844). The iPad and iPhone boards are the 0010 boards with this spec's additions; the sidebar, list, panel and tab bar are 0010's and are not re-specified here.
Design rules that apply: DR-1, DR-2, DR-3, DR-4, DR-5, DR-7, DR-8, DR-11, DR-12, DR-13, DR-15. Deviations: DR-2, the selected segment of `player.panel.segments` uses the 0.12 surface at weight 600 while focus is in the track list, as 0015 does for the selected tab, so the user can see which segment is open; DR-5, the inline control buttons on iPhone, iPad and Mac are drawn at 30 to 32 pt like 0010's and extend their hit area to 44 pt; DR-3, the error surface uses no colour other than the tokens, so a failure is told by text, not by red.
States on the boards:
- `TV-Player.dc.html`: `player.panel` open over live video with `player.panel.segment.info` focused (Focus token), `player.panel.hint`, and `player.panel.info` (logo or initials tile, `player.panel.channel`, programme title, times and remaining per 0008/AC-5, progress bar, summary, badges per 0008/AC-7, `player.panel.stream`); `player.transport` at the bottom in the 0019 timeshift state, paused two minutes behind live, with the scrubber, position text, buffer start and `player.transport.goLive`. The strip stays drawn under an open panel and is not focusable while focus is in the panel (AC-8a).
- `TV-Player-Tracks.dc.html`: `player.panel.segment.audio` selected with focus in the list (selected segment on the 0.12 surface at weight 600), four track rows at 72 pt with the selected row's checkmark, the focused row as the white card with the muted-on-focus token, a row named "Track 4" for a track with no language tag, no transport strip.
- `TV-Player-Error.dc.html`: `player.error` on the ground colour with glyph, `player.error.title` 38 pt, `player.error.body` 26 pt secondary, `player.error.detail` 22 pt muted, `player.retry` as the focused white 64 pt button labelled "Try again", `player.error.hint` 22 pt muted.
- `TV-Player-Buffering.dc.html`: `player.buffering` 64 pt ring centred over the last frame with `player.buffering.caption` 26 pt muted.
- `iPad-Player.dc.html`: the 0010 controls row with `player.tracks`, `player.airplay`, `player.mute` and `player.volume` (macOS only, marked in a comment) inserted between `browse.player.live` and `browse.player.pip`, all 32 pt.
- `iPad-Player-Tracks.dc.html`: `player.trackPicker` as a 320 pt popover above the tracks button, Audio and Subtitles eyebrows at 13 pt, rows 44 pt at 16 pt with the selected row on the 0.12 surface and a checkmark, a "Forced" subtitle row, `player.trackPicker.stream` 13 pt muted footer.
- `iPad-Player-Error.dc.html`: `player.error` in the video frame on the ground colour, title 17 pt, body 15 pt muted, `player.retry` 44 pt on the 0.12 surface; the controls row hidden; `browse.panel` kept. No `player.error.detail` (tvOS only, AC-17b).
- `iPhone-Player.dc.html`: the compact controls row with `player.tracks` at 30 pt between `browse.player.live` and `browse.player.pip`; no AirPlay button at compact inline width.
- `iPhone-Player-Tracks.dc.html`: `player.trackPicker` as a 468 pt sheet with grabber, title "Audio & Subtitles" 17 pt, `player.trackPicker.done`, the same sections and rows as the iPad popover, footer 12 pt.
- `iPhone-Player-Error.dc.html`: `player.error` in the pinned player with the offline wording, title 17 pt, body 15 pt muted, `player.retry` 44 pt; `browse.nowPlaying` kept; no detail line.
Not drawn, each a variant of a drawn board with the same geometry:
- Subtitles segment on tvOS: `TV-Player-Tracks.dc.html` rows with "Off" first and "Forced" as the 22 pt muted detail; with no subtitle track, one row `player.panel.noSubtitles` reading "No subtitles in this stream" in the muted 29 pt style, not focusable, under the focused Off row.
- Info segment in the 0008/AC-6a to AC-6c guide states: `TV-Player.dc.html` with `player.panel.title` reading that text at 34 pt muted and no times, progress or summary.
- `player.transport` hidden: `TV-Player.dc.html` without the bottom strip; nothing but video and, when open, the panel.
- `player.transport` at the live edge: `player.transport.goLive` replaced by the filled LIVE badge of 0008 (18 pt, live dot), not focusable.
- `player.reconnecting`: `TV-Player-Buffering.dc.html` with the caption "Reconnecting… attempt 2 of 3"; on iPhone, iPad and Mac the ring is 44 pt and the caption 15 pt muted, centred in the video frame.
- `player.buffering` on iPhone, iPad and Mac: 44 pt ring centred in the video frame, controls row still drawn; caption 15 pt muted under it after 10 s.
- `player.pipPlaceholder` and `player.airplayPlaceholder`: the video frame on the ground colour with the PiP or AirPlay glyph at 40 pt muted and the text "Playing in Picture in Picture" or "Playing on AirPlay" at 15 pt muted, centred; controls row kept.
- Full screen on iPhone (0010's `iPhone-FullScreen.dc.html`): `player.tracks` and `player.airplay` at 32 pt between LIVE and PiP, the same row.
- `player.error` in full screen on iPhone, iPad and Mac: `iPhone-Player-Error.dc.html` geometry over the whole screen, with `browse.player.fullscreen` alone at its 0010 position in the bottom-right corner so the user can leave full screen.
- `player.tracks` disabled: the glyph at 40% opacity.
- `player.trackPicker.subtitles.none`: a 44 pt row reading "No subtitles in this stream" at 16 pt muted, not selectable, in place of the subtitle track rows.
- Credential-missing error on tvOS: `TV-Player-Error.dc.html` with a second button `player.signIn` ("Sign in") on the 0.12 surface after `player.retry`.
- Error with the zap bar visible on tvOS: `TV-Player-Error.dc.html` with 0008's bar over the lower 236 pt for its five seconds.

## Problem

Antenna's player today is a bare `VideoPlayer` with the system controls and a blank screen when a stream fails, so the user cannot tell whether the provider returned 404, the network dropped, the login has not synced yet, or the codec is one the device cannot decode. The research note lists "diagnose, don't blame" among the things Antenna can do better than TiviMate, whose users also complain about the five-retry limit on dropped streams. 0010, 0008 and 0015 placed their controls and deferred buffering, errors, track pickers, PiP behaviour and background audio to this spec.

## Scope

In:
- tvOS: `player.panel` with Info, Audio and Subtitles segments, opened by a long press on select over full-screen live playback and closed by Menu. The play/pause button where 0008 does not consume it (engine `.failed` in full screen; Guide and content tabs). `player.transport` while 0019 timeshift is active.
- iPhone, iPad and Mac: `player.tracks` and `player.trackPicker`, `player.airplay`, `player.mute` and `player.volume` on macOS, keyboard shortcuts for seeking and volume, the buffering indicator, the error surface and Retry, PiP activation and automatic PiP on leaving the app (iOS, iPadOS), closing PiP, background audio, Now Playing and remote commands, audio interruptions.
- The `audio` entry in `UIBackgroundModes` for the Mobile target, set in `project.yml` (AC-31).
- Every platform: `player.buffering`, `player.reconnecting` with automatic reconnect on transport failures, `player.error` with plain-language reasons from `PlaybackFailureText` in AntennaCore, and `player.retry`.
- The stream line from `StreamLineText` in AntennaCore (`player.panel.stream` on tvOS, `player.trackPicker.stream` elsewhere) naming container, codecs and engine route, with codec names from `CodecName` in AntennaCore (AC-29).
- Accessibility identifiers with prefix `player.`.

Out (explicitly):
- Engine selection, state machine, failure detection, track enumeration, PiP plumbing, presentation info (0017).
- Timeshift buffer, seeking inside it, what pause means at the live edge, superseding 0008/AC-2 so that play/pause pauses live TV (0019). AC-8a to AC-8c draw the strip 0019 drives.
- VOD player UI: scrub bar over a duration, resume, exit back to the card (a later VOD player spec; the error, buffering and track surfaces here are reusable and that spec cites them).
- Catch-up and Start over (catch-up spec).
- Zap bar contents, number entry, LIVE and format badges in full-screen live (0008).
- Placement of play/pause, progress, clock, LIVE, PiP and the full-screen toggle, their visibility timer, Space and Escape (0010).
- Preferred audio and subtitle language remembered across channels, and a background-audio toggle (settings spec; both need the ADR-0002 settings decision).
- PiP on macOS and tvOS. 0009's guide box is an inline view, not system PiP.
- Multi-view.
- Recording.

## Assumed engine interface (0017)

Names this spec reads. 0017 is binding where it differs; this list exists so the criteria can be written and tested against a fake today.

```swift
enum PlaybackState { case idle, loading, buffering, playing, paused, failed(PlaybackFailure) }

enum PlaybackFailure: Sendable, Equatable {
    case httpStatus(Int)             // the stream request got a non-2xx status other than 401 and 403
    case unauthorized                // 401 or 403, or the provider's auth failure
    case offline                     // URLError .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed
    case network(URLError.Code)      // any other URLError
    case timeout                     // no bytes for 0017's stall limit
    case stalled                     // bytes stopped after playback had started
    case credentialMissing           // Keychain item absent or unreadable while building the URL at load time
    case unsupportedCodec(String)    // codec name as the demuxer reports it, "hevc", "ac3"
    case malformedStream             // bytes are not a stream the demuxer or AVPlayer can read
}

struct MediaTrack: Identifiable, Sendable, Equatable {
    enum Kind { case audio, subtitle }
    var id: String; var kind: Kind; var languageCode: String?; var name: String?
    var codec: String?; var channelCount: Int?; var isForced: Bool
}

protocol PlaybackEngine {
    var state: PlaybackState
    var route: EngineRouter.Route            // .system or .demuxer, after sniffing
    var presentation: PresentationInfo?      // 0008/AC-7: video height, audio channels, codec; plus container and video codec names; videoHeight nil once known means no video track
    var tracks: [MediaTrack]
    var selectedTrack: [MediaTrack.Kind: MediaTrack.ID?]
    func select(_ track: MediaTrack?, kind: MediaTrack.Kind) async
    var volume: Float { get set }            // macOS
    var supportsPictureInPicture: Bool       // iOS, iPadOS
    var pictureInPicture: PictureInPictureController?   // start(), stop(), isActive, events
    var supportsAirPlay: Bool                // true only on the .system route
    var isExternalPlaybackActive: Bool       // an AirPlay route is taking the video
    static var stallLimit: Duration          // the .timeout threshold, quoted by AC-18
    func load(_ channel: Channel) async throws   // builds the Xtream URL from the credential at load time
    func play() async; func pause() async; func stop() async
}
```

The fake engine used in tests records every call, exposes a settable state, tracks, selected tracks, route, presentation, stall limit and external-playback flag, and emits PiP events on request. Nothing derived from `streamURL` is written to an accessibility attribute, identifier, label or log (ADR-0003). "`load(_:)` with the current channel" below means a call whose recorded channel equals the one playing; the fake records channels, never URLs.

Terms used below. A load is user-initiated when it comes from a tune, from `player.retry` (AC-6a), or from AC-20 or AC-21a; it is a reconnect when AC-19a issues it. A load has "played 30 s" once the engine has been `.playing` for 30 s in total since that load on the injected clock.

## User flow

tvOS:
1. A channel plays full screen. The user holds select. `player.panel` slides down over the top of the picture with Info selected: what is on, how far in, what the stream is. The picture keeps playing.
2. Swiping right on the segment control moves to Audio, then Subtitles, and the list below changes with the focused segment; swiping down or pressing select enters the list. Select on a track switches it; the panel stays open. Menu closes the panel. While the panel is open, swipes never tune and play/pause does nothing.
3. A stream fails. The picture is replaced by the reason in plain words and a focused "Try again" button. Play/pause or select retries. Swiping up or down tunes another channel as usual; Menu opens the tab bar as usual.
4. With 0019 timeshift active, a strip at the bottom shows where in the buffer the user is and offers "Go to live".

iPhone, iPad and Mac:
1. The inline controls gain a speech-bubble button. Tapping it opens the track picker (a sheet at compact width, a popover otherwise) with Audio and Subtitles sections and a footer naming the stream format.
2. The AirPlay button appears when the stream can be sent to an AirPlay device. On a Mac a speaker button and slider set the volume.
3. A stall shows a ring over the picture; ten seconds after the ring appears a line says the source is slow. A dropped connection reconnects on its own up to three times before showing the reason and "Try again".
4. On iPhone and iPad, leaving the app while a channel plays continues it in Picture in Picture. Where PiP is not possible, or on a Mac, the audio continues and the lock screen or Control Center shows the channel with play and pause.

## Acceptance criteria

Each criterion is testable in isolation and has a stable id. Do not renumber.

### AC-1a Long press opens the panel (tvOS)
Given full-screen live playback, zap bar visible or hidden, no overlay and no number-entry pill, and the engine `.playing`
When the user holds select for at least 0.5 s
Then `player.panel` exists with `player.panel.segments`, `player.panel.hint` reading "Menu closes", and `player.panel.segment.info` having the `.isSelected` trait and focus; the engine state is still `.playing` with no `pause()` call and the same engine instance (DR-1); a visible zap bar is hidden first; the short-press action of 0007 and 0008 does not also fire. A press released before 0.5 s does what 0007 and 0008 say and opens no panel.

### AC-1b Long press while loading (tvOS)
Given full-screen live playback with the engine `.loading` or `.buffering`
When the user holds select for at least 0.5 s
Then the panel opens as in AC-1a and `player.panel.stream` reads "Stream details not available yet".

### AC-1c Long press with an error or the pill shown (tvOS)
Given `player.error` shown, or 0008's number-entry pill visible
When the user holds select for at least 0.5 s
Then `player.panel` does not exist; with the error shown the press acts as select on the focused `player.retry` (AC-6a); with the pill shown 0008's number-entry criteria apply unchanged.

### AC-2a Stream line text (core)
Given `PresentationInfo` values and routes
When `StreamLineText.describe(presentation:route:)` runs
Then it returns, per row: container "MPEG-TS", video codec "h264", height 1080, audio codec "aac", 6 channels, `.demuxer` yields "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna demuxer"; the same on `.system` ends in "System player"; height 576 yields "576p" (the height always prints as "<h>p", unlike the 0008/AC-7 badge, which hides below 720); height nil drops "1080p" and its space; audio codec nil with 6 channels yields "5.1" alone in that slot; container nil drops the first part and its separator; channel count outside the 0008/AC-7 mapping drops the layout; `presentation` nil yields "Stream details not available yet". Codec names come from `CodecName.display` (AC-29). The function is pure in AntennaCore, and its output never contains a URL because it takes none.

### AC-2b Info segment header (tvOS)
Given the panel open in locale en_GB on a channel with number 104, name "Sport One", source named "Acme TV", a current programme from 20:00 to 21:30 at 71% with 26 minutes left
When the Info segment is shown
Then `player.panel.logo` shows the logo or initials tile (0013/AC-7), `player.panel.channel` has the accessibility label "104 · Sport One · Acme TV", `player.panel.title` reads the programme title, `player.panel.times` reads "20:00–21:30 · 26 min left" (locale short time, en dash with no spaces, then 0008/AC-5's remaining text), and `player.panel.progress` has a fraction equal to elapsed over duration within 0.01.

### AC-2c Info segment without guide data (tvOS)
Given the panel open on a channel in the 0008/AC-6a, AC-6b or AC-6c guide state
When the Info segment is shown
Then `player.panel.title` reads that criterion's text ("No programme information", "Loading guide…" or "Guide unavailable"), `player.panel.times`, `player.panel.progress` and `player.panel.summary` do not exist, and `player.panel.badges` and `player.panel.stream` are as in AC-2d.

### AC-2d Info segment details (tvOS)
Given the panel open on the channel of AC-2b and the fake engine's presentation and route of AC-2a's first row
When the Info segment is shown
Then `player.panel.summary` reads the programme summary when it has one and does not exist otherwise, `player.panel.badges` shows the 0008/AC-7 badges, and `player.panel.stream` reads "MPEG-TS · H.264 1080p · AAC 5.1 · Antenna demuxer".

### AC-2e Info segment minute refresh (tvOS)
Given the panel open on a channel with a current programme
When the injected clock crosses a minute boundary
Then `player.panel.times` and `player.panel.progress` show the new values within one second of injected time (0008/AC-16).

### AC-3 Audio segment (tvOS)
Given the panel open and the engine reporting three audio tracks with distinct ids, the first selected in `selectedTrack[.audio]`, plus a fourth entry repeating the second's id
When focus moves to `player.panel.segment.audio`
Then `player.panel.tracks` lists `player.panel.track.<id>` once per distinct audio id in engine order (the repeated id appears once, first occurrence wins), each reading `MediaTrack.displayName` (AC-11) with the codec (AC-29) and the 0008/AC-7 channel layout as detail; the row whose id equals `selectedTrack[.audio]` carries the `.isSelected` trait and the checkmark; swiping down or pressing select puts focus on that row; select on another row calls `select(track, kind: .audio)` exactly once with that track and the panel stays open. Selection is read from `selectedTrack`: after the fake updates it the new row and only that row has `.isSelected`; if the fake leaves it unchanged the old row stays selected.

### AC-4a Subtitles segment with tracks (tvOS)
Given the panel open and the engine reporting two subtitle tracks, one forced, and `selectedTrack[.subtitle]` nil
When focus moves to `player.panel.segment.subtitles`
Then the list begins with `player.panel.track.off` reading "Off" with `.isSelected`, then the tracks in engine order with "Forced" as the detail of a forced track; select on a track calls `select(track, kind: .subtitle)` once; select on Off calls `select(nil, kind: .subtitle)` once; `.isSelected` follows `selectedTrack[.subtitle]` as in AC-3.

### AC-4b Subtitles segment without tracks (tvOS)
Given the panel open and the engine reporting zero subtitle tracks
When focus moves to `player.panel.segment.subtitles`
Then the list is `player.panel.track.off`, selected and focusable, followed by `player.panel.noSubtitles` reading "No subtitles in this stream", not focusable.

### AC-5 Menu closes the panel (tvOS)
Given the panel open with focus on any segment or row
When the user presses Menu
Then `player.panel` is gone, the engine state and instance are unchanged, no `load(_:)`, `pause()` or `select` call was made by the dismissal, focus is on the player, and Menu is consumed (0015/AC-3 does not fire).

### AC-5a Inputs while the panel is open (tvOS)
Given `player.panel` open
When the user swipes in any direction or presses play/pause
Then swipes move focus inside the panel and never tune (0008/AC-9 does not fire), play/pause makes no engine call and shows no bar (0008/AC-2 does not fire), and no `load(_:)` is recorded.

### AC-6a Retry a failed stream
Given `player.error` shown for `.failed(f)` on any platform
When the user activates `player.retry` (on tvOS by select on the focused button or by play/pause)
Then `load(_:)` is called once with the current channel and then `play()` once, `player.error` is gone on the next render after the `load(_:)` call, `player.buffering` follows AC-16a, and no channel-change event (0008/AC-1) is emitted.

### AC-6b Retry that fails
Given a retry per AC-6a in progress
When the engine reports `.failed(g)` before the load has played 30 s
Then AC-17a shows with g at once and AC-19a issues no reconnect.

### AC-7 Play/pause elsewhere (tvOS)
Given the Guide tab (0009) or a content tab (0015/AC-5a) is shown
When the user presses play/pause
Then no engine call is made and no view is presented; 0015/AC-5b governs resume.

### AC-8a Transport strip visibility (tvOS, blocked on 0019)
Given 0019 reports timeshift active and the engine `.paused` or `.playing` in full-screen live playback
When timeshift becomes active, a remote input arrives, or five seconds pass on the injected clock after the last input
Then `player.transport` appears on activation and on any remote input, hides five seconds after the last input while `.playing`, stays while `.paused`, is never shown together with `zapBar.root` (the bar wins and the strip returns when the bar hides), stays shown under an open `player.panel` with none of its elements focusable while the panel is open, and does not exist while timeshift is inactive.

### AC-8b Transport strip contents (tvOS, blocked on 0019)
Given `player.transport` shown with buffer start B, live edge L and position P from 0019
When it renders
Then `player.transport.playPause` shows the play glyph when `.paused` and the pause glyph when `.playing`, `player.transport.scrubber` has a fraction equal to (P − B) over (L − B) within 0.01, `player.transport.position` reads the locale short time of P followed by " · <n> min behind live" (0008/AC-5's minute rounding; "Live" when L − P is under 60 s), and `player.transport.bufferStart` reads "Buffer from <short time of B>".

### AC-8c Go to live focus (tvOS, blocked on 0019)
Given `player.transport` shown, the panel closed
When L − P is 60 s or more, or under 60 s
Then at 60 s or more `player.transport.goLive` exists and holds focus, select on it is 0019's criterion, and swipes up and down still tune per 0008/AC-9 because the player handles vertical swipes before the focus engine; under 60 s `player.transport.goLive` does not exist and the non-focusable LIVE badge is drawn in its place. Scrubbing and pause semantics are 0019's criteria.

### AC-9a Controls additions, regular width and full screen (iOS, iPadOS, macOS)
Given a channel playing inline at regular horizontal size class, or in full screen at any width
When the 0010/AC-10a controls are shown
Then they also contain, in this order after `browse.player.live` and before `browse.player.pip` (or `browse.player.fullscreen` where PiP is absent): `player.tracks`, `player.airplay` when the engine reports `supportsAirPlay`, and on macOS `player.mute` and `player.volume`.

### AC-9b Controls additions, compact inline (iOS, iPadOS)
Given a channel playing inline at compact horizontal size class (iPhone, or iPad in a narrow Split View or Slide Over window)
When the controls are shown
Then only `player.tracks` is added, between `browse.player.live` and `browse.player.pip`; `player.airplay`, `player.mute` and `player.volume` do not exist.

### AC-9c Hit areas and labels (iOS, iPadOS, macOS)
Given the controls of AC-9a or AC-9b shown
When their frames and labels are read
Then each added control has a hit area of at least 44 by 44 pt and the accessibility labels are "Audio and subtitles" (`player.tracks`), "AirPlay" (`player.airplay`), "Mute" or "Unmute" by state (`player.mute`) and "Volume" with the value as a percentage (`player.volume`).

### AC-10a Track picker presentation (iOS, iPadOS, macOS)
Given the engine reporting three audio tracks and two subtitle tracks
When the user activates `player.tracks` at compact horizontal size class, and in a second test at regular
Then `player.trackPicker` is presented as a sheet at compact and as a popover anchored to `player.tracks` at regular, and the 0010/AC-10b hide timer is suspended while it is open.

### AC-10b Track picker rows and selection (iOS, iPadOS, macOS)
Given `player.trackPicker` open per AC-10a
When the rows are read and one is activated
Then there is one `player.trackPicker.audio.<id>` row per audio track under AC-3's content, de-duplication and selection rules, `player.trackPicker.subtitles.off` and `player.trackPicker.subtitles.<id>` rows under AC-4a's rules, or `player.trackPicker.subtitles.none` reading "No subtitles in this stream", not selectable, when there are no subtitle tracks; activating a row calls `select` exactly once and the picker stays open.

### AC-10c Track picker footer (iOS, iPadOS, macOS)
Given `player.trackPicker` open
When the footer is read
Then `player.trackPicker.stream` reads AC-2a's output, with AC-13b's suffix on the `.demuxer` route.

### AC-10d Track picker dismissal (iOS, iPadOS, macOS)
Given `player.trackPicker` open
When the user activates `player.trackPicker.done` (compact), taps outside it, or presses Escape
Then `player.trackPicker` is gone, no `select` call was made by the dismissal, and the 0010/AC-10b hide timer restarts.

### AC-10e Tracks change while the picker is open (iOS, iPadOS, macOS)
Given `player.trackPicker` open
When the engine's `tracks` change (a reconnect re-enumerates them)
Then the rows match the new list on the next render with selection from `selectedTrack`, and the picker stays open.

### AC-11 Track display name (core)
Given `MediaTrack` values with `languageCode` "en" and `name` nil; "en" and name "Commentary"; nil and name "Director"; nil and nil as the fourth audio track; and "zxx"
When `displayName(in: Locale(identifier: "en_GB"), index:)` runs, where `index` is the 0-based position among tracks of the same `kind` in engine order
Then the results are "English", "English (Commentary)", "Director", "Track 4" and "No language"; a `languageCode` the locale cannot name falls back to the code in upper case; the function is pure and lives in AntennaCore.

### AC-12a Tracks button without a choice (iOS, iPadOS, macOS)
Given the engine reporting one audio track and no subtitle track
When the controls are shown
Then `player.tracks` exists and is not enabled.

### AC-12b Tracks arriving late (iOS, iPadOS, macOS)
Given `player.tracks` not enabled per AC-12a
When the engine reports a second audio track or any subtitle track
Then `player.tracks` is enabled on the next render.

### AC-12c One track on tvOS
Given the engine reporting one audio track and no subtitle track on tvOS
When the user long-presses select per AC-1a and moves to the Audio segment
Then the panel opens and the Audio segment lists the one track, selected.

### AC-13a AirPlay route picker (iOS, iPadOS, macOS)
Given the engine on the `.system` route with `supportsAirPlay` true
When the user activates `player.airplay`
Then `player.airplay` is backed by an `AVRoutePickerView` in the view hierarchy, and the tap reaches it (UI test). Device layer: the system picker appears and the chosen route is the system's.

### AC-13b AirPlay on the demuxer route (iOS, iPadOS, macOS)
Given the engine on the `.demuxer` route with `supportsAirPlay` false
When the controls and the track picker are shown
Then `player.airplay` does not exist and `player.trackPicker.stream` reads AC-2a's output with the suffix " · AirPlay not available for this stream".

### AC-13c External playback active (iOS, iPadOS, macOS)
Given the fake engine reporting `isExternalPlaybackActive` true
When the player is shown
Then the video frame shows `player.airplayPlaceholder` reading "Playing on AirPlay" (no device name, DR-12) and the controls stay; the placeholder is gone on the next render after the flag returns to false.

### AC-14a Volume slider (macOS)
Given a channel playing on macOS
When the user drags `player.volume` to a value v
Then the engine's `volume` equals v in 0...1, the app is unmuted if it was muted, and the slider and `player.mute` glyph show the engine value on the next render.

### AC-14b Mute and unmute (macOS)
Given a channel playing on macOS with engine volume v
When the user activates `player.mute` or presses M with focus outside a text field, and then does so again
Then the first activation sets the engine volume to 0 and keeps v as the pre-mute value; the second restores v; with v already 0 and not muted, the first activation does nothing.

### AC-14c Volume keys (macOS)
Given a channel playing on macOS with focus outside a text field
When the user presses Command-Up or Command-Down
Then the engine volume changes by 0.1, clamped to 0...1, and a mute in effect is cleared.

### AC-14d Volume persists (macOS)
Given the volume changed per AC-14a to AC-14c with an injected `UserDefaults` suite
When the app relaunches with the same suite
Then the keys `player.volume` and `player.volume.beforeMute` were written on every change, and the engine starts at the stored `player.volume`, or at the stored pre-mute value unmuted when the app quit muted. `player.volume` and `player.mute` do not exist on iOS and iPadOS.

### AC-15 Seek shortcuts (iPadOS, macOS, blocked on 0019)
Given a hardware keyboard and focus on the player (the video frame or one of its controls), not on the sidebar, a list or a text field
When Left or Right is pressed with 0019 timeshift active, or Option-Left or Option-Right
Then the position moves −10 s, +10 s, −60 s or +60 s through 0019's seek, clamped to the buffer; with timeshift inactive the keys make no engine call; with focus on the sidebar or list the keys are 0010/AC-14's and make no engine call.

### AC-16a Buffering indicator
Given the engine `.loading` or `.buffering`
When 500 ms pass on the injected clock in that state
Then `player.buffering` exists centred in the video frame (64 pt on tvOS, 44 pt elsewhere), `browse.player.playPause` stays hittable on iOS, iPadOS and macOS, and `player.buffering` is gone on the next render after the state becomes `.playing`, `.paused` or `.failed`; a state that returns to `.playing` before 500 ms shows nothing.

### AC-16b Buffering caption
Given `player.buffering` shown
When 10 s pass on the injected clock after the ring appeared, the engine still `.loading` or `.buffering`
Then `player.buffering.caption` reads "Still buffering. <source name> is sending data slowly." (DR-15) and is removed together with the ring.

### AC-17a Error surface
Given the engine `.failed(f)` and AC-19a's reconnect exhausted or not applicable
When the player is shown on any platform
Then `player.error` replaces the video on the ground colour, `player.error.title` and `player.error.body` equal `PlaybackFailureText.describe(f, source:signInOnDevice:)` (AC-18), and `player.retry` is labelled "Try again".

### AC-17b Error surface details (tvOS)
Given `player.error` shown on tvOS for a failure reported at injected-clock time T
When it renders
Then `player.error.detail` reads "Source: <source name> · Attempted at <locale short time of T>", `player.error.hint` reads "Swipe up or down for another channel. Menu opens the tab bar.", and `player.retry` has focus.

### AC-17c Error surface and the controls (iOS, iPadOS, macOS)
Given `player.error` shown on iOS, iPadOS or macOS
When it renders inline and, in a second test, in full screen
Then `player.error.detail` and `player.error.hint` do not exist, the 0010 controls row is hidden except `browse.player.fullscreen` in full screen, `browse.player.live` is hidden, and `browse.nowPlaying` (compact) or `browse.panel` (regular) still exists with the channel's name.

### AC-17d Error surface and the zap bar (tvOS)
Given `player.error` shown on tvOS
When 0008's bar is visible
Then the bar shows the channel's metadata with no LIVE or format badges (0008/AC-7) for its five seconds, and `player.retry` keeps focus when it hides.

### AC-17e Failure over other surfaces
Given `player.panel` open (tvOS), `player.trackPicker` open, `player.pipPlaceholder` shown or `player.airplayPlaceholder` shown
When the engine reports a failure that AC-17a shows
Then the panel or picker is dismissed before `player.error` appears; with PiP active `PictureInPictureController.stop()` is called once and `player.error` shows inline; with external playback active the placeholder is replaced by `player.error`.

### AC-18 Failure text (core)
Given source name "Acme TV" and a stall limit of 15 s
When `PlaybackFailureText.describe(_:source:signInOnDevice:stallLimit:)` runs for each case with `signInOnDevice` false unless stated
Then it returns:

| Failure | Title | Body |
|---------|-------|------|
| `.httpStatus(404)` | Stream not found | Acme TV returned 404 for this channel. The channel may have moved or been removed by the provider. |
| `.httpStatus(n)` with n in 500...599 | Provider error | Acme TV returned <n>. Its server is having trouble. Try again in a moment. |
| `.httpStatus(n)`, any other n (below 400, 400...499 except 404) | Stream unavailable | Acme TV returned <n> for this channel. |
| `.unauthorized`, `signInOnDevice` false | Sign-in refused | Acme TV rejected the login. Check the username and password in Settings, or ask the provider whether the account has expired. |
| `.unauthorized`, `signInOnDevice` true | Sign-in refused | Acme TV rejected the login. Sign in again on this Apple TV, or ask the provider whether the account has expired. |
| `.offline` | You're offline | Connect to the internet and try again. Playback resumes on its own when the connection returns. |
| `.network(code)` | Could not reach Acme TV | The connection failed (<plain name>). Check the network, or a VPN if one is on. |
| `.timeout` | Stream stopped | Acme TV did not send any data for 15 seconds. |
| `.stalled` | Stream stopped | Acme TV stopped sending data. |
| `.credentialMissing`, `signInOnDevice` false | Waiting for login | The login for Acme TV has not reached this device from iCloud Keychain yet. |
| `.credentialMissing`, `signInOnDevice` true | Sign in needed | Sign in to Acme TV on this Apple TV to play its channels. |
| `.unsupportedCodec("hevc")` | Format not supported | This stream uses HEVC, which this device cannot play. Trying again will not help. Pick another channel or ask the provider for a stream in a supported format. |
| `.malformedStream` | Stream could not be read | Acme TV sent data that is not a playable stream. The address may point to a web page or an empty file. |

The plain names for `.network` are: `.timedOut` "timed out"; `.cannotFindHost` and `.dnsLookupFailed` "host not found"; `.cannotConnectToHost` "connection refused"; `.secureConnectionFailed`, `.serverCertificateUntrusted`, `.serverCertificateHasBadDate` and `.serverCertificateNotYetValid` "secure connection failed"; any other code "network error <rawValue>". The codec name in `.unsupportedCodec` comes from `CodecName.display` (AC-29). For every case `title` and `body` contain no "://", no "player_api", no "/live/", "/movie/" or "/series/", and no byte of the fixture credential "s3cr3t-9b2a" or host "panel.example". The function is pure in AntennaCore and takes no URL. The app passes `signInOnDevice` true on tvOS, where the credential does not sync, and false elsewhere (0006's header on `kSecAttrSynchronizable`), and passes 0017's `stallLimit`.

### AC-19a Automatic reconnect schedule
Given live playback and the engine becoming `.failed(f)` with f one of `.stalled`, `.timeout`, `.network(_)`, `.httpStatus(n)` with n in 500...599, or `.offline` while the path monitor reports satisfied (AC-20b)
When the failure is reported and either the current load has played 30 s or an AC-19a schedule is already running
Then `load(_:)` is called with the current channel and then `play()` after 2 s on the injected clock for attempt 1, after 4 s following the next such failure (attempt 2), and after 8 s following the one after (attempt 3); the attempt count resets to 0 after 30 s of continuous `.playing`; the previous audio and subtitle choice is re-applied per AC-30.

### AC-19b Reconnect caption
Given an AC-19a schedule waiting for or running attempt k
When the player is shown
Then `player.reconnecting` reads "Reconnecting… attempt <k> of 3" centred over the video frame and `player.buffering` does not exist.

### AC-19c Reconnect cancelled
Given an AC-19a schedule running
When a fourth such failure arrives, the user tunes, `stop()` is called, or on tvOS the scene leaves the foreground
Then no further reconnect `load(_:)` is recorded; the fourth failure shows AC-17a with the latest f; a tune shows nothing of this schedule; on tvOS AC-28 applies on return. On iOS, iPadOS and macOS leaving the foreground does not cancel the schedule while background audio (AC-25a, AC-25b) or PiP is active.

### AC-19d Reconnect exhausted during Picture in Picture (iOS, iPadOS)
Given PiP active and an AC-19a schedule at attempt 3
When the fourth failure arrives
Then `PictureInPictureController.stop()` is called once and AC-17a shows inline.

### AC-19e Failures that do not reconnect
Given live playback
When the engine reports `.failed(f)` with f one of `.httpStatus(404)`, any `.httpStatus` outside 500...599, `.unauthorized`, `.credentialMissing`, `.unsupportedCodec`, `.malformedStream`, or `.offline` while the path monitor reports unsatisfied; or any reconnectable f before a user-initiated load has played 30 s with no schedule running
Then AC-17a shows at once and no reconnect `load(_:)` is recorded.

### AC-20 Offline recovers when the network returns
Given `player.error` shown for `.offline` and an injected network path monitor reporting unsatisfied
When the monitor reports satisfied
Then `load(_:)` is called once with the current channel and `play()` once within one second, `player.error` is gone on the next render after the call and `player.buffering` follows AC-16a; a second satisfied report within the same error does not call `load` again. On iOS, iPadOS and macOS this applies in the background while background audio or PiP is active; on tvOS it applies on the next scene activation.

### AC-20b Offline with the path already satisfied
Given the engine reporting `.failed(.offline)` while the injected path monitor reports satisfied (a dropped connection on a network that is still up)
When the failure is reported
Then it is handled as a reconnectable failure under AC-19a, and AC-20 does not fire.

### AC-21a Credential arrives (blocked on 0017)
Given `player.error` shown for `.credentialMissing` on a channel whose source lost its Keychain item after the channel list loaded
When the app polls the injected credential store every 5 s on the injected clock while the error is shown, or at the next scene activation, and the item for that source's `credentialKey` is present
Then `load(_:)` is called once with the current channel (0017 builds the URL from the restored credential) and `play()` once, and `player.error` is gone on the next render after the call; polling stops when the error is gone.

### AC-21b Sign in from the error (tvOS, blocked on 0017)
Given `player.error` shown for `.credentialMissing` on tvOS, where `signInOnDevice` is true
When the user selects `player.signIn`, present after `player.retry`
Then 0006/AC-21's "Sign in on this Apple TV" step opens for that source; on success it returns to full-screen playback of the same channel with one `load(_:)` call, and on Menu it returns to `player.error` with `player.retry` focused.

### AC-22a Picture in Picture starts (iOS, iPadOS)
Given a channel `.playing` inline or in full screen with `supportsPictureInPicture` true
When the user activates `browse.player.pip`
Then the fake `PictureInPictureController` records `start()` once, and when it reports active the video frame shows `player.pipPlaceholder` reading "Playing in Picture in Picture", the engine state stays `.playing` on the same instance, and full screen exits to the inline layout.

### AC-22b Tune while Picture in Picture is active (iOS, iPadOS)
Given PiP active per AC-22a
When the user selects another channel in the list
Then the channel list rows are hittable during PiP, selecting one calls `load(_:)` once on the same engine instance with that channel, PiP stays active, and `player.pipPlaceholder` stays. If the new channel fails, AC-17e applies.

### AC-23 Automatic Picture in Picture on leaving the app (iOS, iPadOS)
Given a channel `.playing` inline or in full screen with `supportsPictureInPicture` true
When the user leaves the app with the Home gesture
Then PiP starts without a tap (the controller is configured to start automatically from inline), the engine state stays `.playing`, and tapping the PiP window's restore control returns to the Live section with the same channel and no `load(_:)` call. Device layer: the system starts automatic PiP only on a real app switch.

### AC-24a Picture in Picture closed (iOS, iPadOS)
Given PiP active
When the user closes the PiP window with its close control
Then `pause()` is called once, `player.pipPlaceholder` is replaced by the paused inline player with the play glyph, and the next `browse.player.playPause` calls `play()` once (the position is 0017's or 0019's).

### AC-24b Picture in Picture restored (iOS, iPadOS)
Given PiP active
When the user restores the PiP window
Then no engine call is made and the inline player shows the picture again.

### AC-25a Background audio (iOS, iPadOS)
Given a channel `.playing` and PiP not started (`supportsPictureInPicture` false, or `presentation.videoHeight` nil once presentation is known, meaning no video track)
When the scene phase becomes `.background`
Then the audio session category is `.playback` with mode `.moviePlayback`, and no `pause()` or `stop()` call is made on the phase change; given the engine `.paused` when the app leaves, nothing changes. Device layer: the audio continues for at least 60 s with the screen locked.

### AC-25b Background audio (macOS)
Given a channel `.playing`
When the window is hidden or the app is deactivated
Then no `pause()` or `stop()` call is made on that change. Device layer: the audio continues for at least 60 s with the app hidden.

### AC-26a Now Playing fields (iOS, iPadOS, macOS)
Given a channel numbered 104, named "Sport One", `.playing`, with a current programme "Evening News", and the logo not yet cached
When Now Playing is read
Then `MPNowPlayingInfoCenter` holds "Evening News" as the title, "104 Sport One" as the artist, no artwork, `isLiveStream` true and playback rate 1; with no current programme the title is "Sport One" and the artist the source name; within five seconds of injected time after the logo is cached the artwork is set; with the engine `.paused` the playback rate is 0.

### AC-26b Remote commands (iOS, iPadOS, macOS)
Given a channel `.playing` or `.paused`
When the remote command center's play, pause or toggle command fires
Then `play()` or `pause()` is called once per command, and the previous and next track commands are disabled.

### AC-26c Now Playing updates (iOS, iPadOS, macOS)
Given Now Playing set per AC-26a
When the injected clock crosses a programme boundary or the channel changes
Then the fields hold the new values within five seconds of injected time.

### AC-27 Audio interruption (iOS, iPadOS)
Given a channel `.playing`
When an audio session interruption begins
Then `pause()` is called once; when it ends with `.shouldResume`, `play()` is called once; when it ends without it, no call is made and the inline player shows the paused state.

### AC-28 Background on tvOS
Given a channel on tvOS
When the scene phase becomes `.background` and later `.active`
Then with the engine `.playing` on the way out, `pause()` is called once then and `play()` once on the way back on the same engine instance with no `load(_:)`; with the engine `.paused` or `.failed` on the way out, no call is made in either direction. The resume `play()` counts as a load that has played 30 s, so a reconnectable failure within the next 30 s starts AC-19a's schedule instead of showing AC-17a at once.

### AC-29 Codec display names (core)
Given codec identifiers as the demuxer or AVFoundation reports them
When `CodecName.display(_:)` runs
Then "h264" and "avc1" yield "H.264"; "hevc", "hvc1" and "hev1" yield "HEVC"; "mpeg2video" yields "MPEG-2"; "aac" and "mp4a" yield "AAC"; "ac3" yields "AC-3"; "eac3" and "ec-3" yield "E-AC-3"; "mp2" yields "MP2"; "mp3" yields "MP3"; matching ignores case; any other identifier yields itself in upper case. The function is pure in AntennaCore and is used by AC-2a, AC-3 and AC-18.

### AC-30 Track choice survives a reconnect
Given the user selected an audio track with language "de" and name "Kommentar", and the English subtitle track, before an AC-19a reconnect
When the reconnect load reports its tracks
Then `select` is called once per kind with the first track whose `languageCode` and `name` both match the earlier choice; where no track matches, no `select` call is made for that kind and the engine default stays. A user tune or AC-6a retry does not re-apply the choice.

### AC-31 Background audio entitlement (build)
Given `project.yml`
When the Mobile target's Info.plist properties are read
Then `UIBackgroundModes` contains `audio`, and the TV target's does not.

### AC-32 No URL or secret in player logs
Given a `PlayerModel` run through AC-6a, AC-17a, AC-19a and AC-21a with the fake engine, a channel whose fixture stream URL contains host "panel.example" and credential "s3cr3t-9b2a", and an injected log sink
When the run ends
Then no recorded log line, accessibility label, identifier or Now Playing field contains "panel.example", "s3cr3t-9b2a" or "://".

## Dropped

- AC-1 (long press opens the panel): split into AC-1a, AC-1b and AC-1c; three Givens.
- AC-2 (Info segment contents): split into AC-2a (core formatter), AC-2b (UI contents) and AC-2c (guide states and minute refresh); it held ten assertions and no formatter name. In the third round AC-2b split again into AC-2b and AC-2d, and the minute refresh moved from AC-2c to AC-2e.
- AC-4 (Subtitles segment): split into AC-4a and AC-4b; two Givens.
- AC-6 (retry): split into AC-6a and AC-6b; the failing retry is a second When.
- AC-8 (transport strip): split into AC-8a, AC-8b and AC-8c; ten assertions and no focus path to Go to live.
- AC-9 (controls additions): split into AC-9a and AC-9b; two Givens. AC-9c took the hit-area and label clauses from both.
- AC-10 (track picker): split into AC-10a to AC-10e; presentation, rows, footer, dismissal and late tracks.
- AC-12 (tracks button without a choice): split into AC-12a, AC-12b and AC-12c.
- AC-13 (AirPlay): split into AC-13a, AC-13b and AC-13c; three Givens and no fakeable external-playback state.
- AC-14 (volume and mute): split into AC-14a to AC-14d; slider, mute, keys and persistence.
- AC-16 (buffering indicator): split into AC-16a and AC-16b; the caption is a second Given.
- AC-17 (error surface): split into AC-17a to AC-17d by platform and element group; AC-17e is new.
- AC-19 (automatic reconnect): split into AC-19a to AC-19e. Its Given required 30 s of `.playing` before every attempt, which made attempts 2 and 3 unreachable; AC-19a counts an attempt as reconnectable while a schedule runs. Leaving the foreground no longer cancels the schedule on iOS, iPadOS and macOS (AC-19c).
- AC-21 (credential arrives): split into AC-21a (polling) and AC-21b (tvOS sign-in).
- AC-22 (PiP starts): split into AC-22a and AC-22b; the tune while active is a second When.
- AC-24 (PiP ends): split into AC-24a (close) and AC-24b (restore); two tests in one criterion.
- AC-25 (background audio): split into AC-25a and AC-25b; `AVAudioSession` does not exist on macOS. In the third round both lost their 60 s injected-clock clause, which proved nothing about the system suspending audio, and gained a device layer.
- AC-26 (Now Playing and remote commands): split into AC-26a, AC-26b and AC-26c.

## Edge cases and failure modes

- Zero channels or no sources: the player is never shown (0006/AC-1, 0015/AC-11); nothing here applies.
- Huge sources: no criterion here scales with channel count; the track list is bounded by the stream.
- Malformed stream bytes: `.malformedStream` (AC-18) or `.unsupportedCodec` from 0017; neither reconnects (AC-19e).
- Credential not yet synced: on iOS, iPadOS and macOS a source without a credential contributes no channels (0004/AC-10), so `.credentialMissing` arises only when the item disappears after the list loaded (AC-21a); on tvOS 0006/AC-21 is the sign-in path (AC-21b). A credential that disappears during playback produces `.unauthorized` or `.credentialMissing` on the next load, never a crash.
- Slow source: AC-16b's caption ten seconds after the ring; 0017's stall limit decides when buffering becomes `.timeout`.
- Offline: a lost network with the path unsatisfied shows AC-17a and waits for AC-20; a dropped connection on a path that is still up reconnects under AC-20b.
- A failure while the overlay (0007), guide (0009) or a content tab (0015) is open: `player.error` is drawn in `shell.player` or 0009's box under them; 0007/AC-9a and 0015/AC-18 re-tune on select.
- A channel change while `player.error` or `player.panel` is shown dismisses both before `load(_:)`; AC-19a's count is reset and AC-30 does not apply.
- Long press on select while the panel is open does nothing; select on a segment moves focus into its list; swipe up from the first row returns to the segments.
- Remote-only input: every element of the panel and error surface is reachable by swipe; `player.transport.goLive`, `player.retry` and `player.signIn` are the only focusable elements of their surfaces.
- Track selection applies to the current item and to AC-19a reconnects of it (AC-30); a tune starts from the engine's default (preferred language is out of scope).
- PiP unsupported (`supportsPictureInPicture` false): `browse.player.pip` is disabled per 0010/AC-13 and AC-25a covers backgrounding.
- PiP active and the app is terminated by the system: nothing is persisted here; 0015's last-channel key is unaffected on tvOS; on iOS the Live section restores per 0010.
- AirPlay on the `.demuxer` route is not offered because `AVSampleBufferVideoRenderer` output cannot be routed; screen mirroring still works and is the system's.
- Reduce Motion: panel, strip, picker and error appear without slide or fade.
- VoiceOver: `player.error` is announced once with title and body when it appears; `player.buffering` announces "Buffering" after the 500 ms delay and nothing on removal; track rows read name, detail and "selected".
- Dynamic Type at accessibility sizes: the error body wraps; `player.retry` keeps 44 pt; the track picker rows grow.
- `Channel.streamURL` and the URL 0017 builds are never shown, logged, or placed in an identifier, label or Now Playing field (ADR-0003); AC-18, AC-2a and AC-32 test it.

## Test plan

The failure text table, the stream line, the codec names, the track display name and the reconnect schedule (pure function from attempt count to delay) are pure functions in AntennaCore. Player behaviour lives in a `@MainActor` `PlayerModel` in `Apps/Shared/Player/` that takes an injected engine, clock, `UserDefaults` suite, credential store, network path monitor, audio session (iOS, iPadOS), scene phase, log sink and Now Playing sink; integration tests drive it with the fake engine. UI tests launch with `-antenna.uiTest` plus arguments naming the fake engine's state, failure, tracks, route, presentation, PiP support and external-playback flag. Identifiers: `player.panel`, `player.panel.segments`, `player.panel.segment.info`, `player.panel.segment.audio`, `player.panel.segment.subtitles`, `player.panel.hint`, `player.panel.info`, `player.panel.logo`, `player.panel.channel`, `player.panel.title`, `player.panel.times`, `player.panel.progress`, `player.panel.summary`, `player.panel.badges`, `player.panel.stream`, `player.panel.tracks`, `player.panel.track.<id>`, `player.panel.track.off`, `player.panel.noSubtitles`, `player.transport`, `player.transport.playPause`, `player.transport.scrubber`, `player.transport.position`, `player.transport.bufferStart`, `player.transport.goLive`, `player.tracks`, `player.trackPicker`, `player.trackPicker.audio.<id>`, `player.trackPicker.subtitles.off`, `player.trackPicker.subtitles.<id>`, `player.trackPicker.subtitles.none`, `player.trackPicker.stream`, `player.trackPicker.done`, `player.airplay`, `player.airplayPlaceholder`, `player.mute`, `player.volume`, `player.buffering`, `player.buffering.caption`, `player.reconnecting`, `player.error`, `player.error.title`, `player.error.body`, `player.error.detail`, `player.error.hint`, `player.retry`, `player.signIn`, `player.pipPlaceholder`.

| Criterion | Layer | Test |
|-----------|-------|------|
| AC-1a | ui (tvOS, fake engine; long and short press) | TBD |
| AC-1b | ui (tvOS, fake engine `.loading` and `.buffering`) | TBD |
| AC-1c | ui (tvOS; error shown, pill shown) | TBD |
| AC-2a | core (parameterised table) | TBD |
| AC-2b | ui (tvOS, en_GB) | TBD |
| AC-2c | ui (tvOS, fake GuideStore) | TBD |
| AC-2d | ui (tvOS) | TBD |
| AC-2e | ui (tvOS, injected clock) | TBD |
| AC-3 | ui (tvOS, fake engine select log and `selectedTrack`) | TBD |
| AC-4a | ui (tvOS) | TBD |
| AC-4b | ui (tvOS) | TBD |
| AC-5 | ui (tvOS) | TBD |
| AC-5a | ui (tvOS, fake engine) | TBD |
| AC-6a | integration (PlayerModel) + ui (tvOS, iPhone) | TBD |
| AC-6b | integration (PlayerModel, injected clock) | TBD |
| AC-7 | integration (PlayerModel, per tab) | TBD |
| AC-8a | ui (tvOS, fake 0019 state, injected clock); blocked on 0019 | TBD |
| AC-8b | ui (tvOS, fake 0019 state); blocked on 0019 | TBD |
| AC-8c | ui (tvOS, fake 0019 state); blocked on 0019 | TBD |
| AC-9a | ui (iPad, macOS, iPhone full screen) | TBD |
| AC-9b | ui (iPhone, iPad Split View) | TBD |
| AC-9c | ui (iPhone, iPad, macOS) | TBD |
| AC-10a | ui (iPhone sheet, iPad popover) | TBD |
| AC-10b | ui (iPad; with and without subtitles) | TBD |
| AC-10c | ui (iPad, both routes) | TBD |
| AC-10d | ui (iPhone Done, iPad outside tap, macOS Escape) | TBD |
| AC-10e | ui (fake engine tracks changed while open) | TBD |
| AC-11 | core (parameterised) | TBD |
| AC-12a | ui (iPhone, iPad, macOS) | TBD |
| AC-12b | ui (fake engine tracks arriving late) | TBD |
| AC-12c | ui (tvOS) | TBD |
| AC-13a | ui (`AVRoutePickerView` present) + device | manual on iPhone with an Apple TV |
| AC-13b | ui (fake engine route) | TBD |
| AC-13c | ui (fake engine flag) | TBD |
| AC-14a | ui (macOS) | TBD |
| AC-14b | integration (PlayerModel) + ui (macOS) | TBD |
| AC-14c | ui (macOS keyboard) | TBD |
| AC-14d | integration (PlayerModel, injected `UserDefaults` suite) | TBD |
| AC-15 | ui (macOS; iPad `typeKey`) with fake 0019; blocked on 0019 | TBD |
| AC-16a | integration (injected clock) + ui (tvOS, iPhone) | TBD |
| AC-16b | integration (injected clock) | TBD |
| AC-17a | ui (per platform, parameterised failure) | TBD |
| AC-17b | ui (tvOS, injected clock) | TBD |
| AC-17c | ui (iPhone, iPad, macOS; inline and full screen) | TBD |
| AC-17d | ui (tvOS) | TBD |
| AC-17e | integration (PlayerModel, fake PiP) + ui (tvOS panel, iPad picker) | TBD |
| AC-18 | core (parameterised table, secret scan) | TBD |
| AC-19a | integration (PlayerModel, injected clock, fake engine) | TBD |
| AC-19b | integration (PlayerModel) + ui (tvOS) | TBD |
| AC-19c | integration (PlayerModel, scene phase per platform) | TBD |
| AC-19d | integration (fake PiP controller) | TBD |
| AC-19e | integration (PlayerModel, parameterised failure) | TBD |
| AC-20 | integration (fake path monitor) | TBD |
| AC-20b | integration (fake path monitor) | TBD |
| AC-21a | integration (fake credential store, injected clock); blocked on 0017 | TBD |
| AC-21b | ui (tvOS `player.signIn`); blocked on 0017 | TBD |
| AC-22a | integration (fake PiP controller) + ui (iPhone) | TBD |
| AC-22b | integration (fake PiP controller) + ui (iPhone) | TBD |
| AC-23 | device | manual on iPhone and iPad |
| AC-24a | integration (fake PiP controller close event) | TBD |
| AC-24b | integration (fake PiP controller restore event) | TBD |
| AC-25a | integration (fake audio session, scene phase) + device | manual on iPhone |
| AC-25b | integration (app activation) + device | manual on Mac |
| AC-26a | integration (Now Playing sink, injected clock) | TBD |
| AC-26b | integration (fake command center) | TBD |
| AC-26c | integration (Now Playing sink, injected clock) | TBD |
| AC-27 | integration (fake audio session notifications) | TBD |
| AC-28 | integration (PlayerModel scene phase, three engine states) | TBD |
| AC-29 | core (parameterised) | TBD |
| AC-30 | integration (PlayerModel, fake engine) | TBD |
| AC-31 | build (script check of `project.yml`) | TBD |
| AC-32 | integration (PlayerModel, log sink, secret scan) | TBD |

## Required of other specs

- 0017: `PlaybackFailure` as a typed enum in place of `failed(String)` with the cases above, a `.buffering` state or equivalent stall signal, `MediaTrack` enumeration, `selectedTrack` and `select`, `route` after sniffing, `presentation` extended with the container and video codec names and a no-video signal, `volume`, `supportsPictureInPicture` and a PiP controller that reports start, stop, close and restore events, `supportsAirPlay`, `isExternalPlaybackActive`, a `stallLimit` constant that AC-18's `.timeout` text quotes, `load(_:)` taking the channel (or its `credentialKey`) and building the Xtream URL from the Keychain at load time (until that lands `.credentialMissing` is unreachable and AC-21a and AC-21b are blocked), and the rule that `load(_:)` on a `.failed` engine starts a fresh attempt. None of its values may carry a URL.
- 0019: `isTimeshiftActive`, buffer start, live edge, position and `seek(by:)`, plus the supersession of 0008/AC-2 so that play/pause pauses live TV when a buffer exists. AC-8a to AC-8c and AC-15 read these and stay blocked until it merges.
- 0008: AC-2's Given narrows to "a channel is playing or loading"; with the engine `.failed`, play/pause follows 0018/AC-6a; while `player.panel` is open, AC-2 and AC-9 do not fire (0018/AC-5a); a select held for 0.5 s opens `player.panel` and does not fire 0008's select action (0018/AC-1a). Its Out item "Error display for failed playback" resolves to 0018/AC-17a, AC-17b and AC-17d.
- 0010: AC-10a's control list gains `player.tracks`, `player.airplay`, `player.mute` and `player.volume` per 0018/AC-9a to AC-9c; AC-13's "activation behaviour is the playback spec's" resolves to 0018/AC-22a; the Out items for PiP behaviour, background audio and error UI resolve to 0018/AC-22a to AC-27 and AC-17a and AC-17c.
- 0015: the Out item for the play/pause button resolves to 0018/AC-6a and AC-7; "the full-screen view shows the player's error state" resolves to 0018/AC-17a; the "return from background" edge case resolves to 0018/AC-28.
- 0007 and 0009: a tune while `player.error` or `player.panel` is shown dismisses both before `load(_:)`; 0007's edge case "play/pause toggles the engine while the overlay is open" does not apply while `player.panel` is open, which never coexists with the overlay; a select held for 0.5 s does not open 0007's overlay (0018/AC-1a).
- 0006: AC-21's step, when entered from `player.signIn` with a given source, returns to full-screen playback of the same channel on success and to `player.error` on Menu (0018/AC-21b).
- Design README: `player.` added to DR-11's prefixes; section 4 rows for the ten boards; "player controls on tvOS" removed from "Not yet drawn". Done in this PR.

## Open questions

Decisions made without an interview; each can be overturned at review.

- Long press on select (0.5 s) opens the tvOS panel. The system player uses swipe down, but 0008/AC-9 uses swipe down for channel down. Alternative: swipe left or right, which 0008 leaves unassigned.
- Play/pause is ignored on Guide and content tabs (AC-7). Alternative: toggle the engine there too.
- Three automatic reconnects at 2, 4 and 8 seconds (AC-19a). TiviMate's five retries are a complaint; the alternative is unlimited reconnects with growing delay and a persistent "Reconnecting" caption.
- A failure within 30 s of a user-initiated load shows the error at once instead of reconnecting (AC-19e), so a dead channel does not spend 14 s on retries. Alternative: reconnect from the first second.
- `.offline` with the path unsatisfied waits for the path monitor (AC-20); with the path still up it reconnects like a transport failure (AC-20b).
- The reconnect schedule keeps running in the background on iOS, iPadOS and macOS while audio or PiP is playing (AC-19c), and is cancelled on tvOS, which pauses on background (AC-28).
- Retry is offered for `.unsupportedCodec` even though the body says it will not help, so every error has the same focused control on tvOS. Alternative: hide Retry and focus a "Choose another channel" action that opens 0007's overlay.
- With timeshift active on tvOS, `player.transport.goLive` takes focus and vertical swipes still tune (AC-8c). Alternative: swipes stop tuning while the strip is shown. 0019 may move this.
- AirPlay is hidden on the demuxer route rather than offering a button that only mirrors the screen. Alternative: show it and let the system mirror.
- At compact inline width AirPlay has no button; it is in full screen and in Control Center. Alternative: an overflow menu holding tracks and AirPlay.
- Closing the PiP window pauses rather than stops (AC-24a). For live TV without 0019 a paused frame can be minutes stale; 0019 decides what resume means.
- Background audio is always on for live (AC-25a, AC-25b). A toggle needs the settings ADR.
- Now Playing uses the programme title as title and "<number> <channel>" as artist (AC-26a). The reverse is defensible.
- The track selection is per item, re-applied across AC-19a reconnects (AC-30) and forgotten on the next tune. A preferred-language setting is deferred to the settings spec.
- A Mac app quit while muted relaunches unmuted at its pre-mute volume (AC-14d), so the user is not met by a silent player with no visible cause. Alternative: relaunch muted.
- macOS volume lives in `UserDefaults` per device and is not synced; no ADR is needed for that. If the owner wants it synced, it becomes a `SettingsRecord` field under the settings ADR and AC-14d changes backing, not behaviour.
- The 0017 citations use `0017/AC-n (subject)` because 0017 is in flight. If 0017 lands with different names (for example `.stalled` folded into `.timeout`), AC-18's table is edited in the implementing PR, not renumbered.
- AC-8a to AC-8c and AC-15 stay here rather than moving to 0019 so the strip 0019 drives has one drawn home; if the owner prefers, 0019 absorbs them and this spec keeps the board as a Design note.
- The spec has 72 criteria. The reviewer suggested moving volume, seek keys, background audio and Now Playing (AC-14a to AC-15, AC-25a to AC-26c) into a separate player system-integration spec. They stay here so that the iPhone, iPad and Mac boards have one spec; splitting is a mechanical follow-up if the owner prefers it.
