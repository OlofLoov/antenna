# Spec Delta

## MODIFIED Requirements

### Requirement: VOD info
The system SHALL read a movie's plot, year, duration, genre, age rating, backdrops, container extension, cast, director, rating and trailer link. Duration SHALL come from `duration_secs` when above 0, else from `duration` as `hh:mm:ss` or `mm:ss`; 0 SHALL count as none. A missing or empty `info` SHALL leave every field empty.

#### Scenario: A full info body
- **GIVEN** a `get_vod_info` body with `info.plot` "A desert", `info.releasedate` "2024-03-01", `info.duration` "02:08:00", `info.duration_secs` 7680, `info.genre` "Sci-Fi", `info.age` "15", `info.backdrop_path` ["http://h/b1.jpg", "p.jpg"] and `movie_data.container_extension` "mkv"
- **WHEN** it is decoded
- **THEN** plot is "A desert", year 2024, duration 7680 seconds, genre "Sci-Fi", age rating "15", backdrops `http://h/b1.jpg` only, extension "mkv"

#### Scenario: Duration from text
- **GIVEN** the same body without `duration_secs`
- **WHEN** it is decoded
- **THEN** the duration is 7680 seconds from "02:08:00"

#### Scenario: Year and shapes
- **GIVEN** `info` absent, `{}` or `[]`; `movie_data` absent; `backdrop_path` as one string; a year in `release_date` or `releaseDate`; and a year of "0000"
- **WHEN** they are decoded
- **THEN** missing parts give empty fields, one backdrop string is accepted, the first non-empty of the three date keys gives the year, "0000" or a value not starting with four digits gives none, and `age` is read as number or string

#### Scenario: Cast, director and rating
- **GIVEN** an info body with a cast, a director and a rating of 7.4, and another with a rating of 0
- **WHEN** they are decoded
- **THEN** the first gives that cast, director and rating 7.4, and the second gives no rating

#### Scenario: Trailer link
- **GIVEN** a trailer field holding a full web address, an 11-character YouTube id, or anything else
- **WHEN** it is decoded
- **THEN** the address is kept as is, the id becomes a YouTube watch link, and anything else gives no trailer

## ADDED Requirements

### Requirement: Episode description and picture
The system SHALL read each episode's description and picture when the provider gives them, and SHALL leave them empty otherwise.

#### Scenario: Episode with and without details
- **GIVEN** a series info body where one episode has a description and a picture and another has neither
- **WHEN** it is decoded
- **THEN** the first episode carries its description and picture, and the second has none
