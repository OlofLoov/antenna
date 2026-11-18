# Proposal

## Why

> As a living-room viewer flipping through the guide on Apple TV, I want the small picture to show the channel I am looking at, and I want the tab bar where Apple TV puts its own: centered along the top, the same on every tab.

The owner tested on a device on 2026-11-18 and found three things:

1. The tab bar is not centered. The pills and the Settings gear were centered as one group, so the pills sat 35 pt left of the screen's center, and 70 pt left with the profile button. The system tab bar centers the tabs.
2. Over the guide, the bar sits on top of the small picture. The picture starts 48 pt from the top and the bar's band is 104 pt, so the raised bar covers the top of the video, and the bar looks out of place compared with Movies, Series and Search, where content starts below it.
3. Moving through the guide leaves the small picture on the channel that was playing. The owner wants it to show the highlighted channel, so a viewer can see what is on before picking it.

## What Changes

- The tab pills sit on the screen's horizontal center on every tab. The profile and Settings buttons hang to the right of the pills without moving them. The bar's height, order and focus stay as they are.
- The guide's small picture and panel start below the bar's band (120 pt from the top), so the bar sits over the guide at the same height as on every other tab and never covers the picture. The grid shows six whole rows instead of seven.
- The small picture follows the highlighted row once the highlight rests on it for 0.7 s. It tunes the one player in place of the old stream, so there is never a second connection. Select and Watch keep that channel and play it full screen without loading it again. Leaving the guide any other way (Back, then a tab) tunes back to the channel that played before the guide opened.

Out of scope:
- The iPhone, iPad and Mac guides. They have no small picture and no resting highlight; a tap is the choice. Their tab bar and sidebar are the system's.
- Changing the guide's remote hints. "Back: Tab bar" and "Click: Watch, or details for later" still describe what the remote does.
- A setting to turn the preview off. Add one if viewers on providers with slow channel starts ask for it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `tvos-shell`: a new requirement, "The tab bar sits in the same place on every tab".
- `tv-guide-grid`: a new requirement, "The small picture follows the highlight"; "The channel keeps playing in a small picture" says the picture keeps the stream until the highlight moves to another row.

## Impact

- Apple TV only. Code in `Apps/Shared/Components/ShellTabBar`, `Apps/Shared/Components/GuideGrid`, `Apps/Shared/Views/Guide/GuideScreen.swift` and the shell model. Nothing in AntennaCore changes.
- Boards: every TV board that draws the bar, and the TV-Guide boards.
- Builds on `refresh-visual-design`, which keeps the custom bar's layout, and on the archived guide and shell changes.
- Runs next to agent work on the shell's playback lifecycle (pause behind Movies and Series). Both touch `ShellModel.open`; whichever lands second rebases.
