## ADDED Requirements

### Requirement: Season and episode markers
The system SHALL read a season and episode marker in a playlist entry name written as "S01E02" or "s1 e12", as "1x02" or "01x02" with a two- or three-digit episode, or spelled out as "Season 1 Episode 2" or "Season 1, Ep 2", ignoring case. A crossed number with a letter or digit right before or after it, or with a one-digit episode, SHALL NOT be a marker, and neither SHALL an episode number without a season. Every rule that sorts or groups episodes SHALL use the same markers.

#### Scenario: A crossed season and episode
- **GIVEN** an entry named "Show 1x02" linking to an `.mp4` file
- **WHEN** the playlist loads
- **THEN** the entry is season 1 episode 2 of the series "Show", not a movie

#### Scenario: A spelled-out season and episode
- **GIVEN** an entry named "Show Season 1 Episode 2 - The Visit"
- **WHEN** the playlist loads
- **THEN** the entry is season 1 episode 2, "The Visit", of the series "Show"

#### Scenario: Names that only look like a marker
- **GIVEN** an entry named "4x4 Off-Road" linking to an `.mp4` file, and entries named "Comedy 24x7" and "Nature 1920x1080" linking to `.ts` streams
- **WHEN** the playlist loads
- **THEN** the first is a movie and the other two are live channels

#### Scenario: An episode number without a season
- **GIVEN** an entry named "Show Ep 2" linking to an `.mp4` file
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: One show, two ways of writing it
- **GIVEN** entries named "Show S01E01", "Show 1x02" and "Show Season 2 Episode 1"
- **WHEN** the playlist loads
- **THEN** there is one series "Show" with season 1 episodes 1 and 2 and season 2 episode 1
