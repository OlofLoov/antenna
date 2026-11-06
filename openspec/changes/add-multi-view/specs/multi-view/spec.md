# Spec Delta

## Purpose

Lets sports and news viewers on Apple TV and Mac watch up to four live channels side by side, hearing the one they have highlighted, and change, enlarge, retry or remove each tile without disturbing the others.

## ADDED Requirements

### Requirement: Start multi-view on Apple TV
The system SHALL let a user on Apple TV add a second channel from the channel overlay, splitting the screen into two live tiles without reloading the channel already playing.

#### Scenario: Add a channel from the overlay
- **GIVEN** a channel playing full screen on Apple TV and the overlay open on a different channel
- **WHEN** the user chooses "Add to multi-view"
- **THEN** the screen splits into two tiles, the playing channel on the left continuing without a reload and the new channel on the right with focus and sound
- **AND** each tile shows its number and name, and a hint shows briefly
- **AND** this does not count as a channel change, so no zap bar appears
- **AND** while tiles play the TV's frame rate and HDR mode stay as they were and HLS tiles stay at 1080p (full HD) or below

#### Scenario: Option not offered
- **GIVEN** the overlay open on the playing channel itself, or on any channel while the playing channel is paused, loading or failed
- **WHEN** the user looks at the overlay's actions
- **THEN** "Add to multi-view" is not offered

#### Scenario: A tile in another frame rate
- **GIVEN** a 50 Hz or HDR tile on a TV set to 60 Hz SDR
- **WHEN** the tile plays in multi-view
- **THEN** it plays in the TV's current mode, and the mode changes only when that tile is the one kept on exit

### Requirement: Start multi-view on a Mac
The system SHALL let a Mac user add a second channel to the playing one from the channel list, turning the main window into a tile grid without reloading the channel already playing.

#### Scenario: Add from the channel list
- **GIVEN** a channel playing in the Mac window and another channel in the list
- **WHEN** the user right-clicks that channel and chooses "Add to Multi-view", or highlights it and presses Command-Shift-M
- **THEN** the sidebar folds away, the playing channel becomes tile 1 without a reload and the chosen one tile 2, selected and audible
- **AND** the toolbar shows the tile count, tiles fit the window as it resizes, and the window cannot shrink so far that the channel list disappears

#### Scenario: A narrow window widens
- **GIVEN** a Mac window narrower than multi-view needs
- **WHEN** the user starts multi-view
- **THEN** the window widens to fit

#### Scenario: Option absent
- **WHEN** nothing plays, the user right-clicks the playing channel, the screen is too narrow, or the app runs on iPhone or iPad
- **THEN** "Add to Multi-view" is absent

### Requirement: Sound follows the highlighted tile
The system SHALL play sound from exactly one tile, the highlighted one on Apple TV or the selected one on Mac, and move it when the highlight moves, never letting two tiles be heard at once.

#### Scenario: Move the highlight
- **GIVEN** multi-view with tile 1 highlighted (Apple TV) or selected (Mac)
- **WHEN** the user swipes to another tile, clicks it, or presses Command and its number
- **THEN** the old tile goes quiet before the new one is heard, never two at once
- **AND** each tile's spoken label says whether it has sound
- **AND** on Mac the matching channel is selected in the list, and the lock screen and Control Center show the audible tile's details

#### Scenario: Navigation never changes channel or pauses
- **GIVEN** multi-view on any device
- **WHEN** the user swipes, presses arrows, types a number, or presses play/pause, Space, the media key or the lock-screen control
- **THEN** no channel changes, multi-view stays open, number entry does nothing, and no tile pauses

#### Scenario: A failed tile is highlighted
- **GIVEN** a failed tile
- **WHEN** the user highlights it
- **THEN** every tile is silent, so the sound still matches the highlight

#### Scenario: A radio tile
- **GIVEN** a radio stream in a tile
- **WHEN** it plays
- **THEN** the tile shows the channel logo and its sound follows focus like any other tile

### Requirement: Change a tile's channel
The system SHALL let the user change the channel in one tile with a single reload of that tile, leaving every other tile untouched.

