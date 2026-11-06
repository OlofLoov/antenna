## Why

Source management has shipped, and its save, delete and loading rules have passing tests. The parts a user sees on screen do not: the add sheet staying open on a bad URL, the empty channel list, the Settings list order, sync to a second device, and the player opening on a tap. They wait for a UI test target and a manual two-device check. This change holds them until they are tested. It serves the household setter-upper who wants "sources I add on one device to appear on my other devices, so I never type a URL or password twice", and the user who wants "to edit, refresh or remove a source, and change how the app behaves, so my setup stays right as my subscription changes".

## What Changes

- The add-source sheet stays open with its error after an invalid URL.
- The channel list shows its empty state with no sources.
- Settings lists sources in sort order with name and URL.
- Sources reach a second device through iCloud.
- Selecting a channel pushes the player (stopgap).

Out of scope:
- Editing or reordering a source.
- A delete affordance on tvOS and macOS.
- Rendering load errors.

## Capabilities

### New Capabilities

### Modified Capabilities
- `source-management`: adds the on-screen and two-device requirements that have no test yet.

## Impact

- App: `AddSourceView`, the Settings source list, `ChannelsView`, `PlayerView`, and the UI test target.
- Depends on the UI test target that the favorites UI tests added.
- Superseded in part, once those changes are implemented: the empty state and the channel tap by `add-live-tv-on-iphone-ipad-mac` on iOS, iPadOS and macOS (where the Channels tab becomes Live); the Settings list by `add-sources-and-settings`.
