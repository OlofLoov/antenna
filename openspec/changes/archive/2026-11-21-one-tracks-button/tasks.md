## 1. One button and its menu

- [x] 1.1 `TrackPicker.MenuButton`: `captions.bubble`, filled while full subtitles are on, "Audio and Subtitles", a system menu with Audio, Subtitles and the stream lines; the sheet, popover and subtitles button go
- [x] 1.2 Live (small player, timeshift, full screen) and the movie and episode player use it; the menu holds the controls up on iOS
- [x] 1.3 Strings: "Audio and Subtitles" replaces "Audio and subtitles", "Audio & Subtitles" goes
- [x] 1.4 Boards: the player and track boards on iPhone, iPad and Mac draw one button and the system menu

## 2. Tests

- [x] 2.1 iPhone and iPad UI tests: one tracks button, the menu shows both sections, picking a subtitle turns it on and fills the bubble, picking audio switches the sound in the engine
- [x] 2.2 The tests that opened the old list (`SubtitlePreferenceUITests`, `PlayerExtrasUITests`, `ShelfPlayerUITests`, `SubtitleSwitchUITests`) open the menu
- [x] 2.3 Apple TV: the info panel's Audio and Subtitles tabs and the switch work for Live and a movie on the simulator

## 3. Verify

- [x] 3.1 Each requirement this change adds or modifies has a test citing `player-controls-and-playback-errors/<requirement-slug>`
- [x] 3.2 The touched UI test classes pass on the iPhone and iPad simulators
- [x] 3.3 /opsx:verify passes
