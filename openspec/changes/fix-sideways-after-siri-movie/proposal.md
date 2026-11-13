# Proposal

## Why

> As a viewer watching a channel on my iPhone held sideways, when I ask Siri to play a movie and then close it, I want my channel back full screen, the way it was.

Today the movie plays over Live without the tab changing. When it ends, Live shows its list sideways with the channel stopped, and the user has to switch tabs or turn the phone to get the picture back.

## What Changes

- When a movie or episode ends and Live is the open tab on iPhone, the channel the movie stopped plays again.
- Held sideways, the picture fills the screen again.

Out of scope:
- iPad and Mac, where the movie also plays over Live but there is no sideways full screen. The channel there still starts again when Live next opens.
- Apple TV, which has its own shell.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: "Sideways on iPhone fills the screen" covers a movie that ends while Live is open.

## Impact

- Platforms: iOS (iPhone).
- Depends on: `app-intents` (play a movie by voice or shortcut) and `movies-and-series-browsing/resume-where-you-left-off`.
- A Debug-only launch argument hands the app a Siri request when it returns to the foreground, so a UI test can start a movie over a playing channel.
