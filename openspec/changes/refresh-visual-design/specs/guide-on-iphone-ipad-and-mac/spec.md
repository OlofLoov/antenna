## MODIFIED Requirements

### Requirement: Channels with gaps or no guide
The system SHALL say in a channel's row when its guide is loading, missing or failed, and SHALL show a banner with Try again for a source whose guide failed.

#### Scenario: Missing and failed guides
- **GIVEN** channels whose guide is loading, missing or failed
- **WHEN** the user looks at the guide
- **THEN** their rows read "Loading guide…", "No programme information" or "Guide unavailable" in place of programmes
- **AND** a source whose guide failed gets a banner "Could not load the guide for <source>" with Try again and dismiss

#### Scenario: A login still to sync
- **GIVEN** a source whose login has not synced
- **WHEN** the Guide shows
- **THEN** a banner reads "<source>: waiting for its login to sync from iCloud" until the login arrives

#### Scenario: Offline or a failed refresh
- **WHEN** the device is offline or a guide refresh fails
- **THEN** the guide keeps the programmes it already has, and rows with nothing yet read "Guide unavailable"

#### Scenario: The guide loads while open
- **GIVEN** the Guide open
- **WHEN** a guide finishes loading or refreshes
- **THEN** its rows fill in place without moving the scroll position

### Requirement: Nothing to show yet
The system SHALL replace the grid or list with Live's loading rows or error message while sources load or have all failed, and with a "No channels" message for an empty group.

#### Scenario: Loading, failed or empty
- **GIVEN** sources still loading, every source failed, or a group with no channels
- **WHEN** the user opens the Guide
- **THEN** the grid or list is replaced by the same loading rows or error message with Try again as Live, or by "No channels in <group>" with the toolbar or chips still working
- **AND** while loading or failed, the toolbar and chips are hidden
