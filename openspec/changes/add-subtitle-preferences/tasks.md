## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-subtitle-preferences --strict`
- [x] 1.2 Update `iPad-Player`, `iPhone-Settings` and `TV-Settings-Preferences`, and add `iPhone-FullScreen-Subtitles` and `TV-Player-Subtitles`

## 2. The starting rule

- [x] 2.1 Add `SubtitleMode` and `PlaybackOptions.subtitleMode`, and the Auto, Always and Off rule with forced tracks in `TrackChoice`, with core tests citing `playback-engine/subtitles-start-by-the-subtitle-setting` and `playback-engine/forced-subtitles-in-your-language-show`
- [x] 2.2 Add `MediaTrack.isForced`, report forced tracks from AVPlayer and FFmpeg, name them "English (Forced)", and store a forced selection as off, with tests citing `playback-engine/forced-subtitles-in-your-language-show`
- [x] 2.3 Pass the device's languages and the mode from `ChannelLanguages` and `ShelfPlayback`, with app tests citing `playback-engine/subtitles-start-by-the-subtitle-setting`

## 3. The Subtitles preference

- [x] 3.1 Add `AppPreferences.subtitles` and `PreferencesRecord.subtitlesRaw` defaulted to Auto, with core and app tests citing `sources-and-settings/choose-when-subtitles-show`
- [x] 3.2 Add the Subtitles row with its explanation line to Preferences on every platform, and hand the value to the live, shell and movie players
- [x] 3.3 UI tests on iPhone and Apple TV: the row reads Auto, picking Always starts subtitles on the next channel, citing `sources-and-settings/choose-when-subtitles-show` and `playback-engine/subtitles-start-by-the-subtitle-setting`

## 4. Subtitles on screen and the switch

- [x] 4.1 Add `SubtitleOverlay` and `PlayerSubtitles` and draw text cues over the picture in Live, the tvOS shell and the movie player, with previews
- [x] 4.2 Add `TrackChoice.switched` and the subtitles button next to the tracks button on iPhone, iPad and Mac where AirPlay can show, with core tests citing `player-controls-and-playback-errors/turn-subtitles-on-or-off-in-one-step`
- [x] 4.3 Add the Subtitles On/Off switch to the Apple TV info panel
- [x] 4.4 Make the scripted engines apply the starting rule and emit a cue, add `UITESTING_TRACKS=foreign` and `UITESTING_SUBTITLES`, and add UI tests on iPhone, iPad and Apple TV for Auto, forced subtitles and the switch

## 5. DVB picture subtitles

- [x] 5.1 Add the `dvbsub` decoder to `scripts/build-ffmpeg.sh`, build it locally for every platform, and record the build in design.md
- [x] 5.2 Publish the build as `ffmpeg-7.1.3-2` and move `Packages/FFmpeg/Package.swift` to its url and checksum, with `FFmpegBuildTests` expecting the DVB subtitle decoder. Published; the package points at it and `FFmpegBuildTests` expects the DVB subtitle decoder.
- [x] 5.3 Make a TS fixture with a DVB subtitle stream and record the command that made it
- [x] 5.4 List DVB subtitle streams as tracks, decode their pages into picture cues with place and time, and test against the fixture citing `playback-engine/picture-subtitles-in-broadcast-streams`
- [x] 5.5 Draw picture cues in `SubtitleOverlay`, scaled to the picture, with a preview

## 6. Verify

- [x] 6.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [x] 6.2 `/opsx:verify` passes
