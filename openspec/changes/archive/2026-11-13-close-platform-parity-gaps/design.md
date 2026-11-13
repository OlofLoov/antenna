# Design

## Context

See proposal.md for why. Each gap below was checked against the code on 2026-11-13 before it went into this change:

1. `ShelfPlayerView` draws the picture, subtitles, a close button and a tap to pause. It has no tracks button and no Apple TV panel. `ShelfPlayback` already starts each title by the Subtitles setting through `PlaybackOptions.subtitleMode`.
2. `LiveModel.offersMultiView` is false outside macOS, and `MultiViewWindow`, `LiveMultiViewKey` and `LiveMultiViewMenuExtra` draw nothing on iOS.
3. `AVPlayerEngine.attach(to:)` and `DemuxEngine.enablePictureInPicture()` create the Picture in Picture controller only on iOS and tvOS, and `PictureInPictureHooks.app` returns `.none` elsewhere.
4. `SearchFeed` hides the bell with `#if !os(tvOS)`. Apple TV already has reminders: the bell in the guide and the overlay, and an in-app banner (`TV-Reminder-Banner`). The bell is not a notification permission question, so it can go in Search.
5. `GuideSourcesList` hides the filter field with `#if !os(tvOS)`.
6. `Clipboard.system` is nil on macOS.
7. `GuideCompactScreen` has no filter; its doc comment says so.
8. The title page's Trailer opens the link with `openURL`. On Apple TV the button is absent. Xtream panels send a YouTube id or link in nearly every case, which tvOS cannot open.

