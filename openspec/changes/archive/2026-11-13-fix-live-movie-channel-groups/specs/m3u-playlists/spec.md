## MODIFIED Requirements

### Requirement: Movies and episodes in a playlist are recognized
The system SHALL sort each playlist entry by the first rule that applies: a `series` folder in the link makes it an episode; a `movie` or `movies` folder a movie; an episode marker such as "S01E02" in the name an episode; a group starting with VOD a movie; a group starting with Movie or Film a movie when the link is a video file; a live sign a live channel; a video file a movie. A video file link ends in `.mp4`, `.mkv`, `.avi`, `.mov` or `.m4v`. Every other entry SHALL be a live channel.

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

#### Scenario: Live movie channels in a Movies group
- **GIVEN** entries in the group "Movies" linking to `http://tv.example/live/u/p/5.ts`, `http://tv.example/hls/film4.m3u8` and `http://tv.example/u/p/6`
- **WHEN** the playlist loads
- **THEN** each entry is a live channel and shows in Live

#### Scenario: Movie files in a Movies group
- **GIVEN** an entry `#EXTINF:-1 group-title="Movies | Drama"` linking to `http://cdn.example/files/the-film.mp4`
- **WHEN** the playlist loads
- **THEN** the entry is a movie
