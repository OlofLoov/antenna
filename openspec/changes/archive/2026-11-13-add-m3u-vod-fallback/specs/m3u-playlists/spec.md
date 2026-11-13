## ADDED Requirements

### Requirement: Movies and episodes in a playlist are recognized
The system SHALL sort each playlist entry, in this order: a link with a `series` folder is an episode; a link with a `movie` or `movies` folder is a movie; a name with a season and episode marker such as "S01E02" is an episode; a link ending in `.mp4`, `.mkv`, `.avi`, `.mov` or `.m4v` is a movie; a group whose first word is VOD, Movie, Movies, Film or Films is a movie. Every other entry SHALL be a live channel.

#### Scenario: A panel's movie link
- **GIVEN** an entry linking to `http://tv.example.net/movie/u/p/9.mkv`
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: A movie group
- **GIVEN** an entry in the group "VOD | Action" whose link has no file extension
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: An episode
- **GIVEN** an entry named "Show S01E02" linking to an `.mp4` file
- **WHEN** the playlist loads
- **THEN** the entry is an episode, not a movie

#### Scenario: A live channel
- **GIVEN** an entry in the group "Vodafone TV" linking to a `.ts` stream
- **WHEN** the playlist loads
- **THEN** the entry is a live channel

### Requirement: Playlist movies stay out of live channels
The system SHALL leave a playlist's movies out of its live channels everywhere live channels show, and out of the channel count of the onboarding checklist and Settings. Episodes and live channels SHALL keep their playlist order.

#### Scenario: A playlist with channels and movies
- **GIVEN** a playlist with two live channels, one movie and one episode
- **WHEN** it loads
- **THEN** Live lists the two channels and the episode, and not the movie

### Requirement: Playlist movies show in Movies
The system SHALL list a playlist's movies in the Movies section with the entry's name, its logo as the poster and its group as the category, and SHALL play a movie from its link. The Movies tab SHALL show on iPhone and Apple TV when a playlist's last load had movies, even without an Xtream source. A movie's id SHALL hold no link or login.

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
- **WHEN** the user opens Series
- **THEN** the playlist adds no series
