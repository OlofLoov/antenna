## MODIFIED Requirements

### Requirement: New titles up front
The system SHALL show the newest title in the banner with its name, category, year, length and description, move through the four newest by itself while the user is not interacting with it, and let the user page it by hand. The banner's art SHALL fill the banner and stay inside it, whatever the shape of the picture.

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

#### Scenario: A title with only a poster
- **GIVEN** a title in the banner has a poster and no backdrop
- **WHEN** the banner shows it, or pages to or from it
- **THEN** the poster fills the banner and nothing of it shows above, below or beside the banner
- **AND** the banner's name, details and buttons stay where the board puts them
