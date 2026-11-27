## Purpose

The app's side of matching the movies and series in the user's own sources to a public movie database: what a lookup may carry, what is kept on the device, how details and scores join the title page, and the switch that turns it off. Release builds have no lookup yet, and Debug builds use a sample lookup with made-up scores. It never adds a title the user's sources do not have.

## ADDED Requirements

### Requirement: Sample scores in Debug builds only
The system SHALL look nothing up in a Release build: a title page shows no scores and no details from a movie database, Settings shows no Movie info and scores switch, and no request leaves the device for a lookup. A Debug build SHALL offer sample scores, turned on from Settings or at launch, made up on the device from the title's cleaned-up name, the same for a title on every launch, and labelled Sample on the page.

#### Scenario: A Release build
- **GIVEN** a Release build
- **WHEN** the user opens a title's page and then Settings
- **THEN** the page shows the provider's details only, with no score row, and Settings has no Movie info and scores switch

#### Scenario: Sample scores in a Debug build
- **GIVEN** a Debug build with sample scores turned on
- **WHEN** the user opens "EN | The Long Harbor (2024) 4K" and later a title named "the long harbor" from 2024
- **THEN** both pages show the same TMDB score, and the score row ends with a Sample label

#### Scenario: Sample scores stay off the network and off the disk
- **GIVEN** a Debug build with sample scores turned on
- **WHEN** a title page shows a sample score
- **THEN** no request was made for it and nothing was written to the folder kept matches use

### Requirement: Only what is needed is looked up
The system SHALL look a title up only when its page opens, and SHALL give the lookup only the title's kind, its name cleaned of provider tags, its year and any database id its provider gave. It SHALL never send a source's link, login or name, a profile, or anything about the user, and SHALL never cause a request to the user's provider.

#### Scenario: Browsing rows
- **GIVEN** a source with 40,000 movies
- **WHEN** the user scrolls the Movies rows without opening a page
- **THEN** no title is looked up

#### Scenario: A name with provider tags
- **GIVEN** a playlist movie named "EN | Dune: Part Two (2024) 4K"
- **WHEN** its page opens
- **THEN** it is looked up as the movie "Dune: Part Two" from 2024, and a year from the provider wins over the one in the name

#### Scenario: What a lookup carries
- **GIVEN** a playlist movie whose link holds a username and password
- **WHEN** its page opens and it is looked up
- **THEN** the lookup gets the name and year, and no link, username, password, source name or profile

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
The system SHALL show the provider's details and let the user play without waiting for the lookup, add what the lookup gives when it arrives, and leave a failed lookup out with no message or Retry.

#### Scenario: A slow lookup
- **GIVEN** the lookup takes ten seconds to answer
- **WHEN** the user opens a title's page
- **THEN** Play, My list and the provider's details work at once, and the scores appear when the answer arrives without moving the buttons under the user's finger or focus

#### Scenario: The lookup fails
- **GIVEN** the lookup answers with an error
- **WHEN** the user opens a title's page
- **THEN** the page shows what was kept for the title, or the provider's details only when nothing was, and the title is tried again the next time its page opens

### Requirement: Details the provider left out come from the database
The system SHALL fill a matched title's missing description, year, length, genre, backdrop, cast and director from the match, and SHALL keep every field the provider gave.

#### Scenario: A plain playlist movie
- **GIVEN** a playlist movie with only a name, a logo and a group, matched to a film
- **WHEN** its page opens
- **THEN** it shows the film's year, length, genre, description, backdrop, cast and director from the match

#### Scenario: The provider's description wins
- **GIVEN** an Xtream movie whose provider gives a description and no cast
- **WHEN** it is matched
- **THEN** the page keeps the provider's description and adds the cast from the match

### Requirement: Lookups can be turned off
The system SHALL let the user turn movie database lookups off in Settings. While off, it SHALL look nothing up, delete what it kept, and show title pages with the provider's details only, on every device of the iCloud account.

#### Scenario: Turning lookups off
- **GIVEN** lookups are on and some titles were looked up
- **WHEN** the user turns lookups off
- **THEN** nothing is looked up from then on, the kept matches are deleted, and title pages show no scores and no details from the database
- **AND** the user's other devices turn lookups off when the setting reaches them

#### Scenario: Turning lookups back on
- **GIVEN** lookups are off
- **WHEN** the user turns them on and opens a title's page
- **THEN** the title is looked up again
