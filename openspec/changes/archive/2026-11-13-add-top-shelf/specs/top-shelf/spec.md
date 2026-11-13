# Spec Delta

## Purpose

Lets Apple TV viewers who start from the Home screen see their favorite channels with what is on now and the titles they are part way through, and tune or resume with one press, using only what they have in Antenna.

## ADDED Requirements

### Requirement: Favorites show what is on now
The system SHALL show a Favorites row on the Top Shelf listing the user's favorite channels in their order, each titled with the channel and the programme on now and a bar for how far into the programme it is.

#### Scenario: Highlight Antenna with favorites
- **GIVEN** the user has favorite channels and the guide knows what is on
- **WHEN** they highlight Antenna on the Home screen
- **THEN** a Favorites row lists the favorites in the user's order, each titled "<channel> · <programme on now>" with a bar showing how far into the programme it is

#### Scenario: Offline
- **GIVEN** the Apple TV is offline
- **WHEN** the shelf is shown
- **THEN** it still shows, and programme titles stop advancing once the 12 hours of guide in the summary run out, until Antenna runs again

#### Scenario: Many favorites
- **GIVEN** a user with more than 20 favorites
- **WHEN** the shelf is shown
- **THEN** it carries at most 20 favorites

#### Scenario: A login not yet synced
- **GIVEN** favorites from a source whose login has not reached this Apple TV
- **WHEN** the shelf is shown
- **THEN** those favorites are left off until the login arrives

### Requirement: A channel with no guide left shows its name
The system SHALL title a favorite tile with the channel name alone, without a progress bar, when its guide data ends before now.

#### Scenario: Guide ran out
- **GIVEN** a favorite whose guide data ends before now
- **WHEN** the shelf is shown
- **THEN** its tile is titled with the channel name alone and has no progress bar

### Requirement: Continue watching shows titles in progress
The system SHALL show a Continue watching row listing movies and episodes in progress, most recent first, each with a bar for how far the user got.

#### Scenario: A movie and an episode in progress
- **GIVEN** the user is part way through a movie and an episode
- **WHEN** they highlight Antenna on the Home screen
- **THEN** a Continue watching row lists them most recent first, the episode titled with its season and episode ("S2 E4"), each with a bar showing how far the user got

#### Scenario: Many titles in progress
- **GIVEN** more than 10 titles in progress
- **WHEN** the shelf is shown
- **THEN** it carries the 10 most recent

### Requirement: A row with nothing in it is left out
The system SHALL show only the shelf rows that have content, with no "add favorites" tile when either row has content.

#### Scenario: One row empty
- **GIVEN** the user has favorites but nothing in progress, or the reverse
- **WHEN** the shelf is shown
- **THEN** only the row with content appears, and there is no "add favorites" tile

### Requirement: An empty shelf says how to fill it
The system SHALL show one "Add favorites in Antenna to see them here" tile when the user has no favorites and nothing in progress, and selecting it SHALL open Antenna normally.

#### Scenario: Nothing to show
- **GIVEN** the user has no favorites and nothing in progress
- **WHEN** the shelf is shown
- **THEN** one tile reads "Add favorites in Antenna to see them here" and selecting it opens Antenna normally

#### Scenario: Favorites still loading
- **GIVEN** favorites whose source is still loading
- **WHEN** the shelf is shown
- **THEN** the shelf stays blank rather than showing the add-favorites tile

#### Scenario: The unlock lapses
- **WHEN** the paid unlock lapses
- **THEN** Antenna clears the shelf summary and the shelf shows only the add-favorites tile, which opens the paywall

### Requirement: The shelf keeps up with the app
The system SHALL update the shelf after the user changes favorites, watches something, deletes a source or the guide refreshes, so the next Home screen shows the change.

#### Scenario: A change while Antenna runs
- **GIVEN** Antenna is running
- **WHEN** the user changes favorites, watches something, deletes a source, or the guide refreshes
- **THEN** the shelf shows the change the next time the Home screen shows it, including changes made just before Antenna went to the background

#### Scenario: First launch
- **GIVEN** Antenna's first launch
- **WHEN** the Home screen shows before every source has loaded once
- **THEN** the shelf is blank

#### Scenario: A failed write
- **WHEN** writing the shelf summary fails because storage is full or the shared area is unavailable
- **THEN** the previous shelf stays in place and the next change tries again

#### Scenario: A damaged or outdated summary
- **GIVEN** a damaged summary, or one from an older version after an app update
- **WHEN** the shelf is shown
- **THEN** it is blank until Antenna runs again

#### Scenario: Favorites added on another device
- **WHEN** the user adds favorites on another device
- **THEN** they reach the shelf only after Antenna runs on this Apple TV

### Requirement: No passwords or links leave the app
The system SHALL write a shelf summary and tile images that hold no link, channel identity, username or password, only names, programme titles, times, progress and the images.

#### Scenario: Sources with credentials in their links
- **GIVEN** sources whose stream, logo or poster links carry a username or password
- **WHEN** Antenna writes the shelf's summary for the extension
- **THEN** the summary and the tile images hold no link, channel identity, username or password, only names, programme titles, times, progress and the images themselves

### Requirement: Select a tile to watch
The system SHALL play the channel or resume the title of a selected shelf tile, whether Antenna was running on any screen or not running.

#### Scenario: Select a tile
- **GIVEN** a favorite channel tile or a Continue watching tile on the shelf
- **WHEN** the user selects it, with Antenna running on any screen or not running at all
- **THEN** Antenna plays that channel, or resumes that title where the user left off, instead of what it would otherwise show at launch

### Requirement: A tile that no longer matches opens Antenna as it was
The system SHALL open Antenna on its current screen, or launch normally, with nothing played and no error, when a selected tile no longer matches anything.

#### Scenario: A stale or damaged tile
- **GIVEN** a tile for a favorite the user has since removed, or the "add favorites" tile, or a damaged link
- **WHEN** the user selects it
- **THEN** Antenna opens on the screen it was on, or launches normally, with nothing played and no error shown

#### Scenario: A playlist reordered
- **GIVEN** a tile for an M3U channel with no guide id, and a playlist that has since been reordered
- **WHEN** the user selects the tile before Antenna writes a new summary
- **THEN** the tile no longer matches and Antenna opens as it was

### Requirement: The paywall and setup come first
The system SHALL show the paywall or setup, as on a normal launch, when a tile is selected while Antenna is locked or has no sources, and SHALL not play the tile's channel afterwards.

#### Scenario: Locked or not set up
- **GIVEN** Antenna is locked behind the paid unlock or has no sources yet
- **WHEN** the user selects a shelf tile
- **THEN** the paywall or setup is shown as on a normal launch, and after buying or adding a source Antenna launches normally, without playing the tile's channel

### Requirement: The shelf shows the current profile
The system SHALL show only the favorites and progress of the profile last current in Antenna on this Apple TV.

#### Scenario: Switch profile
- **GIVEN** the profiles Dad and Kids, each with their own favorites
- **WHEN** Kids is chosen in Antenna and the user goes back to the Home screen and highlights Antenna
- **THEN** the shelf shows only Kids's favorites and progress
