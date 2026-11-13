## MODIFIED Requirements

### Requirement: Playlist movies stay out of live channels
The system SHALL leave a playlist's movies and episodes out of its live channels everywhere live channels show, and out of the channel count of the onboarding checklist and Settings. Live channels SHALL keep their playlist order.

#### Scenario: A playlist with channels and movies
- **GIVEN** a playlist with two live channels, one movie and one episode
- **WHEN** it loads
- **THEN** Live lists the two channels, and not the movie or the episode

### Requirement: Playlist movies show in Movies
The system SHALL list a playlist's movies in the Movies section with the entry's name, its logo as the poster and its group as the category, and SHALL play a movie from its link. The Movies tab SHALL show on iPhone and Apple TV when a playlist's last load had movies or episodes, even without an Xtream source. A movie's id SHALL hold no link or login.

#### Scenario: Browsing playlist movies
- **GIVEN** a playlist with a movie "Film A" in the group "VOD | Action"
- **WHEN** the user opens Movies
- **THEN** "Film A" shows under "VOD | Action" and plays from its link

#### Scenario: A playlist without movies
- **GIVEN** only a playlist with live channels
- **WHEN** it loads
- **THEN** there is no Movies tab

#### Scenario: Series
- **GIVEN** a playlist with episodes only
- **WHEN** it loads
- **THEN** the Movies tab shows and its Series part lists the playlist's shows

## ADDED Requirements

### Requirement: Playlist episodes group into series
The system SHALL group a playlist's episodes into series by the show name, the part of the entry name before its season and episode marker, ignoring case, punctuation and spacing. Each episode SHALL take its season, number and title from the name, and episodes SHALL be ordered by season, then number. Series and episode ids SHALL hold no link or login.

#### Scenario: Two seasons of one show
- **GIVEN** entries named "Show S02E01", "Show - S01E02 - The Visit" and "show s01e01"
- **WHEN** the playlist loads
- **THEN** there is one series "Show" with season 1 episodes 1 and 2 ("The Visit") and season 2 episode 1

#### Scenario: Different shows
- **GIVEN** entries named "Alpha S01E01" and "Beta S01E01"
- **WHEN** the playlist loads
- **THEN** there are two series, "Alpha" and "Beta"

#### Scenario: An episode without a title or marker
- **GIVEN** an entry "Show S01E03" and an entry "Pilot" whose link has a `series` folder
- **WHEN** the playlist loads
- **THEN** the first is "Episode 3" of "Show", and "Pilot" is a series of its own

### Requirement: Playlist series show in Series
The system SHALL list a playlist's series in the Series section with the first episode's logo as the poster and its group as the category. Opening one SHALL show its title page with the seasons and the episode picker, and an episode SHALL play from its link.

#### Scenario: Watching a playlist episode
- **GIVEN** a playlist with episodes of "Show" in the group "Shows"
- **WHEN** the user opens Series, picks "Show" and plays season 1 episode 2
- **THEN** the episode plays from its link

#### Scenario: A playlist with episodes only
- **GIVEN** only a playlist whose entries are episodes
- **WHEN** it loads
- **THEN** Live has no channels from it and Series lists its shows
