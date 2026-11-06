# Spec Delta

## Purpose

Gives people who watch their provider's movies and series a detail page that says what a title is about and lets them play, resume or save it, and for a series pick a season and episode and see which episodes they have watched.

## ADDED Requirements

### Requirement: Open a movie's page
The system SHALL open a movie's page at once from More info, showing what it already knows while it asks the provider for the details once.

#### Scenario: More info on a movie
- **GIVEN** a movie on the Movies banner and as a poster
- **WHEN** the user picks More info on the banner or in the poster's menu
- **THEN** the movie's page opens at once with its name, "Movie · <category>" and its poster, shows that the rest is loading, and asks the provider for the details once

#### Scenario: Leave before the details arrive
- **GIVEN** a page whose details are still loading
- **WHEN** the user leaves it
- **THEN** the request is canceled, a late reply changes nothing, and opening the page again asks again

#### Scenario: The source is deleted
- **GIVEN** a title's page open
- **WHEN** its source is deleted
- **THEN** the page closes and the section shows again

#### Scenario: The same title on two sources
- **GIVEN** two sources with the same title
- **WHEN** the user opens each poster
- **THEN** each opens its own page and keeps its own progress

### Requirement: Open a series' page
The system SHALL open a series' page at once from a series poster outside Continue watching, the Series banner or a search result, without starting playback.

#### Scenario: Select a series
- **GIVEN** a series poster outside Continue watching, the Series banner, or a series in search results
- **WHEN** the user selects the poster or result, or picks More info on the banner
- **THEN** the series' page opens at once with its name, "Series · <category>" and poster, the episode list shows it is loading, Play waits until the episodes arrive, and nothing starts playing

#### Scenario: A series in Continue watching
- **GIVEN** a series in Continue watching
- **WHEN** the user selects it
- **THEN** it plays straight away, picking its episode by the same rule as Play on the page

### Requirement: What the title is about
The system SHALL show a title's backdrop, year, length or seasons, genre, rating, badges, description, cast and director once the details arrive, and SHALL leave out any field the provider does not give.

#### Scenario: A movie with full details
- **GIVEN** a movie whose details include year 2024, a length of 2 h 08 min, genre Thriller, rating 7.4, age rating 15, a "2160p" name, a description, cast and a director
- **WHEN** the details arrive
- **THEN** the backdrop replaces the poster and the page shows year, length, genre, rating and the age and 4K badges, the description cut to a few lines with More, and the cast and director

#### Scenario: Missing fields
- **GIVEN** a title whose provider leaves fields out
- **WHEN** the details arrive
- **THEN** a missing field is simply missing, never "Unknown"

#### Scenario: A series
- **WHEN** a series' details arrive
- **THEN** it shows its number of seasons instead of a length, counted from what the episodes say when they disagree with the provider's season count

#### Scenario: Large text and VoiceOver
- **GIVEN** a large text size and VoiceOver on
- **WHEN** the page shows
- **THEN** the details line wraps, and VoiceOver reads the name, the details, then the description

### Requirement: Play or Resume a movie
The system SHALL offer Resume with progress for a movie stopped part-way through and Play from the start otherwise, and SHALL return to the page with the button up to date when playback ends.

#### Scenario: Resume and Play
- **GIVEN** a movie the user stopped part-way through, and one they have not started or have finished
- **WHEN** they open its page and press the button
- **THEN** the first reads "Resume" with a progress bar and the minutes left, and plays from where they stopped
- **AND** the second reads "Play" and plays from the start
- **AND** when the movie ends or the user leaves playback, they are back on the page with the button and bar up to date

#### Scenario: A change from another device
- **GIVEN** a title's page open
- **WHEN** a new position or My list change arrives from another device
- **THEN** the button, the bars and the UP NEXT mark update

### Requirement: My list from the page
The system SHALL add a title to My list or remove it when the user presses My list, keeping the page and the banner in agreement and the list matching the button however fast the user presses.

#### Scenario: Add and remove
- **GIVEN** a title not in My list
- **WHEN** the user presses My list on its page, and presses it again
- **THEN** the first press adds it, the button shows a check and "Remove from my list", and the banner's My list button agrees
- **AND** the second removes it and both go back
- **AND** however fast the user presses, the list ends up matching the button

### Requirement: Trailer
The system SHALL offer a Trailer button on iPhone, iPad and Mac when the provider gives a trailer link, opening it outside the app, and SHALL offer none on Apple TV.

#### Scenario: A trailer link
- **GIVEN** the provider gives a trailer link for the title, on iPhone, iPad or Mac
- **WHEN** the user presses Trailer
- **THEN** the link opens outside the app

#### Scenario: No Trailer button
- **WHEN** the page shows on Apple TV, or the title has no link
- **THEN** there is no Trailer button

