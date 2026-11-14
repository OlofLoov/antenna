## ADDED Requirements

### Requirement: Scores from other sites
The system SHALL show a matched title's scores from other sites on its page, below the Play and My list buttons, each with the site's name, on iPhone, iPad, Mac and Apple TV, and SHALL leave out a site that has no score for the title.

#### Scenario: A matched movie
- **GIVEN** a movie matched to the movie database, with a TMDB user score of 74%
- **WHEN** its page shows
- **THEN** "TMDB 74%" shows below the buttons

#### Scenario: Scores from several sites
- **GIVEN** a matched movie with scores from more than one site
- **WHEN** its page shows
- **THEN** each score shows with its site's name, in a fixed order, and a site with no score for the title is left out

#### Scenario: No match or lookups off
- **GIVEN** a title with no match, or lookups turned off
- **WHEN** its page shows
- **THEN** no score row shows and the page keeps its layout

#### Scenario: Apple TV focus
- **GIVEN** a title page on Apple TV with a score row
- **WHEN** the user moves focus
- **THEN** the scores take no focus, and focus moves between Play, My list, Trailer and More as before

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** it reads the page
- **THEN** it reads each score with its site after the details, for example "TMDB user score 74 percent"

## MODIFIED Requirements

### Requirement: What the title is about
The system SHALL show a title's backdrop, year, length or seasons, genre, rating, badges, description, cast and director once the details arrive, and SHALL leave out any field the provider does not give.

#### Scenario: A movie with full details
- **GIVEN** a movie whose details include year 2024, a length of 2 h 08 min, genre Thriller, rating 7.4, age rating 15, a "2160p" name, a description, cast and a director
- **WHEN** the details arrive
- **THEN** the backdrop replaces the poster and the page shows year, length, genre, rating and the age and 4K badges, the description cut to a few lines with More, and the cast and director

#### Scenario: No backdrop
- **GIVEN** a title whose provider gives a poster but no backdrop
- **WHEN** its page shows
- **THEN** the poster sits on black where the backdrop would be

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

#### Scenario: Scores replace the provider's rating
- **GIVEN** a title with a provider rating of 7.4 that is matched and has at least one score from another site
- **WHEN** the page shows
- **THEN** the details line leaves out the provider's rating and the score row shows instead
- **AND** with no score from another site, the provider's rating stays in the details line
