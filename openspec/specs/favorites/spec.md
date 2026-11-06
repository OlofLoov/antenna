# favorites Specification

## Purpose
Keeps the user's short list of favorite channels in their own iCloud account and shows it in a Favorites tab on every device, so it survives source reloads. It serves the viewer who wants "my favorite channels together in one list, across all my subscriptions and devices".

## Requirements

### Requirement: Empty state
The system SHALL show a "No favorites" view in the Favorites tab when the user has no favorites.

#### Scenario: No favorites
- **GIVEN** no favorites
- **WHEN** the Favorites tab is shown
- **THEN** the "No favorites" view is shown

### Requirement: List order
The system SHALL list favorites by their saved sort order, each showing its channel id.

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
- **THEN** it stays in the list as a bare channel id

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
- **WHEN** device B, signed into the same iCloud account, is online
- **THEN** the favorite appears in device B's Favorites tab
