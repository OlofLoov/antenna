## ADDED Requirements

### Requirement: The iPhone tab bar
The system SHALL show on iPhone, and on iPad in a narrow window, a tab bar holding Live, Guide, Movies and Series, with Search as the system's round search button at its trailing end and no Settings tab. Movies and Series SHALL each show only when the sources offer them, and each SHALL keep its own place.

#### Scenario: Sources with movies and series
- **GIVEN** an iPhone with an Xtream source
- **WHEN** the tab bar shows
- **THEN** it holds Live, Guide, Movies and Series in that order, then the search button at its trailing end
- **AND** there is no Settings tab and no Movies | Series switch

#### Scenario: A playlist with movies only
- **GIVEN** an iPhone whose only source is a playlist whose last load had movies and no episodes
- **WHEN** the tab bar shows
- **THEN** it holds Movies and no Series tab

#### Scenario: Each tab keeps its place
- **GIVEN** Movies is open with the Drama genre picked and the rows scrolled down
- **WHEN** the user opens Series and comes back to Movies
- **THEN** Series shows its own rows from its banner, and Movies shows Drama where the user left it

#### Scenario: Search from the tab bar
- **GIVEN** Movies is open
- **WHEN** the user taps the search button
- **THEN** Search opens with the field ready for typing, and Cancel goes back to Movies

#### Scenario: Right-to-left
- **GIVEN** the app in Arabic
- **WHEN** the tab bar shows
- **THEN** Live is the rightmost tab and the search button sits at the left end

### Requirement: Settings from the profile button
The system SHALL show a profile button at the top right of Live, the Guide, Movies and Series on iPhone and in a narrow iPad window, and SHALL open Settings from it as a sheet over the open tab. With two or more profiles the button SHALL show the current profile and open a menu with Switch profile and Settings.

#### Scenario: Settings with one profile
- **GIVEN** one profile
- **WHEN** the user taps the profile button, a person glyph, on any of Live, the Guide, Movies or Series
- **THEN** Sources & Settings opens as a sheet over that tab, and Close goes back to the tab as it was

#### Scenario: Settings with two or more profiles
- **GIVEN** the profiles Dad and Kids, with Kids current
- **WHEN** the user taps the profile button, a circle in Kids's color with its initial
- **THEN** a menu headed Kids offers Switch profile and Settings

#### Scenario: Nothing to watch yet
- **GIVEN** Live or the Guide shows a whole-screen message, such as no sources, a failed source or no connection
- **WHEN** the user looks for Settings
- **THEN** the profile button sits in the top right corner over the message

#### Scenario: A link to Settings
- **GIVEN** the empty or error state's Open Settings, or a reminder's Watch while Settings is open
- **WHEN** the user taps it
- **THEN** Open Settings opens the Settings sheet, and Watch closes the sheet and plays the channel in Live

#### Scenario: Right-to-left
- **GIVEN** the app in Arabic
- **WHEN** Live shows
- **THEN** the profile button sits at the left end of the group row

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the profile button is focused
- **THEN** it reads "Settings" with one profile, and "Profile, Kids" with Kids current among two or more

## MODIFIED Requirements

### Requirement: Picture pinned at the top on iPhone
The system SHALL show on iPhone, and on iPad in a narrow Split View, the picture across the top with the now-playing line, the group button and the channel list below and the tab bar at the bottom, and switching layouts SHALL NOT interrupt the channel.

#### Scenario: The Live tab on iPhone
- **GIVEN** an iPhone, or an iPad in a narrow Split View
- **WHEN** the user opens the Live tab
- **THEN** the picture spans the width at the top, with the now-playing line, the group button and the channel list below it and the tab bar at the bottom
- **AND** the group button runs from the leading edge to the profile button at the row's trailing end, and shows the open group's name, its channel count and a chevron

#### Scenario: Switching between narrow and wide
- **GIVEN** a channel is playing
- **WHEN** the layout switches between narrow and wide
- **THEN** the channel is not interrupted

#### Scenario: Large text
- **GIVEN** the user has a large text size
- **WHEN** Live is shown on iPhone
- **THEN** the rows grow and the picture keeps its shape

#### Scenario: The group button sits under the line
- **GIVEN** an iPhone, with or without a channel playing
- **WHEN** Live is shown
- **THEN** the group button sits right under the now-playing line, or under the picture area when nothing plays, and the channel list starts right under the button

### Requirement: Tap the open tab to go back to the top
The system SHALL scroll Live's channel list, the Guide's channels, Movies, Series and Search back to their top when the user taps the tab that is already open in the tab bar on iPhone or in a narrow iPad window. On Movies and Series, a movie or series page open from the tab's rows SHALL close on the same tap. The channel playing SHALL not change.

#### Scenario: Movies scrolled down
- **GIVEN** Movies is open on iPhone and scrolled down past the banner
- **WHEN** the user taps Movies in the tab bar
- **THEN** the rows scroll back to the top with the banner showing

#### Scenario: Live's list scrolled down
- **GIVEN** Live is open on iPhone with a channel playing and the list scrolled down
- **WHEN** the user taps Live in the tab bar
- **THEN** the list scrolls back to its first channel and the channel keeps playing

#### Scenario: A page open on Movies
- **GIVEN** a movie's page opened from the Movies rows on iPhone, or a series page opened from the Series rows
- **WHEN** the user taps Movies, or Series, in the tab bar
- **THEN** the page closes and the rows show from the top

#### Scenario: Another tab
- **GIVEN** Live is open on iPhone
- **WHEN** the user taps Movies
- **THEN** Movies opens where it was left, without scrolling
