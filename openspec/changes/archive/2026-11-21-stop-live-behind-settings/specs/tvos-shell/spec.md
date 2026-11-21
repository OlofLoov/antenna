## MODIFIED Requirements

### Requirement: Open Settings
The system SHALL open Settings as the last tab when the user selects it, and no channel SHALL play while Settings shows. Settings SHALL hold the video as Movies, Series and Search do: it pauses at once, the stream stops after 30 seconds, and going back to Live or Guide resumes a paused video or tunes a stopped one again at live.

#### Scenario: Settings button
- **GIVEN** the tab bar shows
- **WHEN** the user selects Settings
- **THEN** Settings opens, listing the sources and the way to add one

#### Scenario: No sound behind Settings
- **GIVEN** a channel is playing on Live
- **WHEN** the highlight moves along the tab bar to Settings
- **THEN** the video pauses when the first of Movies, Series, Search or Settings opens and stays paused on Settings
- **AND** the 30 seconds count from that first tab

#### Scenario: Back to Live from Settings
- **GIVEN** Settings has been open less than 30 seconds
- **WHEN** the user goes back to Live or Guide
- **THEN** the video plays on from where it paused, without loading the channel again

#### Scenario: Settings left open
- **GIVEN** Settings has been open for 30 seconds
- **WHEN** the user goes back to Live or Guide
- **THEN** the stream was stopped meanwhile, and the channel tunes again at live

#### Scenario: Closing Settings
- **GIVEN** Settings is open
- **WHEN** the user presses Menu
- **THEN** the highlight moves to Settings in the tab bar
