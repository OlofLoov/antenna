## ADDED Requirements

### Requirement: A title is matched by its database id first
The system SHALL match a movie or series to the movie database by the database id its provider gives, and only when there is none by its cleaned-up name and year. A title with no confident match SHALL stay unmatched.

#### Scenario: The provider gives an id
- **GIVEN** an Xtream movie "Dune" whose provider gives TMDB id 438631
- **WHEN** the user opens its page
- **THEN** it is matched to that database entry without a name search

#### Scenario: A name with provider tags
- **GIVEN** a playlist movie named "EN | Dune: Part Two (2024) 4K" with no database id
- **WHEN** the user opens its page
- **THEN** it is looked up as "Dune: Part Two" from 2024 and matched to that film

#### Scenario: A name with no year
- **GIVEN** a movie named "Heat" with no year from the provider, and the database has several films called "Heat"
- **WHEN** the user opens its page
- **THEN** it is matched only when one result has exactly that name and clearly more votes than the rest, and otherwise it stays unmatched

#### Scenario: No match
- **GIVEN** a title the database does not know, such as a home recording or a sports replay
- **WHEN** the user opens its page
- **THEN** the page shows what the provider gave and nothing from the database, with no error

### Requirement: The database is credited
The system SHALL credit the movie database in Settings, under About, with its logo and the notice its terms ask for, and SHALL name the site next to every score it shows.

#### Scenario: About in Settings
- **WHEN** the user opens About in Settings on any device
- **THEN** a row names the movie database with its logo and says Antuna uses its API but is not endorsed or certified by it

#### Scenario: A score on a page
- **WHEN** a title page shows a score
- **THEN** the site the score is from is named beside it
