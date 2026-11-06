# favorites Specification

## Purpose
Keeps the user's short list of favorite channels in their own iCloud account and shows it in a Favorites tab on iPhone, iPad and Mac, so it survives source reloads. The list can be read but not yet changed in the app, and Apple TV does not show it. It serves the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

## Requirements

### Requirement: Empty state
The system SHALL show a "No favorites" view with the line "Favorites sync across your devices." in the Favorites tab when the user has no favorites.

#### Scenario: No favorites
- **GIVEN** no favorites
- **WHEN** the Favorites tab is shown
- **THEN** the "No favorites" view is shown and no list is shown

### Requirement: List order
The system SHALL list favorites by their saved sort order, each row showing only its channel id, not the channel's name or logo.

#### Scenario: Out-of-order favorites
- **GIVEN** favorites with sort order 2, 0, 1
- **WHEN** the Favorites tab is shown
- **THEN** three rows appear in the order 0, 1, 2, each showing its channel id

#### Scenario: Duplicates and equal sort orders
- **GIVEN** two favorites for the same channel, or two favorites with the same sort order
- **WHEN** the Favorites tab is shown
- **THEN** duplicates are listed twice and favorites with equal sort order appear in an unspecified relative order

#### Scenario: Source deleted
- **GIVEN** a favorite whose source was deleted
- **WHEN** the Favorites tab is shown
- **THEN** it stays in the list as a bare channel id, because deleting a source keeps its favorites

### Requirement: Favorites reference stable channel ids
The system SHALL produce the same channel id for a channel when its source reloads with unchanged content, for M3U entries with a non-empty `tvg-id` and for Xtream streams.

#### Scenario: Reload with unchanged content
- **GIVEN** a favorite for a channel from an M3U entry with a non-empty `tvg-id`, or from an Xtream stream
- **WHEN** the same source is reloaded with unchanged content
- **THEN** the same channel id is produced, so the favorite still refers to it

#### Scenario: Positional M3U ids
- **GIVEN** a favorite for an M3U entry without `tvg-id`
- **WHEN** the playlist order changes
- **THEN** the favorite no longer refers to that channel, because those ids are positional

### Requirement: Favorites sync between devices
The system SHALL sync favorites through the user's private iCloud account to every device signed into it. This is checked by hand on two devices.

#### Scenario: Second device
- **GIVEN** a favorite saved on device A
- **WHEN** device B, an iPhone, iPad or Mac signed into the same iCloud account, is online
- **THEN** the favorite appears in device B's Favorites tab

### Requirement: Favorites list is read-only
The system SHALL offer no way to add, remove, reorder or play a favorite. Rows in the Favorites tab do nothing when selected, and no channel list has a control that makes a channel a favorite.

#### Scenario: Selecting a row
- **GIVEN** a favorite in the Favorites tab
- **WHEN** the user taps it
- **THEN** nothing opens and nothing plays

#### Scenario: Channel list
- **GIVEN** a loaded channel list
- **WHEN** the user looks for a way to mark a channel as a favorite
- **THEN** there is none

### Requirement: Apple TV shows no favorites
The system SHALL show no Favorites screen on Apple TV. Favorites synced from other devices stay stored there and are not changed.

#### Scenario: Favorites from an iPhone
- **GIVEN** favorites saved on an iPhone signed into the same iCloud account
- **WHEN** the user opens Antenna on Apple TV
- **THEN** no tab or screen lists them, and they are still listed on the iPhone
