# Proposal

## Why

> As a living-room viewer with a big provider, when I move through the groups in the channel overlay on my Apple TV, I want the channel list to keep up and focus to land where I expect.

With tens of thousands of channels in hundreds of groups, the Apple TV overlay glitches when the user switches groups. Left from a channel can land on a group other than the one shown, then jump back, or switch the list to that other group. Right from a group can stop on a row of the old list first. Every logo in the list goes back to initials and loads again on each move, so the list flashes. Each focus move in the overlay also rebuilds the whole channel list, and adding a favorite on Apple TV indexes every channel again, so menus stall now and then.

## What Changes

- Left from the channel list always lands on the group it shows, and right from a group lands on the playing channel or the group's first channel, with no stop on another row, however far either column has scrolled.
- The group column opens scrolled to the group the overlay shows.
- Each group's list opens at its entry row instead of at the previous group's scroll offset.
- Channel logos download once, shrink to tile size off the main thread and stay in memory, so a logo seen once shows at once in every list, panel and guide row, on every platform.
- A focus move in the overlay redraws the panel and the group column, not the channel list.
- Adding or removing a favorite on Apple TV no longer indexes every channel again.
- The chips row on iPhone builds only the chips on screen.
- AntennaCore performance tests with a 50 000-channel catalogue and a seven-day guide keep the work per move under a budget.

Out of scope:
- Moving the catalogue build off the main actor. It runs when a source loads or group rules change, not on a menu move. Signposts now mark it so it can be measured on a device first.
- Restyling the overlay (`refresh-visual-design` task 6.1 does that).

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `tv-channel-overlay`: "Picking a group shows its channels" covers where focus lands moving between the columns, and a large catalogue.

## Impact

- Platforms: tvOS for focus and the overlay list; iOS, iPadOS and macOS for logos and the chips row.
- Depends on: `tv-channel-overlay`, `live-tv-on-iphone-ipad-mac/pick-a-group`, `design-system/channels-without-a-logo-show-initials`.
- A Debug-only launch argument adds 20 000 channels in 300 groups to the shell's UI test sources, so a UI test can switch groups in a large catalogue.
