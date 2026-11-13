# Proposal

## Why

An audit of the four apps found features that exist on some platforms and not others with no reason the platform forces. A household that watches on an iPad in the kitchen, a Mac at the desk and an Apple TV in the living room meets a different app on each:

- The movie and series watcher: "I can pick the Spanish audio on a live channel but not on a film."
- The sports fan with an iPad: "My Mac shows four games at once. My iPad Pro has a bigger screen and can't."
- The on-the-go viewer at a Mac: "On my iPad the channel floats in a corner while I work. On my Mac it can't."
- The living-room viewer: "I found the match in Search on the TV but have to go to the guide to set a reminder."
- The household setter-upper fixing guides on the Apple TV: "Two hundred channels without a guide and no way to find the one I mean."
- The household setter-upper on a Mac: "I copied the link from the provider's email, and my iPhone offers to fill it in. My Mac doesn't."
- The on-the-go viewer on an iPhone: "The guide on my iPad lets me type a channel name. On my phone I scroll."
- The movie watcher on Apple TV: "Every other device shows the Trailer button."

Afterwards each of these works on every platform where the hardware and the system allow it, and the ones that cannot are written down with the reason.

## What Changes

- Movie and episode player: the audio-and-subtitles button and the subtitles switch on iPhone, iPad and Mac, and an Audio and Subtitles panel on Apple TV, the same lists Live has. Titles keep starting by the Subtitles setting.
- Multi-view on iPad in the regular layout, with the Mac's tile grid driven by touch: Add to Multi-view in a channel's long-press menu, tap to move the sound, double-tap to enlarge. It leaves multi-view, keeping the selected tile, when the window turns compact.
- Picture in Picture on Mac for both playback paths, from a button in the Live controls.
- The Remind me bell on guide results in Search on Apple TV.
- A filter in the Guide sources channel list on Apple TV.
- The clipboard Fill in banner in the add-source form on Mac.
- A pull-down filter in the iPhone guide.
- The Trailer button on Apple TV when the trailer link is a video file or an HLS stream, played in the app.

Out of scope:
- Widgets (declined for v1).
- Picture in Picture on Apple TV (see design.md).
- YouTube trailers on Apple TV: tvOS has no web browser to open them in, and the app does not embed YouTube.
- Multi-view on iPhone.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `player-controls-and-playback-errors`: adds track choice in the movie and episode player and Picture in Picture on a Mac.
- `multi-view`: adds starting multi-view on an iPad; the Mac requirement no longer says iPad lacks it.
- `programme-reminders`: Remind me on guide results in Search on Apple TV.
- `guide-sources-and-channel-mapping`: the channel filter on Apple TV.
- `first-run-onboarding`: Fill in from a copied link on Mac.
- `guide-on-iphone-ipad-and-mac`: the filter on iPhone.
- `title-detail-and-episode-picker`: Trailer on Apple TV for links that play in the app.

## Impact

- Apps: `ShelfPlayback` and `ShelfPlayerView` gain the tracks list; the multi-view grid screen builds on iPad; the engines create the Picture in Picture controller on macOS; `SearchFeed`, `GuideSourcesList`, `OnboardingModel`, the iPhone guide and the title page change.
- AntennaDemux: Picture in Picture for the sample-buffer layer builds on macOS.
- AntennaCore: a rule for which trailer links play in the app.
- Boards: new `iPhone-Title-Player-Tracks`, `iPad-Title-Player-Tracks`, `TV-Title-Player-Tracks`; changed `TV-Search`, `TV-GuideSources`, `TV-Title`, `iPhone-Guide`, `iPad-MultiView`, `iPad-Player`.
- Depends on the archived changes that built each feature (`add-multi-view`, `add-programme-reminders`, `add-player-controls-and-playback-errors`, `add-title-detail-and-episode-picker`, `add-first-run-onboarding`, `add-guide-on-iphone-ipad-and-mac`) and on `add-subtitle-preferences` for the subtitles switch. Nothing blocks it.
