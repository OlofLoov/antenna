## ADDED Requirements

### Requirement: The tab bar sits in the same place on every tab
The system SHALL center the tabs on the screen's horizontal center, with the profile and Settings buttons to the right of the tabs, and SHALL show the bar at the same height along the top on Live, Guide, Movies, Series and Search. Over the Guide the bar SHALL leave the small picture uncovered.

#### Scenario: Over the picture and over Movies
- **GIVEN** a channel is playing full screen
- **WHEN** the user presses Back, and later opens Movies
- **THEN** the tabs sit on the screen's center line both times, at the same height

#### Scenario: With a profile button
- **GIVEN** the profiles Dad and Kids
- **WHEN** the tab bar shows
- **THEN** the tabs stay on the center line and the profile and Settings buttons sit to their right

#### Scenario: Over the Guide
- **GIVEN** the Guide is open with a channel in the small picture
- **WHEN** the user presses Back and the bar shows over the guide
- **THEN** the bar is at the same height as on every other tab, and the small picture starts below it
