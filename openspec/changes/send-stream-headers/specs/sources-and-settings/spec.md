## ADDED Requirements

### Requirement: A User-Agent per source
The system SHALL let the user set a User-Agent in a source's details on iPhone, iPad, Mac and Apple TV, and SHALL send it on the source's playlist download, its provider calls and its streams. Empty SHALL mean the default. The setting SHALL sync with the source.

#### Scenario: Set a User-Agent
- **GIVEN** an M3U or Xtream source's details
- **WHEN** the user types "Box/1" in User-Agent and saves
- **THEN** it saves without a server check, the source reloads, and its requests carry "Box/1"

#### Scenario: Clear it
- **GIVEN** a source with a User-Agent
- **WHEN** the user empties the field and saves
- **THEN** the source's requests carry the default User-Agent again

#### Scenario: Another device
- **GIVEN** a User-Agent set on the iPhone
- **WHEN** the Apple TV syncs
- **THEN** the source there uses it too
