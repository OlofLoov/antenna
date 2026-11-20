# Proposal

## Why

Every prominent button on iPhone, iPad and Mac draws a white label on the profile's accent: Connect, Add a source, Start watching, Play, Watch on the reminder banner and the picked chip. White on Blue is 2.15:1, and the other four accents are worse (Amber 1.76:1). `add-accent-and-app-icons` recorded the gap and left it for this fix. The boards already draw these labels dark; the code did not follow them.

The Apple TV guide sat 64 pt from the left and right edges while the channel overlay and every other page keep Apple's 80 pt safe area. The owner picked 80 pt sides and 60 pt top and bottom, Apple's tvOS safe area, for the guide too.

Afterwards a viewer reads every prominent button on any accent, and the guide lines up with the overlay and the tab pages on Apple TV.

## What Changes

- Prominent buttons and picked chips on iPhone, iPad and Mac draw their label in the dark ground color, 7.30:1 or more on all five accents.
- The Apple TV Save button under a source's fields takes the primary action style, like Connect on the add-source page. It drew white on the white glass prominent fill.
- The Apple TV guide keeps 80 pt at each side. The half-hour column narrows from 370 to 365 pt so the 300 pt channel column and four columns fit between the edges.
- The design-system capability gains "Text on the accent is dark", and the safe-area requirement names the guide.
- `TV-Guide`, `TV-Guide-Future`, `TV-Guide-Placeholders`, `TV-Guide-Empty` and `TV-Guide-RTL` move to the 80 pt edges and 365 pt columns.

Out of scope:
- Focused buttons on Apple TV, which keep the system's light platter with dark text.
- System alerts and menus, whose buttons the system draws.
- Other Apple TV screens with 64 pt edges: Search, the guide sources page and the hero copy. They are listed in design.md for a later change.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `design-system`: text on an accent fill is dark; the guide keeps the Apple TV safe area.

## Impact

- Platforms: iPhone, iPad and Mac for the labels; Apple TV for the guide and the Save button.
- Code: `ProfileAccent.label` in AntennaCore, `GuideScale.television`, `Palette.onAccent`, `prominentStyle(_:)` next to `primaryActionStyle()`, `chipStyle`, the reminder banner, the Up Next card, the source details page, `GuideGrid.Screen`, the shell's guide picture, and `scripts/check-rules.sh`.
- Boards: the five `TV-Guide` boards. Boards with prominent buttons already draw a dark label and stay as they are.
- Depends on `add-accent-and-app-icons` (archived), which added the five accents.
