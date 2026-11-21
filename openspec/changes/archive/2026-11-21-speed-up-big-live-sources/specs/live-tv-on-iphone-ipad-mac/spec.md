## ADDED Requirements

### Requirement: A very large source stays responsive
The system SHALL keep the channel list still and the main thread free of work that grows with the channel count when nothing it shows has changed, on iPhone, iPad, Mac and Apple TV.

#### Scenario: A refresh with the same channels
- **GIVEN** a source with 100 000 channels
- **WHEN** it refreshes and brings back the same channels
- **THEN** the channel list and the guide are not rebuilt

#### Scenario: A channel counts as watched
- **GIVEN** the open group holds 50 000 channels
- **WHEN** a channel has played for ten seconds and joins Recents
- **THEN** the open group's list is not worked out again, unless the open group is Recents

#### Scenario: Logos scrolled past
- **GIVEN** a fast scroll through a large group in the Live list, the Guide or the Apple TV overlay
- **WHEN** rows leave the screen before their logos arrive
- **THEN** downloads that no row waits for stop, and the logos on screen do not queue behind them

#### Scenario: Guide progress
- **GIVEN** a large guide downloading for a source with 50 000 channels
- **WHEN** the download reports progress
- **THEN** channels are not matched to guide entries by name again until the guide or the channels change
