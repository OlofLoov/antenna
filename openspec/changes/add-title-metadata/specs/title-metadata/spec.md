## Purpose

Matches the movies and series in the user's own sources to a public movie database, so a title page can show scores and fill in details the provider left out, and later changes can show trending titles and the people in them. It never adds a title the user's sources do not have.

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

### Requirement: Only what is needed is looked up
The system SHALL look a title up only when its page opens, and SHALL send the database only the title's name, year and ids. It SHALL never send a source's link, login or name, a profile, or anything about the user, and SHALL never cause a request to the user's provider.

#### Scenario: Browsing rows
- **GIVEN** a source with 40,000 movies
- **WHEN** the user scrolls the Movies rows without opening a page
- **THEN** no title is looked up

#### Scenario: What a lookup carries
- **GIVEN** a playlist movie whose link holds a username and password
- **WHEN** its page opens and it is looked up
- **THEN** the request holds the name and year, and no link, username, password, source name or profile

### Requirement: Matches are kept on the device
The system SHALL keep each match and the details and scores it brought on the device, show them from there the next time without waiting, and ask again only after seven days. Nothing looked up SHALL sync to other devices, and nothing SHALL be kept longer than six months.

#### Scenario: Opening a page again
- **GIVEN** a title looked up yesterday
- **WHEN** the user opens its page again
- **THEN** its scores and details show at once with no new lookup

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user opens a page looked up before, and one never looked up
- **THEN** the first shows what was kept, and the second shows the provider's details only, with no error about the database

#### Scenario: Deleting a source
- **GIVEN** matches for titles from a source
- **WHEN** the source is deleted on this device or another
- **THEN** its matches are removed from this device

### Requirement: A slow or failing lookup never holds up the page
The system SHALL show the provider's details and let the user play without waiting for the database, add what the database gives when it arrives, and leave a failed lookup out with no message or Retry.

#### Scenario: A slow database
- **GIVEN** the database takes ten seconds to answer
- **WHEN** the user opens a title's page
- **THEN** Play, My list and the provider's details work at once, and the scores appear when the answer arrives without moving the buttons under the user's finger or focus

#### Scenario: The database is down
- **GIVEN** the database answers with an error
- **WHEN** the user opens a title's page
- **THEN** the page looks as it did before this change, and the title is tried again the next time its page opens

### Requirement: Details the provider left out come from the database
The system SHALL fill a matched title's missing description, year, length, genre, backdrop, cast and director from the database, and SHALL keep every field the provider gave.

#### Scenario: A plain playlist movie
- **GIVEN** a playlist movie with only a name, a logo and a group, matched to a film
- **WHEN** its page opens
- **THEN** it shows the film's year, length, genre, description, backdrop, cast and director from the database

#### Scenario: The provider's description wins
- **GIVEN** an Xtream movie whose provider gives a description and no cast
- **WHEN** it is matched
- **THEN** the page keeps the provider's description and adds the cast from the database

### Requirement: Lookups can be turned off
The system SHALL let the user turn movie database lookups off in Settings. While off, it SHALL send nothing to the database, delete what it kept, and show title pages with the provider's details only, on every device of the iCloud account.

#### Scenario: Turning lookups off
- **GIVEN** lookups are on and some titles were looked up
- **WHEN** the user turns lookups off
- **THEN** no request goes to the database from then on, the kept matches are deleted, and title pages show no scores and no details from the database
- **AND** the user's other devices turn lookups off when the setting reaches them

#### Scenario: Turning lookups back on
- **GIVEN** lookups are off
- **WHEN** the user turns them on and opens a title's page
- **THEN** the title is looked up again

### Requirement: The database is credited
The system SHALL credit the movie database in Settings, under About, with its logo and the notice its terms ask for, and SHALL name the site next to every score it shows.

#### Scenario: About in Settings
- **WHEN** the user opens About in Settings on any device
- **THEN** a row names the movie database with its logo and says Antenna uses its API but is not endorsed or certified by it

#### Scenario: A score on a page
- **WHEN** a title page shows a score
- **THEN** the site the score is from is named beside it
