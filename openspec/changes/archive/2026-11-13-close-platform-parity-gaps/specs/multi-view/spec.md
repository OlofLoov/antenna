## ADDED Requirements

### Requirement: Start multi-view on an iPad
The system SHALL let an iPad user in the side-by-side layout add a second channel to the playing one from the channel list, turning the picture column into the Mac's tile grid without reloading the channel already playing, driven by touch, and SHALL leave multi-view when the window turns compact.

#### Scenario: Add from the channel list
- **GIVEN** a channel playing on an iPad showing the channel list beside the picture, and another channel in the list
- **WHEN** the user touches and holds that channel and chooses "Add to Multi-view", or highlights it with a keyboard and presses Command-Shift-M
- **THEN** the sidebar folds away, the playing channel becomes tile 1 without a reload and the chosen one tile 2, selected and audible

#### Scenario: Touch in the grid
- **GIVEN** multi-view on an iPad
- **WHEN** the user taps a tile, double-taps it, or taps the selected tile's close button
- **THEN** the tap selects it and moves the sound, the double-tap enlarges it or puts it back, and the close button removes it

#### Scenario: The window turns compact
- **GIVEN** multi-view on an iPad
- **WHEN** the window turns compact in Split View or Slide Over
- **THEN** multi-view ends and the selected tile keeps playing on its own without a reload

#### Scenario: Option absent
- **WHEN** nothing plays, the user holds the playing channel, the window is compact, or the app runs on iPhone
- **THEN** "Add to Multi-view" is absent

## MODIFIED Requirements

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
- **WHEN** nothing plays, the user right-clicks the playing channel, or the screen is too narrow
- **THEN** "Add to Multi-view" is absent
