# Proposal

## Why

From the owner, after a week on a real Apple TV: "in many menus it would be useful if the actual controls would be shown as well ie for navigating menus a remote control (the actual apple one) would be illustrating how to do stuff (feature should be toggleable)".

> As a living-room viewer, I want to see which remote button does what on the screen I am on, so I find holding select for Favorites, swiping left for the last channel and play/pause for the info bar without being told.

Several Apple TV actions have no button on screen: hold select on a channel adds it to Favorites, swipe left on the picture goes back to the last channel, swipe right opens Recents, hold select on the picture opens audio and subtitles, play/pause pauses live TV. Today the only hint is "Press to browse channels" on the info bar.

After this change a small legend in a corner of the screen shows the Siri Remote and the three to five actions that work there, for a few seconds after the viewer reaches a screen. "Show remote hints" in Settings turns it off on that Apple TV.

## What Changes

- A remote hints legend on Apple TV: the remote's symbol, then one line per control (glyph, name, action), on Live full screen, the info bar, the channel overlay's groups and channels, the guide, the tab bar, the Movies and Series rows, a title page, the movie and episode player (skip, scrub, play/pause, audio and subtitles, and what changes while scrubbing), and Settings.
- The legend shows when the highlight reaches a new screen, fades after six seconds, and shows at most three times per screen until the app launches again.
- It sits top right over full-screen video and the info bar and bottom right elsewhere, inside the TV safe area, never takes focus, and VoiceOver reads it as one sentence.
- "Show remote hints" in Settings, on until switched off, kept per device and never synced.

Out of scope:
- iPhone and iPad without a keyboard, which have no remote.
- A keyboard shortcuts legend on Mac and on iPad with a keyboard. design.md says why and what would do it instead.
- Hints on Search, multi-view, the live info panel, the onboarding and paywall screens, and the timeshift scrubber.
- Any artwork of the remote other than SF Symbols.

## Capabilities

### New Capabilities
- `control-hints`: the remote hints legend on Apple TV, what each screen lists, when it shows and fades, where it sits, and the switch in Settings.

### Modified Capabilities

None. The Settings row is part of `control-hints`.

## Impact

- Platforms: tvOS only.
- AntennaCore: the hint lists per screen, the schedule and the stored setting.
- Apps: one legend component, one host on the shell window and one on Settings, and one modifier on each screen that has hints.
- Boards: new `TV-Hints-Live`, `TV-Hints-Overlay`, `TV-Hints-Movies` and `TV-Settings-Hints`.
- Depends on `refresh-visual-design` for the text styles, the spacing and radius scale and the safe area. Its Settings slice (PR #358) reshapes the Settings list; the row is one line in a section of its own so the two merge either way.
