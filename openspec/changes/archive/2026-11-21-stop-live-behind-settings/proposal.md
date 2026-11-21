# Proposal

## Why

> As a viewer, when I open Settings I don't want the channel I was watching to keep playing behind it.

Since Settings became a sheet over the open tab on iPhone and in a narrow iPad window, Live stays on screen under it and its sound runs on while the user edits sources. Before, Settings was a tab, and leaving Live paused the channel. On iPad and Mac the sidebar's Settings section left the channel playing, and on Apple TV the Settings tab played the channel on, even after passing Movies, Series and Search had paused it. The owner found it on an iPhone.

## What Changes

- Opening Settings holds the channel on every platform, as Movies, Series and Search do: it pauses at once and the stream stops after 30 seconds, which frees the provider's connection.
- Closing the Settings sheet treats the tab under it as opened again. Over Live or the Guide the channel plays on, or tunes again at live after 30 seconds. Over Movies, Series or Search it stays paused.
- On iPad, Mac and Apple TV, Settings is a section or tab, so going back to Live or the Guide ends the hold as it does from Movies.
- A channel in Picture in Picture or on AirPlay keeps playing behind Settings.
- Opening the sheet does not change the tab the next launch opens on.

Out of scope:
- A movie or episode playing full screen. Settings cannot open over it.
- Any change to how Movies, Series and Search hold the channel.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: "The channel pauses behind Movies, Series and Search" covers Settings, and "Settings from the profile button" says what the sheet does to the channel.
- `tvos-shell`: "Open Settings" holds the video instead of leaving it alone.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Builds on the hold behind Movies, Series and Search (`live-tv-on-iphone-ipad-mac/the-channel-pauses-behind-movies-series-and-search`, `tvos-shell/the-video-pauses-behind-movies-series-and-search`) and reuses it as it is.
- Reverses the Apple TV fix that made Settings end the hold (`fix(tv): resume live when the highlight reaches Settings`).