#### Scenario: Pick a new channel for a tile
- **GIVEN** multi-view with tile 2 highlighted or selected
- **WHEN** the user presses select and picks a channel from the overlay, which says "Changing tile 2 of 3" and marks channels already in a tile, or on Mac clicks a channel in the list
- **THEN** tile 2 switches to that channel with one reload, the others are untouched, and no zap bar appears

#### Scenario: Picking a channel already shown
- **GIVEN** the picker open for tile 2
- **WHEN** the user picks a channel already in another tile
- **THEN** the highlight moves to that tile instead
- **AND** picking tile 2's own channel does nothing

#### Scenario: Leave the picker
- **GIVEN** the picker open for a tile on Apple TV
- **WHEN** the user presses Menu
- **THEN** the overlay closes with nothing changed

#### Scenario: Pick from a full-screen tile
- **GIVEN** one tile shown full screen
- **WHEN** the user changes its channel
- **THEN** the tile returns to full screen afterwards

### Requirement: Add more tiles, up to the limit
The system SHALL let the user add tiles up to the device's limit, four or two on Apple TV HD and Intel Macs, and lower that limit for the session when the device cannot decode another stream.

#### Scenario: Add a tile
- **GIVEN** multi-view with fewer tiles than the device's limit
- **WHEN** the user chooses "Add as new tile" in the overlay, or "Add to Multi-view" on a Mac channel
- **THEN** the new channel joins as the next tile, takes focus and sound, and the layout rearranges without reloading the others

#### Scenario: The device runs out of decoders
- **GIVEN** multi-view below the device's limit
- **WHEN** the device cannot decode another stream
- **THEN** the limit drops to the tiles still playing until the user leaves multi-view

#### Scenario: The limit is reached
- **GIVEN** multi-view at its limit
- **WHEN** the user opens the overlay or a Mac channel's menu
- **THEN** the overlay offers no "Add as new tile" and the Mac menu shows a greyed "Multi-view is full"

#### Scenario: A channel already in a tile
- **WHEN** the user tries to add a channel that is already in a tile
- **THEN** it is not added a second time

### Requirement: Each tile has its own actions
The system SHALL give each tile on Apple TV an actions menu with Full screen, Change channel and Remove from multi-view, putting Try again first when the tile has failed.

#### Scenario: Open a tile's actions
- **GIVEN** a tile highlighted on Apple TV
- **WHEN** the user holds select, or uses VoiceOver's actions
- **THEN** a menu offers Full screen, Change channel and Remove from multi-view, with Try again first and focused when the tile has failed
- **AND** Change channel opens the channel picker for that tile

#### Scenario: Close the actions
- **GIVEN** a tile's actions menu open
- **WHEN** the user presses Menu
- **THEN** the menu closes with nothing changed

### Requirement: One tile full screen and back
The system SHALL let the user show one tile full screen and return to the grid, with no reload and the other tiles playing on out of sight.

#### Scenario: Enlarge a tile
- **GIVEN** multi-view with tile k highlighted or selected
- **WHEN** the user presses play/pause or chooses Full screen on Apple TV, or double-clicks the tile on Mac
- **THEN** tile k fills the screen (on Mac, the tile area) with no reload and the same sound, the others keep playing out of sight, and a badge says which tile of how many is shown

#### Scenario: Return to the grid
- **GIVEN** one tile shown full screen
- **WHEN** the user presses Menu or play/pause on Apple TV, double-clicks or presses Escape on Mac, chooses another tile, or adds one
- **THEN** the grid comes back

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** tiles rearrange or a tile enlarges
- **THEN** it happens without animation

### Requirement: Remove a tile
The system SHALL let the user remove a tile, close up the others without reloading them, and leave multi-view when only one channel would remain.

#### Scenario: Remove one of three or four
- **GIVEN** multi-view with three or four tiles
- **WHEN** the user removes a tile from its actions, its close button or right-click menu, or on Mac presses Command-Delete on the selected tile
- **THEN** that tile stops, the others close up without reloading, and the highlight and sound move to the neighbouring tile if the removed one had them

#### Scenario: Remove one of two
- **GIVEN** multi-view with two tiles
- **WHEN** the user removes one
- **THEN** multi-view ends and the other channel plays alone without a reload
- **AND** this counts as a channel change, so the zap bar shows and the channel is remembered as the last one

