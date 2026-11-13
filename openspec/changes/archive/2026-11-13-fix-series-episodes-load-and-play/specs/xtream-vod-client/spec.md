## MODIFIED Requirements

### Requirement: Episodes flatten
The system SHALL turn the episodes of a series, keyed by season or given as an array, into one flat list. An array whose elements are arrays SHALL be read as seasons in order, the first being season 0. Under a season key, an object of episodes keyed by number SHALL give those episodes in key order, and a single episode object SHALL give that episode. An episode's season SHALL be its own `season` field, else the season key or position when it is a number. A season value that is neither an array nor an object SHALL give no episodes. Each episode SHALL get the id `xtream#<host>#episode#<id>`, and a title given as a number SHALL be read as its text.

#### Scenario: Dictionary keyed by season
- **GIVEN** a `get_series_info` whose `episodes` is keyed "1", "2" and "10", each episode with `id`, `episode_num`, `title`, `container_extension` and `info.duration_secs`
- **WHEN** it is decoded with host H
- **THEN** the series details follow the movie info rules, and the episodes are one flat list with id, season, number, title, extension and duration

#### Scenario: Array of episodes
- **GIVEN** `episodes` as an array
- **WHEN** it is decoded
- **THEN** the same flat list results

#### Scenario: Array of season arrays
- **GIVEN** `episodes` as an array of three arrays, the first holding a special, the second two episodes of season 1 and the third an episode that says it is season 2
- **WHEN** it is decoded
- **THEN** the special is in season 0, the next two in season 1 and the last in season 2, and none are skipped

#### Scenario: A season keyed by episode number
- **GIVEN** season "1" as an object holding episodes under "2" and "1" and a string under "3", and season "2" as one episode object
- **WHEN** it is decoded
- **THEN** season 1 has its two episodes in order, season 2 has its one episode, and the string counts as one skipped episode

#### Scenario: Season and number fallback
- **GIVEN** episodes with no `season` of their own, a non-numeric season key, or an `episode_num` that is absent or not a number
- **WHEN** they are decoded
- **THEN** the season comes from the key when numeric, else none, the number is none when not numeric, and the response's `seasons` array is ignored

#### Scenario: Leading zeros, numbers and odd keys
- **GIVEN** `episodes` keyed "01" holding an episode with `id` "9", `title` 42 and `episode_num` "3", and a key "x" holding 5
- **WHEN** they are decoded
- **THEN** the one episode is in season 1, number 3, titled "42", and the "x" key adds nothing and is not counted as skipped

## ADDED Requirements

### Requirement: Panel bodies that are almost JSON
The system SHALL read a panel's answer that is JSON apart from a byte-order mark, a server notice printed before it, text after it, text in Latin-1 or Windows-1252, or tabs and line breaks typed inside a string, as the JSON it holds. A web page SHALL still fail to read.

#### Scenario: A notice before the series
- **GIVEN** a `get_series_info` answer that starts with a PHP notice, holds a plot in Windows-1252 with a raw tab and line break, and ends with a warning
- **WHEN** it is decoded
- **THEN** the plot reads "Café owner’s story" with its tab and line break, and the episode list is complete

#### Scenario: A byte-order mark
- **GIVEN** a series list or series answer that starts with a UTF-8 byte-order mark
- **WHEN** it is decoded
- **THEN** it reads as if the mark were not there, and a refused login is still reported as refused

#### Scenario: A web page
- **GIVEN** a login page, or any answer with `<html` or `<!doctype` before its first brace
- **WHEN** it is decoded
- **THEN** it fails as a body that is not JSON
