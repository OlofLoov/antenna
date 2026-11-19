## ADDED Requirements

### Requirement: Names on list rows
The system SHALL read a movie or series row's `cast`, else `actors`, and `director` when the panel puts them in the list, with the rules of the info call's cast and director, and SHALL leave them out when the row has none.

#### Scenario: A series row with a cast
- **GIVEN** a `get_series` row with `cast` "Mira Holt, Jonas Reeve" and `director` "Sanna Weiss"
- **WHEN** it is decoded
- **THEN** the series has that cast and that director

#### Scenario: A movie row without names
- **GIVEN** a `get_vod_streams` row with no `cast`, `actors` or `director`
- **WHEN** it is decoded
- **THEN** the movie has no cast and no director, and the row is kept
