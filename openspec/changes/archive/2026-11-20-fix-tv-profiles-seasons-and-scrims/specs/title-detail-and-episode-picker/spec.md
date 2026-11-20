## MODIFIED Requirements

### Requirement: Pick a season
The system SHALL group a series' episodes into seasons, specials and other episodes, open on the season holding the episode Play would start, and show only the picked season's episodes in order.

#### Scenario: Pick Season 3
- **GIVEN** a series with seasons 1, 2 and 3, specials (season 0) and episodes with no season
- **WHEN** the user opens its page and picks Season 3 by tap, click, the arrow keys, or on Apple TV by resting on it
- **THEN** the picker lists "Season 1", "Season 2", "Season 3", "Specials" and "Other", opens on the season that holds the episode Play would start, and after the pick shows only Season 3's episodes in order with its episode count

#### Scenario: Many seasons
- **GIVEN** a series with fifteen seasons
- **WHEN** its page shows on iPhone, iPad, Mac or Apple TV
- **THEN** the season chips that do not fit scroll within their row, and none of them covers the episode count at the end of the row

#### Scenario: One group only
- **GIVEN** a series whose episodes form one group
- **WHEN** its page shows
- **THEN** there is no season picker
