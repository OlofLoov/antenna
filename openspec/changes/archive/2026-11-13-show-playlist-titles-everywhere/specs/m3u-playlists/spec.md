## MODIFIED Requirements

### Requirement: Playlist movies show in Movies
The system SHALL list a playlist's movies in the Movies section with the entry's name, its logo as the poster and its group as the category, and SHALL play a movie from its link. A movie's id SHALL hold no link or login. Where the Movies section shows is set by the requirement "Playlist titles show on every platform".

#### Scenario: Browsing playlist movies
- **GIVEN** a playlist with a movie "Film A" in the group "VOD | Action"
- **WHEN** the user opens Movies
- **THEN** "Film A" shows under "VOD | Action" and plays from its link

#### Scenario: A playlist without movies
- **GIVEN** only a playlist with live channels
- **WHEN** it loads
- **THEN** there is no Movies tab or section

#### Scenario: Series
- **GIVEN** an iPhone with only a playlist that has episodes
- **WHEN** it loads
- **THEN** the Movies tab shows and its Series part lists the playlist's shows

## ADDED Requirements

### Requirement: Playlist titles show on every platform
The system SHALL treat a playlist whose last load on this device had movies or episodes like an Xtream source wherever Movies, Series or titles show: the iPhone tab bar, the iPad and Mac sidebar, the Apple TV tab bar, the Movies and Series chips in Search, the "Open on launch" choices, the section the app reopens on, Top Shelf links and Siri.

#### Scenario: iPad sidebar with a playlist
- **GIVEN** an iPad with only a playlist that has movies and episodes
- **WHEN** the playlist has loaded
- **THEN** the sidebar lists Movies and Series, and each opens the playlist's titles

#### Scenario: Searching playlist titles on Apple TV
- **GIVEN** an Apple TV with only a playlist that has the movie "Film A"
- **WHEN** the user searches "film"
- **THEN** "Film A" is a result

#### Scenario: Searching playlist titles on iPhone, iPad and Mac
- **GIVEN** only a playlist that has movies
- **WHEN** the user searches
- **THEN** the Movies and Series chips show beside the others

#### Scenario: Open on launch with a playlist
- **GIVEN** only a playlist whose last load had movies
- **WHEN** the user opens the "Open on launch" choices
- **THEN** Movies is one of them, and choosing it opens Movies at the next launch before the playlist has loaded again

#### Scenario: Top Shelf link to a playlist movie
- **GIVEN** an Apple TV whose Top Shelf shows a playlist movie from Continue watching
- **WHEN** the user selects its tile
- **THEN** the movie plays once the playlist's titles have loaded

#### Scenario: Siri finds a playlist movie
- **GIVEN** only a playlist that has the movie "Film A", and the app not running
- **WHEN** the user asks Siri to play "Film A" in Antenna
- **THEN** the movie is found and plays

### Requirement: Movies and Series show by what the sources offer
The iPad and Mac sidebar and the Apple TV tab bar SHALL show Movies only when a source offers movies, and Series only when a source offers series. An Xtream source SHALL offer both, whether or not it has answered. A playlist SHALL offer movies when its last load had movies and series when it had episodes.

#### Scenario: Mac sidebar with a playlist
- **GIVEN** a Mac with only a playlist that has movies
- **WHEN** the playlist has loaded
- **THEN** the sidebar lists Movies and not Series

#### Scenario: Apple TV with a playlist of episodes only
- **GIVEN** an Apple TV with only a playlist whose on-demand entries are episodes
- **WHEN** it loads
- **THEN** the tab bar shows Series and not Movies, and Series lists the shows

#### Scenario: A playlist that loses its titles
- **GIVEN** a playlist whose movies were removed by its provider, with Movies open
- **WHEN** it loads again with no movies or episodes
- **THEN** Movies and Series leave the tab bar or sidebar and Live shows

### Requirement: What a playlist offered is remembered
The system SHALL remember on the device how many movies and episodes each playlist's last load had, holding no link or login, so the tabs, the sidebar and the launch screen are right before the playlist loads again.

#### Scenario: Reopening on Series
- **GIVEN** an iPad with only a playlist that has episodes, last left on Series
- **WHEN** the app opens again
- **THEN** it opens on Series

#### Scenario: Open on launch with episodes only on Apple TV
- **GIVEN** an Apple TV set to open on Movies, with only a playlist that has episodes
- **WHEN** the app opens
- **THEN** it opens on Series
