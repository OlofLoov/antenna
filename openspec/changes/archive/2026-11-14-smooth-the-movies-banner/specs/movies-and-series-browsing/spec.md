## MODIFIED Requirements

### Requirement: New titles up front
The system SHALL show the newest title in the banner with its name, category, year, length and description, move through the four newest by itself while the user is not interacting with it, and let the user page it by hand. The banner SHALL fade from one title to the next, and its art SHALL stay inside it.

#### Scenario: Titles with dates added
- **GIVEN** the provider's movies have dates they were added
- **WHEN** the user opens Movies
- **THEN** the banner shows the newest title with its name, category, year, length and description
- **AND** it moves through the four newest by itself while the user is not interacting with it
- **AND** the user can page it by hand

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the banner shows
- **THEN** it never moves by itself
- **AND** paging wraps at either end

#### Scenario: Two Xtream sources
- **GIVEN** the user has two Xtream sources
- **WHEN** the banner fills
- **THEN** it picks titles from both

#### Scenario: Moving to the next title
- **GIVEN** the banner shows a title
- **WHEN** it moves to the next title, by itself or by hand
- **THEN** the picture and the words fade across to the next title
- **AND** the banner never shows the empty placeholder between two titles that have pictures

#### Scenario: A title with a backdrop
- **GIVEN** the provider's info call for a title answers with a backdrop within 1.5 seconds
- **WHEN** the banner shows the title
- **THEN** the backdrop shows, without the poster showing first

#### Scenario: A title with only a poster
- **GIVEN** a title in the banner has a poster and no backdrop
- **WHEN** the banner shows it, or pages to or from it
- **THEN** nothing of the poster shows above, below or beside the banner
- **AND** the banner's name, details and buttons stay where the board puts them
- **AND** on iPad, Mac and Apple TV the whole poster shows at the right of the banner over a blurred copy of itself
- **AND** on iPhone the poster fills the banner
