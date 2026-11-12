# Design

## Context

See proposal.md for why. The engines already list sound and subtitle tracks, pick the starting ones through `TrackChoice.initial(audio:subtitles:options:)` and remember a pick per channel under `player.languages`. Two gaps make subtitles invisible in practice:

- `ChannelLanguages.options(for:)` passes `preferredAudioLanguages: Locale.preferredLanguages` and never `preferredSubtitleLanguages`, so every stream starts with subtitles off. Movies and episodes (`ShelfPlayback`) pass no languages at all.
- Both engines publish `subtitleCues()`, and `RoutedEngine` forwards them, but no view draws them. A subtitle picked in the list today is selected and never seen. This change adds the drawing, since the rest of it is pointless without it.

Boards, under `openspec/specs/design-system/boards/`:
- Changed: `iPad-Player.dc.html` (the subtitles button after `player.tracks`, the tracks icon as a speech bubble with lines), `iPhone-Settings.dc.html` and `TV-Settings-Preferences.dc.html` (the Subtitles row).
- New: `iPhone-FullScreen-Subtitles.dc.html` (full-screen controls with tracks, the subtitles button on, AirPlay, and a subtitle line on the picture), `TV-Player-Subtitles.dc.html` (the panel on the Subtitles tab with the "Subtitles On" switch after the tabs, and a subtitle line under the panel).
- Not drawn: the Mac strip (the iPad board's order with mute and volume, as today), the grayed subtitles button (the grayed tracks button's 0.4 opacity), the Apple TV Subtitles choice list (the standard tvOS pushed picker list), and a DVB picture subtitle (it is the broadcaster's own picture, placed where the stream says).

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Text meets contrast minimums", "Nothing fake and nothing bundled".

## Goals / Non-Goals

**Goals:**
- Apple's "Auto" rule for the starting subtitle, decided in AntennaCore and tested there.
- One Subtitles preference, Off, Auto or Always.
- A one-press subtitles switch on every platform.
- Subtitles drawn over the picture on every platform, text and, later, DVB pictures.

**Non-Goals:**
- Subtitle search, files, timing offset, styling, teletext, CEA-608/708 captions.
- Subtitles in multi-view tiles; a tile has no controls and no list.
- A subtitles control in the movie and episode player on iPhone, iPad and Mac, which has no audio-and-subtitles button yet. Movies start by the rule; picking waits for that player's controls.

## Decisions

### The rule lives in TrackChoice

`PlaybackOptions` gains `subtitleMode: SubtitleMode` (`.off`, `.auto`, `.always`, default `.auto`). `preferredSubtitleLanguages` is the device's languages. `TrackChoice.subtitle` becomes:

1. A remembered pick wins: a language the stream still has starts that track; a remembered "off" starts no full subtitles.
2. Otherwise by mode. `.off`: none. `.always`: the first preferred language with a full (non-forced) track. `.auto`: none when the chosen sound's language is one of the preferred languages or has no language tag; else as `.always`.
3. With no full track chosen, a forced track in the first preferred language that has one.

The chosen sound is decided first, so Auto looks at the sound that will actually play. Sound with no language tag counts as understood: an untagged stream is usually local, and showing subtitles nobody asked for is worse than one press to turn them on.

Options considered: deciding in each engine (two copies of the rule), or in the app before load (the app does not know the tracks before the engine opens the stream). AntennaCore keeps one copy, testable with `swift test`.

### Forced tracks

`MediaTrack` gains `isForced` (default false). AVPlayer: options with `.containsOnlyForcedSubtitles` are now listed with `isForced = true` instead of filtered out. FFmpeg: `AV_DISPOSITION_FORCED`. `TrackMenu.isForced` reads the flag, or "forced" in the provider's name as before. `TrackName.display` adds " (Forced)" after a language, so "English (Forced)" and "English" are told apart.

`LanguagePick(tracks)` stores a forced selection as subtitles off. Forced subtitles are not a choice the user makes; the rule brings them back on its own, and storing them as a language would turn the full track on next time.

### The setting syncs

`PreferencesRecord` gains `subtitlesRaw: String = "auto"`; `AppPreferences` gains `subtitles: SubtitleMode`.

Options considered:
- Synced in `PreferencesRecord` (chosen). Whether someone reads subtitles is about the person: hard of hearing, learning a language, watching with the sound low. They expect to set it once. It is one defaulted property, a lightweight CloudKit-safe migration like the earlier preference fields.
- Per device in `UserDefaults` (`player.subtitles`). Fits a living-room TV used by many people, but the per-channel pick already covers "this channel on this TV", and the Auto rule already follows each device's own languages.
- Per profile. Profiles key only per-device state today; a per-profile synced field would be a new kind of record.

The preference is read by the screens that already query `PreferencesRecord` (`ShellView`, `LiveViews`, `RootView`) and handed to `ChannelLanguages.subtitles` and `ShelfPlayback.subtitles` with `.onChange(initial: true)`. A change applies from the next stream start; the playing stream keeps its tracks, so flipping the setting never interrupts what is on screen.

### The switch

`TrackChoice.switched(_ tracks: TrackList, preferred: [String]) -> MediaTrack.ID?`: with a full track on, nil; otherwise the first preferred language's full track, else the first full track. `TrackChoice.fullSubtitlesOn(_:)` says whether the switch reads as on.

- iPhone, iPad, Mac: `TrackPicker.SubtitlesButton`, identifier `player.subtitles`, label "Subtitles", value "On" or "Off", SF Symbol `captions.bubble` and `captions.bubble.fill` when on, 44 pt hit area, grayed at 0.4 with no subtitles. It shows where AirPlay may show: regular width, Mac and full screen. The compact strip above the channel list has no room: five 44 pt buttons plus clock and LIVE leave the progress bar under 20 pt on a 390 pt iPhone. The tracks button's symbol becomes `text.bubble`, the speech bubble with lines the boards draw, so the two buttons differ.
- Apple TV: `InfoPanel.SubtitlesSwitch`, identifier `player.panel.subtitles`, a capsule after the tabs reading "Subtitles On" or "Subtitles Off" in the segment style, not shown when the stream has no subtitles. Focus moves to it with right from the last tab. Select flips it and the panel stays open.

The switch calls the same `selectSubtitle` as the list, so `ChannelLanguages` keeps it as the channel's pick.

### Drawing subtitles

`SubtitleCue` gains an optional `image: SubtitleImage` (RGBA bytes, width, height, and a rect normalized to the picture) next to `text`. `SubtitleOverlay` in `Apps/Shared/Components/Player/` takes cues and the picture's aspect ratio, fits the picture's rect into its bounds like `resizeAspect`, draws text cues centered near the bottom of that rect (white, semibold, on a 0.6 black backdrop, 4 percent of the picture height with the platform caption floor as minimum) and image cues at their normalized rect. `PlayerSubtitles` in `Apps/Shared/Player/` follows an engine's `subtitleCues()` and `presentation()` and feeds the overlay; it goes over the surface in `LivePicture`, the tvOS shell and `ShelfPlayerView`. Identifier `player.subtitles.cue`.

### DVB picture subtitles (last slice)

- `scripts/build-ffmpeg.sh` adds `--enable-decoder=dvbsub` and nothing else. `dvbsubdec.c` is LGPL 2.1 or later and needs no external library, so the build stays LGPL, demux-only plus MPEG-2, MP2 and this one decoder. The configure check for the LGPL line stays.
- A new release tag `ffmpeg-7.1.3-2` publishes the xcframework through `.github/workflows/ffmpeg.yml`; `Packages/FFmpeg/Package.swift` moves to its url and checksum.
- AntennaDemux lists `dvb_subtitle` streams as subtitle tracks (teletext, `dvb_teletext`, stays out), opens one `dvbsub` decoder per listed stream, decodes with `avcodec_decode_subtitle2`, turns each `AVSubtitleRect` of type `SUBTITLE_BITMAP` (8-bit indices plus a palette) into RGBA, and normalizes its rect by the decoder's display size (720x576 when the stream sends no display definition). Start is the packet time plus `start_display_time`; end is plus `end_display_time`, or the next page when the stream leaves it open. An empty page clears. Cues reach the screen on the engine's clock like text cues.
- This is not a software video renderer: video still decodes on VideoToolbox and draws through `AVSampleBufferVideoRenderer`. The overlay draws small subtitle pictures.
- The test fixture is a short TS with a DVB subtitle stream, made with ffmpeg from a generated picture and a text subtitle, and checked into the AntennaCore test support fixtures with the command that made it.

### Testing

- Core: `TrackChoiceTests` for every scenario of the rule, forced tracks and the switch; `AppPreferencesTests` for the default and the value.
- App unit: `ChannelLanguagesTests` checks that options carry the device's languages and the mode.
- UI: the scripted engines apply `TrackChoice.initial` to their track list on load and emit a cue while a subtitle is on. `UITESTING_TRACKS=foreign` gives German sound with German and English subtitles and forced English; tests launch with `-AppleLanguages (en)` so the device's languages are fixed. `UITESTING_SUBTITLES=off|auto|always` seeds the preference.
- DVB: `swift test --package-path Packages/AntennaDemux` against the fixture.

## Risks / Trade-offs

- [Auto shows subtitles on channels with wrongly tagged sound] → One press on the switch turns them off and the channel remembers it.
- [The FFmpeg release needs the workflow on a tag push] → If the tag cannot be pushed from here, the build script and code land, and the task to publish and bump the checksum stays open.
- [AVPlayer's forced options were hidden on purpose] → They are listed with a clear name now; nothing else selects them.

## Migration Plan

`subtitlesRaw` is a new defaulted property on `PreferencesRecord`; SwiftData migrates it lightly and CloudKit adds the field. Older app versions ignore it.

## Open Questions

None.

## Implementation decisions

- `TrackChoice.switched` and `fullSubtitlesOn` landed with the starting rule in slice 2, since they share its helpers; the buttons that call them come in slice 4.
- AntennaDemux tests do not load on this Mac (macOS 15.6, the package targets macOS 26), so `DemuxForcedTests` runs in PR CI only.
- `ChannelLanguages` and `ShelfPlayback` take the device's languages as an injected closure, `Locale.preferredLanguages` by default, so tests do not depend on the simulator's language.
- The screens hand the preference over with one modifier, `followsSubtitlePreference`, which queries `PreferencesRecord` itself. `ShellView` is near the 500-line limit, so it gains one line.
- The Subtitles row's explanation is the Preferences section's footer, so it sits right under the row. On Apple TV the row is a pushed list (`.navigationLink` picker style) as the board draws it; on iPhone, iPad and Mac it is the menu picker the other rows use.
- `SubtitleOverlay` puts the lines 12 percent of the picture's height above its bottom edge, and `raised` lifts them over the 52 pt control strip on iPhone, iPad and Mac while the controls show. On Apple TV the panel covers the top, so the lines stay put.
- The switch asks for the device's languages at the press (`switchSubtitles(languages:)`, `Locale.preferredLanguages` by default) rather than keeping them in the player model.
- `InfoPanel.Frame` gained an `accessory` slot after the segments; a constrained initializer keeps the two-closure form for the previews and any caller without one.
- The scripted UI-test engines now start with an empty track list and apply `TrackChoice.initial` on load, and their language picks live in their own emptied defaults suite. Before, the first track list differed from the chosen one and was kept as a pick, and picks leaked from one test to the next through `UserDefaults.standard`.
- The FFmpeg build adds `--enable-decoder=dvbsub` and nothing else. `libavcodec/dvbsubdec.c` in FFmpeg 7.1.3 is LGPL 2.1 or later with no external library, and configure still reports "License: LGPL version 2.1 or later". Change `add-playback-engine`'s design lists the decoders as MPEG-2 and MP2 only; this change records the third and leaves that design as written.
- Built locally with Xcode 26.6 for macOS, iOS, the iOS simulator, tvOS and the tvOS simulator, then packed into `FFmpeg.xcframework` by the script. The smoke check now also expects the DVB subtitle decoder and no teletext decoder; `FFmpegBuildTests` checks the same once the package points at the new release.
