## MODIFIED Requirements

### Requirement: Movies and episodes in a playlist are recognized
The system SHALL sort each playlist entry by the first rule that applies, in this order:
1. A link with a `series` folder is an episode.
2. A link with a `movie` or `movies` folder is a movie.
3. A name with a season and episode marker such as "S01E02" is an episode.
4. A group whose first word is VOD, Movie, Movies, Film or Films is a movie.
5. An entry with a live sign is a live channel. Live signs are: catch-up attributes, a guide id, a group with the word Live, News, Sport or Sports or the text "24/7", and an `#EXTINF` duration of -1 or 0.
6. A link ending in `.mp4`, `.mkv`, `.avi`, `.mov` or `.m4v` is a movie.

Every other entry SHALL be a live channel.

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

#### Scenario: A news channel served as an mp4 file
- **GIVEN** an entry `#EXTINF:-1 tvg-id="news24.example" group-title="News"` linking to `http://cdn.example/news24/live.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a live channel and shows in Live, not in Movies

#### Scenario: A movie file with a length
- **GIVEN** an entry `#EXTINF:5400,The Film` with no guide id, no group and no catch-up, linking to `http://cdn.example/the-film.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a movie

#### Scenario: A movie link beats live signs
- **GIVEN** an entry with a guide id and catch-up attributes linking to `http://tv.example.net/movie/u/p/9.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a movie
