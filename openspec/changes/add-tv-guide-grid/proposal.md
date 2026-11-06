# Proposal

## Why

TV viewers plan the evening with a guide grid that shows what is on across channels at a glance and what comes later. Antenna's Guide tab on Apple TV is an empty placeholder. The guide data is already downloaded and stored by `guide-data`, and nothing shows it.

User stories served:
- "As a viewer, I want a guide grid of what is on across channels over the coming days, so I can plan what to watch."
- "As a user, I want one search across channels, guide programmes, movies and series, so I do not have to know where something lives."

## What Changes

- The Guide tab shows the playing channel in a small picture and a panel describing the highlighted programme.
- A grid of the current group's channels, with half-hour columns and a line at the current time.
- Programmes drawn to scale, past ones dimmed, gaps in the guide shown as empty blocks.
- Moving around the grid, to the day picker, and to the panel.
- Tuning from the grid.
- A day picker across the days the guide covers.
- Opening at a programme the user found in Search.
- A clock.

Out of scope:
- Reminders. Remind me stays hidden.
- Recording, catch-up and Start over, hidden as in the channel overlay.
- A guide on iPhone, iPad and Mac.
- Switching groups inside the guide. The user changes group in the channel overlay.
- Downloading, storing and refreshing the guide.
- Searching programmes.

## Capabilities

### New Capabilities
- `tv-guide-grid`: the Apple TV guide grid with a small live picture, a programme panel, a day picker and tuning.

### Modified Capabilities
None.

## Impact

- tvOS Guide tab content; window, layout and day-list maths in the core package.
- Depends on: `source-management`, `channel-catalogue`, `guide-data`, `tvos-shell`, change `add-tv-channel-overlay` (current group), change `add-tv-zap-bar-and-number-entry` (info bar and formatting), change `add-search` (opening at a found programme), change `add-playback-engine` (playing state, resume and picture height).
