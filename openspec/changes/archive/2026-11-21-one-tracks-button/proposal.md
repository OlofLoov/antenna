# One button for audio and subtitles

## Why

The owner, on iPhone: "the icon for changing sound as well as subtitles is not obvious. We have two icons for essentially the same thing?"

The player controls on iPhone, iPad and Mac showed two speech bubbles side by side: one opened the audio and subtitles list, the other turned subtitles on or off. They look alike and nothing on screen says which does what.

> As an on-the-go viewer, I want one button for sound and subtitles, so I don't have to guess which bubble to press.

Apple's TV app and the system player on iOS 26 show one captions button that opens a menu with the audio and subtitle choices. After this change Antenna does the same on Live, timeshift, movies and episodes, in the small player and in full screen.

## What Changes

- One button, `captions.bubble`, filled while subtitles are on, labelled "Audio and Subtitles" for VoiceOver.
- It opens a system menu instead of the custom sheet and popover: an Audio section, a Subtitles section with Off first (or "No subtitles in this stream"), and a last section with the stream line and, for streams Antenna reads itself, "AirPlay not available for this stream", shown as rows that do nothing when tapped.
- Picking a row switches the track and closes the menu, as in the system player.
- The separate subtitles switch goes away on iPhone, iPad and Mac. Turning subtitles on or off takes two taps.
- The button is grayed out only when the stream has one sound and no subtitles.
- Apple TV keeps its info panel with Audio and Subtitles tabs and its Subtitles switch.

Out of scope:
- The Apple TV panel's layout and the Subtitles setting.
- The Mac menu bar's Playback menu.

## Capabilities

### Modified Capabilities

- `player-controls-and-playback-errors`: adds `One button for audio and subtitles`. `Choose audio and subtitles` says the menu closes on a pick on iPhone, iPad and Mac while the Apple TV panel stays open. `Turn subtitles on or off in one step` keeps only the Apple TV switch. `Choose audio and subtitles in a movie or episode` uses the menu and drops the switch on iPhone, iPad and Mac. `Extra buttons on iPhone, iPad and Mac` puts the AirPlay line in the menu.

## Impact

- `Apps/Shared/Components/Player/TrackPicker.swift`, `Apps/Shared/Views/Live/LivePicture.swift`, `Apps/Shared/Views/Shelf/TitleTrackControls.swift`, the strings catalog.
- UI tests: `PlayerTracksUITests`, `SubtitleSwitchUITests`, `SubtitlePreferenceUITests`, `PlayerExtrasUITests`, `ShelfPlayerUITests`.
- Boards: `iPhone-Player-Tracks`, `iPad-Player-Tracks`, `iPhone-Title-Player-Tracks`, `iPad-Title-Player-Tracks`, `iPhone-Title-Player-Transport`, `iPad-Title-Player-Transport`, `iPhone-FullScreen-Subtitles`, `iPad-Player`, `iPhone-Player`, `iPad-Menus-Go`, `Mac-Menus-Playback`.
- Nothing blocks it.