### Requirement: When details or episodes do not load
The system SHALL say which part of the page failed to load, with Retry, and SHALL still let a movie whose details failed be played and added to My list.

#### Scenario: The provider fails
- **GIVEN** the provider fails to answer for the details or the episodes
- **WHEN** the page is showing
- **THEN** the part that failed reads "Could not load details" or "Could not load episodes", or the offline message when that is the cause, with Retry
- **AND** a movie whose details failed can still be played and added to My list

#### Scenario: A login not on this device
- **GIVEN** a title whose source login has not reached this device
- **WHEN** the page shows or the user presses Play
- **THEN** it shows "<source>: waiting for its login to sync from iCloud" with Retry, and Play plays nothing

#### Scenario: A slow provider
- **WHEN** the provider is slow
- **THEN** the name and poster show at once, and only the details and episodes wait

### Requirement: Pick a season
The system SHALL group a series' episodes into seasons, specials and other episodes, open on the season holding the episode Play would start, and show only the picked season's episodes in order.

#### Scenario: Pick Season 3
- **GIVEN** a series with seasons 1, 2 and 3, specials (season 0) and episodes with no season
- **WHEN** the user opens its page and picks Season 3 by tap, click, the arrow keys, or on Apple TV by resting on it
- **THEN** the picker lists "Season 1", "Season 2", "Season 3", "Specials" and "Other", opens on the season that holds the episode Play would start, and after the pick shows only Season 3's episodes in order with its episode count

#### Scenario: One group only
- **GIVEN** a series whose episodes form one group
- **WHEN** its page shows
- **THEN** there is no season picker

### Requirement: What each episode shows
The system SHALL show each episode with a picture, number, title, length and one line of description, marking finished episodes Watched and showing progress for ones in progress.

#### Scenario: Episodes in every state
- **GIVEN** episodes watched to the end, part-way, barely or not at all, some without a picture, title or description
- **WHEN** the user looks at the episode list
- **THEN** each row shows a picture, or a tile with the episode number, the number, the title, the length and one line of description
- **AND** a finished episode shows a full bar and "Watched" instead of its length, one in progress shows its bar and the minutes left, and one barely started looks unwatched
- **AND** missing fields are left out

#### Scenario: No episodes or unreadable ones
- **GIVEN** a series with no episodes, or with episodes the provider listed but could not describe
- **WHEN** the page shows
- **THEN** a series with none says "No episodes available", and unreadable ones are counted under the list as "<n> episodes could not be read from the provider's list."

#### Scenario: Watched outside Antenna
- **GIVEN** an episode watched outside Antenna
- **WHEN** the list shows
- **THEN** it shows as unwatched until played here

#### Scenario: VoiceOver on an episode
- **GIVEN** VoiceOver on
- **WHEN** the user moves to an episode
- **THEN** it reads the number, title, length, minutes left or watched, and "up next" when marked

### Requirement: Play starts the right episode
The system SHALL make Play resume the episode last in progress, else play the first unwatched episode after the last one finished, and SHALL name that episode on the button and mark it UP NEXT.

#### Scenario: A partly watched series
- **GIVEN** a series the user has partly watched
- **WHEN** they open its page
- **THEN** Play resumes the episode they were last part-way through
- **AND** if none is in progress, it plays the first unwatched episode after the last one they finished, wrapping to the start when that was the last
- **AND** that episode carries the UP NEXT mark and the button names it, for example "Resume S2 E4"

#### Scenario: Nothing started or everything watched
- **WHEN** nothing in the series is started, or everything is watched
- **THEN** Play plays Season 1 Episode 1 rather than a special when nothing is started, and the first episode when everything is watched

#### Scenario: No episodes
- **GIVEN** a series with no episodes
- **WHEN** its page shows
- **THEN** Play is disabled

### Requirement: Play an episode and come back
The system SHALL play a chosen episode from where the user stopped, save its progress as it plays, and return to the page with that episode in view and everything up to date.

#### Scenario: Watch an episode
- **GIVEN** the episode list
- **WHEN** the user selects an episode, or presses Play for the up-next one
- **THEN** it plays from where they stopped and its progress is saved as it plays
- **AND** when it ends or they leave playback they are back on the page with that episode's season showing, the episode in view, and its bar, the UP NEXT mark and the Play button up to date

### Requirement: Back to where you were
The system SHALL return the user from a title page to the section they came from, at the same scroll position and without reloading, with the starting poster or button in view.

#### Scenario: Go back
- **GIVEN** the page was opened from a poster deep in a row, from the banner, or from search results
- **WHEN** the user goes back with Menu (Apple TV), the back button or Escape (iPad, Mac), or the back button or an edge swipe (iPhone)
- **THEN** the section shows the same rows at the same scroll position without reloading, with the poster or button they started from focused on Apple TV and in view elsewhere
- **AND** from search, Search shows with the query still there