#### Scenario: A tile's channel leaves the source
- **GIVEN** a tile whose channel disappears or is renumbered after a source refresh, or whose source loses its login
- **WHEN** the refresh lands
- **THEN** that tile is removed as if the user had removed it
- **AND** if no tile's channel is left, multi-view ends with everything stopped

#### Scenario: Remove an unselected tile on Mac
- **GIVEN** multi-view on Mac with tile 1 selected
- **WHEN** the user removes tile 3
- **THEN** the sound stays on tile 1

### Requirement: Leave multi-view
The system SHALL end multi-view by keeping the highlighted or selected tile's channel playing on its own, without a reload, and stopping every other tile.

#### Scenario: Leave from the grid
- **GIVEN** multi-view with tile k highlighted or selected and nothing else open
- **WHEN** the user presses Menu on Apple TV, or "Exit multi-view" on Mac
- **THEN** every other tile stops and tile k's channel keeps playing full screen (Apple TV) or in the normal player with the sidebar back as it was (Mac), without a reload, at full quality and with the TV's mode matching again
- **AND** this counts as one channel change to tile k's channel, which is remembered as the last channel
- **AND** on Apple TV that Menu press does not also open the tab bar

#### Scenario: Close the app in multi-view
- **GIVEN** multi-view with several tiles
- **WHEN** the app is closed and opened again
- **THEN** nothing about the tiles is restored and the last single channel plays

#### Scenario: The purchase lapses
- **GIVEN** multi-view playing
- **WHEN** the purchase lapses
- **THEN** the paywall replaces everything and every tile stops

### Requirement: A tile that fails says why
The system SHALL show each tile's loading and failure state on that tile alone, in plain words that name a provider refusing another stream or a device that cannot decode another one.

#### Scenario: Loading and failure
- **GIVEN** multi-view with several tiles
- **WHEN** one tile is loading or reconnecting, or fails
- **THEN** a loading tile shows a spinner
- **AND** a failed tile shows a title and explanation, stays highlightable and silent, and does nothing more until the user tries again, changes its channel or removes it
- **AND** Try again reloads the tile once

#### Scenario: The provider refuses another stream
- **GIVEN** another tile from the same source is playing
- **WHEN** the provider refuses with busy or a 503, 509 or 403
- **THEN** the tile says "Your provider refused another stream. Many providers allow one or two streams per account at a time."
- **AND** for a 403 it adds a hint to check the login

#### Scenario: The device cannot decode another stream
- **WHEN** the device cannot decode another stream
- **THEN** the tile says "This Apple TV can't play another stream" (or "This Mac") with "Remove a tile or pick a lower-resolution channel."

#### Scenario: Other failures and offline
- **WHEN** a tile fails for any other reason, or is added while offline
- **THEN** it uses the player's usual failure wording, at once when offline
- **AND** a connection dropped mid-session is retried per tile, with no session-wide error

#### Scenario: A one-stream account
- **GIVEN** a one-stream account with one tile playing
- **WHEN** a new tile from the same account pushes the older one off
- **THEN** the older tile fails and stays failed rather than looping

#### Scenario: A slow tile
- **WHEN** a tile never starts
- **THEN** it times out on its own without affecting the others

### Requirement: Leaving the app
The system SHALL pause and resume every tile with the app on Apple TV, keeping the same tile audible, and keep tiles playing on Mac when the app goes to the background.

#### Scenario: Background and return
- **GIVEN** four tiles playing with tile 2 audible
- **WHEN** the app goes to the background and comes back
- **THEN** on Apple TV every tile pauses and resumes, with tile 2 still the only one heard
- **AND** on Mac nothing pauses

### Requirement: Four tiles hold up on real hardware
The system SHALL play four tiles for 30 minutes without buffering or failure on every Apple TV 4K generation and on an M1 Mac, moving the sound within half a second.

#### Scenario: Thirty minutes of four tiles
- **GIVEN** each Apple TV 4K generation on wired Ethernet, and separately an M1 Mac, playing four tiles (two MPEG-TS 1080p50 and two HLS 1080p)
- **WHEN** multi-view runs for 30 minutes with 20 changes of the audible tile
- **THEN** every tile keeps playing with no buffering or failure, the app is not shut down, and the new tile is heard within half a second of each change
