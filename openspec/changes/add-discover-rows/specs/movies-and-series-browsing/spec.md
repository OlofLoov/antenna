## ADDED Requirements

### Requirement: Trending in your sources
The system SHALL show a Trending row in Movies and in Series listing the titles from this week's TMDB trending list that the user's sources have, in trending order, at most 20. It SHALL never show a title no source has, and SHALL hide the row when fewer than three match or lookups are off.

#### Scenario: Trending titles the sources have
- **GIVEN** this week's trending movies include "Dune: Part Two" and "Heat", and one source has "EN | Dune: Part Two (2024) 4K" while no source has "Heat"
- **WHEN** the user opens Movies
- **THEN** the Trending row shows "Dune: Part Two" from that source and does not show "Heat"

#### Scenario: Ids first, then names
- **GIVEN** a source whose movies carry TMDB ids, and a playlist whose movies carry only names
- **WHEN** the Trending row fills
- **THEN** titles with an id match by id, and the rest match by their cleaned-up name and, when the name holds one, the year

#### Scenario: Too few matches
- **GIVEN** only two of this week's trending series are in the user's sources
- **WHEN** the user opens Series
- **THEN** there is no Trending row

#### Scenario: The same title on two sources
- **GIVEN** two sources both have a trending movie
- **WHEN** the Trending row fills
- **THEN** the movie shows once, from the source that comes first in the user's source order

#### Scenario: Lookups off
- **GIVEN** movie info lookups are turned off in Settings
- **WHEN** the user opens Movies or Series
- **THEN** there is no Trending row and no trending list is fetched

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user opens Movies
- **THEN** the row shows the last trending list fetched in the past seven days, or is hidden when there is none

#### Scenario: Nothing about the user is sent
- **WHEN** the trending list is fetched
- **THEN** the request names only movies or series and the week, and carries no title, source or profile

#### Scenario: Apple TV focus
- **GIVEN** the Trending row on Apple TV
- **WHEN** the user moves down from the row above and selects a poster
- **THEN** focus lands on the first Trending poster, and selecting it acts as any poster does

### Requirement: Recently watched
The system SHALL show a Recently watched row in Movies listing the movies, and in Series the series, that the current profile played on any device, finished ones included, most recent first, each once, at most 20, and SHALL hide the row when there are none.

#### Scenario: Movies and episodes watched
- **GIVEN** the profile finished a movie yesterday, stopped one part-way today, and watched two episodes of one series
- **WHEN** the user opens Movies and then Series
- **THEN** Movies' Recently watched lists today's movie then yesterday's, and Series' lists the series once

#### Scenario: Another profile
- **GIVEN** Kids watched a cartoon movie and Dad did not
- **WHEN** Dad opens Movies
- **THEN** the cartoon is not in Dad's Recently watched

#### Scenario: Watched on another device
- **GIVEN** the profile watched a movie on the iPad
- **WHEN** the user opens Movies on the Apple TV with the same iCloud account
- **THEN** the movie is in Recently watched once its progress has arrived

#### Scenario: Without movie info lookups
- **GIVEN** lookups are off and the device is offline
- **WHEN** the user opens Movies
- **THEN** Recently watched shows as usual

#### Scenario: A title no longer listed
- **GIVEN** a watched movie its source no longer lists
- **WHEN** the row fills
- **THEN** it is left out and its progress is kept

### Requirement: See everything new
The system SHALL offer See all on the Recently added row, opening a poster grid of every title newest first with its count, as a genre opens.

#### Scenario: See all on iPhone, iPad and Mac
- **GIVEN** the Recently added row
- **WHEN** the user picks See all
- **THEN** a poster grid of every title, newest first, takes the rows' place with the count above it

#### Scenario: See all on Apple TV
- **GIVEN** the Recently added row on Apple TV
- **WHEN** the user moves right past the last poster to See all and selects it
- **THEN** the grid opens as its own screen that Menu closes

#### Scenario: Titles without dates
- **GIVEN** a source whose titles have no date added
- **WHEN** the grid opens
- **THEN** dated titles come first, newest first, and undated ones follow in the provider's order

## MODIFIED Requirements

### Requirement: Rows in a predictable order
The system SHALL show, after Continue watching and My list, Trending, Recently watched, Recently added newest first and one row per category that has titles in the provider's order, each headed with its name and number of titles, leaving out a row with nothing in it.

#### Scenario: Provider categories
- **GIVEN** the provider's movies and categories
- **WHEN** the user opens Movies
- **THEN** after Continue watching and My list come Trending, Recently watched, Recently added, newest first, and one row per category that has titles, in the provider's order
- **AND** each row is headed with its name and number of titles

#### Scenario: Rows with nothing in them
- **GIVEN** a profile that has watched nothing and lookups turned off
- **WHEN** the user opens Movies
- **THEN** there is no Trending or Recently watched row, and Recently added follows My list

#### Scenario: Two sources with the same category
- **GIVEN** two Xtream sources share a category name
- **WHEN** the rows show
- **THEN** their titles merge into one row

#### Scenario: Thousands of categories
- **GIVEN** the provider has thousands of categories
- **WHEN** the user scrolls
- **THEN** rows load as they scroll into view and only visible rows fetch posters

#### Scenario: Missing or broken poster
- **GIVEN** a title's poster is missing or broken
- **WHEN** its poster shows
- **THEN** the title's name shows on a plain tile, never an empty frame

#### Scenario: Entries without a name or id
- **GIVEN** the provider lists entries without a name or id
- **WHEN** the rows fill
- **THEN** those entries are skipped

#### Scenario: VoiceOver reads a poster
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a poster
- **THEN** it is read as title, year and, when in progress, the minutes left
