# Spec Delta

## ADDED Requirements

### Requirement: Play or resume from a shelf link
The system SHALL tune a channel or resume a title named by a Top Shelf link, and hold a link that arrives before the shell is ready until the item's source loads within the launch deadline, replacing the last-channel tune with one load in total.

#### Scenario: A link at launch
- **GIVEN** Antenna is not running and its last channel is 7
- **WHEN** the user selects the shelf tile for channel 104
- **THEN** channel 104 plays once its source loads, and channel 7 is never loaded

#### Scenario: A link while running
- **GIVEN** Antenna is running on any screen
- **WHEN** a shelf link for a channel arrives
- **THEN** the channel plays as it would after going to live TV

#### Scenario: A link that does not resolve
- **GIVEN** a shelf link whose channel's source does not load within the launch deadline, or whose channel no longer exists
- **WHEN** the link arrives
- **THEN** the link is dropped and Antenna launches or stays as it would without it