Boards, under `openspec/specs/design-system/boards/`:
- New: `iPhone-Title-Player-Tracks.dc.html` (the movie player with the tracks and subtitles buttons top right and the sheet open), `iPad-Title-Player-Tracks.dc.html` (the same with the popover, iPad and Mac), `TV-Title-Player-Tracks.dc.html` (the panel with Audio and Subtitles tabs only).
- Changed: `iPad-MultiView.dc.html` (a note that the frame now also stands for iPad, where touch replaces click and hover), `iPad-Player.dc.html` (the Picture in Picture button also on Mac), `TV-Search.dc.html` (the bell after a later programme's row), `TV-GuideSources.dc.html` (the search field over the channel list), `TV-Title.dc.html` (Trailer after My list), `iPhone-Guide.dc.html` (the pull-down search field).
- Not drawn: the Mac add-source sheet with the clipboard banner (the iPhone banner, `iPhone-Onboard-2`, in the shared sheet), the trailer playing on Apple TV (the movie player, a full-screen picture with no chrome), and the system's Picture in Picture window.

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled".

## Goals / Non-Goals

**Goals:**
- Each gap closed with the components and models that already serve the other platforms.
- Every platform difference that stays is written down here with its reason.

**Non-Goals:**
- Widgets, multi-view on iPhone, Picture in Picture on Apple TV, YouTube trailers on Apple TV.
- Remembering a track pick per movie. Live remembers per channel because people come back to the same channel; a film is watched once.

## Decisions

### Tracks in the movie player

`ShelfPlayback` gains `tracks: TitleTracks?`, a small `@Observable` model made in `start(_:from:source:)` for each title. It follows the engine's `tracks()` and `presentation()` streams, works out the route the way `PlayerModel.currentRoute()` does, and exposes `audioRows`, `subtitleRows`, `hasTrackChoices`, `subtitlesOn`, `canSwitchSubtitles`, `streamLine`, `selectAudio`, `selectSubtitle`, `switchSubtitles`, `pickerOpen` and `panel`. The rows come from `TrackMenu`, `TrackChoice` and `StreamLine` in AntennaCore, so both players read the same rules.

Options considered:
- Reuse `PlayerModel`. It is built around a channel: `PlayerSubject`, timeshift, reconnect waiting, login checks, catch-up. A movie would carry a fake channel to get the track lists.
- Move the track state out of `PlayerModel` into `TitleTracks` and have both use it. Cleaner in the end, but it touches every Live view and test for a change about movies; left for a later refactor.
- A small model for titles (chosen). The duplicated part is the wiring of two streams and five computed properties.

On iPhone, iPad and Mac `ShelfPlayerView` puts `TrackPicker.OpenButton` and `TrackPicker.SubtitlesButton` in a capsule at the top right, across from Close, and opens `TrackPicker.Sheet` at compact width and `TrackPicker.Popover` otherwise, as `LivePicture` does. The identifiers are the Live ones (`player.tracks`, `player.subtitles`, `player.trackPicker.*`), so the UI tests read the same.

On Apple TV holding select opens a `TitleTVPanel`: `InfoPanel.Frame` with the Audio and Subtitles segments and the Subtitles switch, built from the `InfoPanel` parts the Live panel uses. There is no Info tab: the title page already shows the details and the movie has no guide line. Menu closes the panel before it closes the movie. Identifiers follow the Live panel (`player.panel.segment.audio`, `player.panel.track.<n>`).

### Multi-view on iPad

`MultiViewMacScreen` becomes `MultiViewGridScreen` and builds on iOS too. Its gestures already map to touch: `onTapGesture` selects, `onTapGesture(count: 2)` enlarges, `onHover` shows the close button under an iPad pointer, the selected tile always shows it, and the keyboard shortcuts work with a hardware keyboard. On iPad the grid drops the Mac's minimum width, since an iPad window cannot be widened by the app.

The offer: `LiveModel.offersMultiView` stays the Mac's screen check; `LiveMultiViewMenuItem` and `LiveMultiViewKey` pass `offered:` from the horizontal size class on iPad (regular offers it). `LiveRegularView` ends multi-view through `MultiViewModel.leave()` when the size class turns compact, which keeps the selected tile playing on the single engine.

Options considered:
- The Apple TV screen (`MultiViewTVScreen`). It is built for focus and a remote, with a pick mode and an actions sheet; touch would need all of it redone.
- A new iPad screen. The board `iPad-MultiView` already draws the shared iPad and Mac frame; a second screen would draw the same tiles twice.
- The Mac grid (chosen).

The four-tile cap stays. Four tiles on iPad hardware are not measured yet; that check belongs with the multi-view requirement "Four tiles hold up on real hardware". A tile that cannot decode fails with its reason, as on the other platforms.

### Picture in Picture on Mac

AVKit's `AVPictureInPictureController` exists on macOS for both `AVPlayerLayer` and an `AVSampleBufferDisplayLayer` content source, so the guards in `AVPlayerEngine.attach(to:)`, `DemuxEngine+PictureInPicture.swift`, `PictureInPictureWatch` and `startPictureInPicture()` widen from `os(iOS) || os(tvOS)` to include macOS. `canStartPictureInPictureAutomaticallyFromInline` stays iOS only: a Mac window that loses focus keeps playing in place, so the window opens only from the button. The `PictureInPictureButton` joins the Mac controls after the volume slider. Closing the window pauses and returning restores, through the same delegate as iOS.

### Picture in Picture on Apple TV: not now

tvOS has `AVPictureInPictureController`, and the app creates one on tvOS today without a way to start it. The Apple TV shell already keeps the channel playing behind the guide, the overlay, Search and every tab (design-system "Live video keeps playing under overlays"), so in-app Picture in Picture adds nothing there. Its other use, a channel in the corner while another app runs, needs the user to start it from the player, and the Apple TV player has no button row to put it in; holding select already opens the info panel. Multi-view covers watching two channels. Revisit if users ask to keep a channel up while in another app.

### The Search bell on Apple TV

`SearchFeed`'s row drops `#if !os(tvOS)`. On tvOS `SearchRow.Bell` is its own focusable button after the row, so a swipe right from a later programme lands on it, as in the Apple TV guide. The bell's identifier stays `search.row.<n>.bell`.

### Guide sources filter on Apple TV

The list gets `.searchable(text: $model.filter)` on tvOS, which puts the system search field at the top of the list and opens the full-screen keyboard. The inline `TextField` stays on the other platforms.

### Clipboard on Mac

`Clipboard.system` on macOS asks `NSPasteboard.general.detect(patternsFor: [.probableWebURL])`, which does not read the contents and so does not trigger macOS's paste prompt, and reads `string(forType: .URL)` or `.string` only on Fill in. The banner is the same component in the same sheet.

### Filter on iPhone

`GuideCompactScreen` adds `.searchable(text:placement: .navigationBarDrawer(displayMode: .automatic))` bound to the same `GuideBoardModel.filter` the regular guide uses, and reads the rows with `filtered: true`. The field hides until the user pulls the list down.

### Trailer on Apple TV

`TrailerLink.playsInApp(_:)` in AntennaCore answers true for an http or https link whose path ends in `m3u8`, `mp4`, `m4v` or `mov`, and whose host is not YouTube. The tvOS title page shows Trailer only then. Pressing it plays through `ShelfPlayback.playTrailer(_:of:)`, with a `.trailer(URL, of: ShelfTitle)` target: same engine and player view, no saved position, and the title page underneath when it ends or Menu closes it.

Options considered:
- AVKit's `VideoPlayer`. It bypasses `PlaybackEngine`, which the conventions forbid in the apps.
- A separate trailer model. It would copy `ShelfPlayback`'s start and close.
- A target on `ShelfPlayback` (chosen).

## Risks / Trade-offs

- Four tiles on an older iPad may run hot. Mitigation: the same per-tile failure messages; the cap can drop to three on iPad later with no spec change to the grid.
- Search and the Guide sources screen are also being edited by other open work. Each slice here touches small sections and rebases before pushing.

## Migration Plan

No data changes. Each slice ships on its own.

## Open Questions

None.
