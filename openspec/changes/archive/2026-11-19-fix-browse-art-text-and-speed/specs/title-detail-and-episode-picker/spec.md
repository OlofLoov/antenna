## MODIFIED Requirements

### Requirement: What the title is about
The system SHALL show a title's backdrop, year, length or seasons, genre, rating, badges, description, cast and director once the details arrive, and SHALL leave out any field the provider does not give. Every word of the description, cast and director SHALL be reachable: on Apple TV through More, which opens them on a page of their own, and elsewhere by expanding in place. The backdrop SHALL keep its proportions.

#### Scenario: A movie with full details
- **GIVEN** a movie whose details include year 2024, a length of 2 h 08 min, genre Thriller, rating 7.4, age rating 15, a "2160p" name, a description, cast and a director
- **WHEN** the details arrive
- **THEN** the backdrop replaces the poster and the page shows year, length, genre, rating and the age and 4K badges, the description cut to a few lines with More, and the cast and director

#### Scenario: More on Apple TV
- **GIVEN** a title page on Apple TV whose description runs past its lines
- **WHEN** the viewer moves up to More and presses select
- **THEN** a full-screen page shows the name, the details line, the whole description, the cast and the director over the blurred title page
- **AND** swiping down and up scrolls a text longer than the screen
- **AND** Menu closes it and focus is back on More

#### Scenario: More on iPhone, iPad and Mac
- **GIVEN** a title page whose description runs past its lines
- **WHEN** the user taps or clicks More
- **THEN** the description shows in full in place, and so do the cast and director

#### Scenario: No backdrop
- **GIVEN** a title whose provider gives a poster but no backdrop
- **WHEN** its page shows
- **THEN** the poster sits on black where the backdrop would be

#### Scenario: A poster sent as the backdrop
- **GIVEN** a title whose provider's backdrop is a tall picture, such as its poster
- **WHEN** its page shows on a screen wider than it is tall
- **THEN** the whole picture shows at the right over a blurred copy of itself, never enlarged to a strip of its middle

#### Scenario: Missing fields
- **GIVEN** a title whose provider leaves fields out
- **WHEN** the details arrive
- **THEN** a missing field is simply missing, never "Unknown"

#### Scenario: A series
- **WHEN** a series' details arrive
- **THEN** it shows its number of seasons instead of a length, counted from what the episodes say when they disagree with the provider's season count

#### Scenario: Large text and VoiceOver
- **GIVEN** a large text size and VoiceOver on
- **WHEN** the page shows
- **THEN** the details line wraps, and VoiceOver reads the name, the details, then the description

### Requirement: What each episode shows
The system SHALL show each episode with a picture, number, title, length and one line of description, marking finished episodes Watched and showing progress for ones in progress. An episode with a description SHALL offer Description in its menu, which shows the whole description.

#### Scenario: Episodes in every state
- **GIVEN** episodes watched to the end, part-way, barely or not at all, some without a picture, title or description
- **WHEN** the user looks at the episode list
- **THEN** each row shows a picture, or a tile with the episode number, the number, the title, the length and one line of description
- **AND** a finished episode shows a full bar and "Watched" instead of its length, one in progress shows its bar and the minutes left, and one barely started looks unwatched
- **AND** missing fields are left out

#### Scenario: Reading an episode's description
- **GIVEN** an episode whose description is longer than its line
- **WHEN** the user long-presses its row on Apple TV, or opens its menu on iPhone, iPad or Mac, and picks Description
- **THEN** the episode's number, title, length and whole description show on a page of their own that Menu, Done or Escape closes
- **AND** an episode without a description has no Description item

#### Scenario: No episodes or unreadable ones
- **GIVEN** a series with no episodes, or with episodes the provider listed but could not describe
- **WHEN** the page shows
- **THEN** a series with none says "No episodes available", and unreadable ones are counted under the list as "<n> episodes could not be read from the provider's list."

#### Scenario: Watched outside Antenna
- **GIVEN** an episode watched outside Antenna
- **WHEN** the list shows
- **THEN** it shows as unwatched until played here

#### Scenario: VoiceOver on an episode
- **GIVEN** VoiceOver on
- **WHEN** the user moves to an episode
- **THEN** it reads the number, title, length, minutes left or watched, and "up next" when marked
