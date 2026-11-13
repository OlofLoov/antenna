## ADDED Requirements

### Requirement: Movie database ids
The system SHALL read a TMDB id from a movie or series row's `tmdb` or `tmdb_id` field and from an info body's `tmdb_id` or `tmdb` field, and an IMDb id from an info body's `imdb_id` field. A TMDB id SHALL be a positive whole number given as a number or as digits; an IMDb id SHALL be `tt` followed by digits. Anything else SHALL leave the id empty without failing the row.

#### Scenario: A row with a TMDB id
- **GIVEN** a `get_vod_streams` row for "Dune" with `tmdb` "438631", and a `get_series` row for "Dark" with `tmdb_id` 70523
- **WHEN** they are decoded
- **THEN** the movie has TMDB id 438631 and the series has TMDB id 70523

#### Scenario: An info body with both ids
- **GIVEN** a `get_vod_info` body whose `info` has `tmdb_id` 438631 and `imdb_id` "tt1160419"
- **WHEN** it is decoded
- **THEN** the details carry TMDB id 438631 and IMDb id "tt1160419"

#### Scenario: Ids that are not ids
- **GIVEN** rows with `tmdb` "", "0", "n/a", -5 or 12.5, and an info body with `imdb_id` "1160419"
- **WHEN** they are decoded
- **THEN** each row keeps its other fields and has no TMDB id, and the info body has no IMDb id

#### Scenario: A row without ids
- **GIVEN** a row with neither field
- **WHEN** it is decoded
- **THEN** it decodes as before with no TMDB id
