## Why

Five Apple TV changes talk about "the tab bar" and "Menu goes back to full screen", and none says how those work. The app opened on a sidebar with Channels, Guide, Favorites and Settings, which matches none of the boards. This change builds the frame every Apple TV screen sits in: the app opens on the last channel full screen, Menu dims the picture and shows a tab bar, and Menu again goes back to the picture. It serves the living-room viewer who wants "to flip channels quickly with the remote, by up and down or by typing a number, so it feels like cable", and the viewer who wants "the app to come back to the channel I was watching, and to find recently watched channels quickly".

## What Changes

- A tab bar along the top: the Antenna mark, Live, Guide, Movies, Series, Search, a Settings button and a clock. Movies and Series appear only when a source offers them.
- Live is the current channel full screen. The bar is hidden on Live and Guide and always shown on Movies, Series and Search.
- Menu from full screen shows the bar over the dimmed picture; Menu from the top of a tab moves to the bar; Menu from the bar goes back to Live.
- At launch the last channel watched on this Apple TV plays, or the first channel; a loading screen and an empty screen cover the time before that is possible.
- The video carries on behind Movies, Series and Search for 30 seconds, then pauses.
- Other screens can send the user to Search, to a programme in the Guide, or back to Live.
- The Settings button opens Settings.

Out of scope:
- What happens inside the overlay, info bar, guide, movies and search.
- What Settings contains.
- The purchase screen; the shell assumes the user has paid.
- The Top Shelf.
- Leaving the app; the TV button does that, and Menu never leaves the app from inside the shell.
- The play/pause button, and where in the live stream the video resumes after a pause.

## Capabilities

### New Capabilities
- `tvos-shell`: the Apple TV tab bar, full-screen playback and Menu behavior.

### Modified Capabilities

## Impact

- App, tvOS only: `ShellView`, `ShellModel`, `ShellNavigator`, `LastChannelKey`.
- Depends on `add-first-run-onboarding`, `add-tv-channel-overlay`, `add-tv-zap-bar-and-number-entry`, `add-tv-guide-grid`, `add-live-tv-on-iphone-ipad-mac`, `add-movies-and-series-browsing`, `add-search`, `channel-catalogue` and `add-playback-engine`.
- `add-search` must add "the video is paused after 30 seconds, as in the tvOS shell" in its implementing change.
