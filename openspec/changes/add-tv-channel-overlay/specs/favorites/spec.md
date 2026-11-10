## MODIFIED Requirements

### Requirement: Favorites list is read-only
The system SHALL offer no way to add, remove, reorder or play a favorite on iPhone, iPad or Mac. Rows in the Favorites tab do nothing when selected, and no channel list there has a control that makes a channel a favorite. On Apple TV the channel overlay adds and removes favorites (tv-channel-overlay).

#### Scenario: Selecting a row
- **GIVEN** a favorite in the Favorites tab
- **WHEN** the user taps it
- **THEN** nothing opens and nothing plays

#### Scenario: Channel list
- **GIVEN** a loaded channel list on iPhone, iPad or Mac
- **WHEN** the user looks for a way to mark a channel as a favorite
- **THEN** there is none

## REMOVED Requirements

### Requirement: Apple TV shows no favorites
**Reason**: The channel overlay on Apple TV lists Favorites as its first group and has a favorite button, so favorites synced from other devices show and can change there.
**Migration**: The overlay's requirements "Every group, with its size" and "Add or remove a favorite" describe favorites on Apple TV.
