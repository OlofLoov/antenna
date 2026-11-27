# title-detail-and-episode-picker Specification

## Purpose
Gives people who watch their provider's movies and series a detail page that says what a title is about and lets them play, resume or save it, and for a series pick a season and episode and see which episodes they have watched.

## Requirements

### Requirement: Open a movie's page
The system SHALL open a movie's page at once from its poster outside Continue watching and Recently watched, from a search result or a person's page, and from More info on the banner or in a poster's menu, showing what it already knows while it asks the provider for the details once. When the banner, the Apple TV preview or an earlier page already has the details, the page SHALL show them at once without asking.

#### Scenario: Select a movie
- **GIVEN** a movie as a poster in a row or grid, in search results or on a person's page
- **WHEN** the user selects the poster
- **THEN** the movie's page opens at once with its name, "Movie · <category>" and its poster, shows the details the section already has or shows that the rest is loading, asks the provider at most once, and nothing starts playing

#### Scenario: More info on a movie
- **GIVEN** a movie on the Movies banner, in Continue watching or in Recently watched
- **WHEN** the user picks More info on the banner or in the card's menu
- **THEN** the movie's page opens at once, as from its poster

#### Scenario: Leave before the details arrive
- **GIVEN** a page whose details are still loading
- **WHEN** the user leaves it
- **THEN** the page stops waiting and a late reply changes nothing on it
- **AND** the reply is kept, so opening the page again shows the details without asking again

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
The system SHALL show a title's backdrop, year, length or seasons, genre, rating, badges, description, cast and director once the details arrive, and SHALL leave out any field the provider does not give. Every word of the description, cast and director SHALL be reachable: on Apple TV through More, which opens them on a page of their own, and elsewhere by expanding in place. The backdrop SHALL keep its proportions and show whole, or lose at most 8% at two edges to fill its area.

#### Scenario: A movie with full details
- **GIVEN** a movie whose details include year 2024, a length of 2 h 08 min, genre Thriller, rating 7.4, age rating 15, a "2160p" name, a description, cast and a director
- **WHEN** the details arrive
- **THEN** the page shows the backdrop, year, length, genre, rating and the age and 4K badges, the description cut to a few lines with More, and the cast and director

#### Scenario: More on Apple TV
- **GIVEN** a title page on Apple TV whose description runs past its lines
- **WHEN** the viewer moves up to More and presses select
- **THEN** a full-screen page shows the name, the details line, the whole description, the cast and the director over the blurred title page
- **AND** swiping down and up scrolls a text longer than the screen
- **AND** Menu closes it and focus is back on More

#### Scenario: More on iPhone, iPad and Mac
- **GIVEN** a title page whose description runs past its lines
- **WHEN** the user taps or clicks More
- **THEN** the description shows in full in place, and so do the cast and director

#### Scenario: No backdrop
- **GIVEN** a title whose provider gives a poster but no backdrop
- **WHEN** its page shows
- **THEN** the poster sits on black where the backdrop would be

#### Scenario: A 16:9 backdrop on iPhone
- **GIVEN** a title whose backdrop is 16:9
- **WHEN** its page shows on an iPhone
- **THEN** the backdrop spans the screen's width at 16:9 directly under the status bar, with nothing of it cut or covered
- **AND** a blurred copy of it fills the status bar band and fades into the page below the picture

#### Scenario: A 16:9 backdrop on iPad and Mac
- **GIVEN** a title whose backdrop is 16:9
- **WHEN** its page shows on an iPad or a Mac
- **THEN** the card is 16:9 for its width, between 380 and 560 points tall, and the backdrop shows whole
- **AND** in a window wide enough to hold the card at 560 the backdrop sits against the right, fading into its blurred copy under the copy

#### Scenario: A series on Apple TV
- **GIVEN** a series whose backdrop is 16:9
- **WHEN** its page shows on Apple TV, with the backdrop in the band above the episodes
- **THEN** the backdrop shows whole at the right of the band over a blurred copy of itself, never cut to a strip of its middle

#### Scenario: A poster sent as the backdrop
- **GIVEN** a title whose provider's backdrop is a tall picture, such as its poster
- **WHEN** its page shows
- **THEN** the whole picture shows with rounded corners over a blurred copy of itself, never enlarged to a strip of its middle
- **AND** on iPhone it sits in the middle of the 16:9 area, nearly its full height; on iPad, Mac and Apple TV it sits at the right

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

#### Scenario: Scores replace the provider's rating
- **GIVEN** a title with a provider rating of 7.4 that is matched and has at least one score from another site
- **WHEN** the page shows
- **THEN** the details line leaves out the provider's rating and the score row shows instead
- **AND** with no score from another site, the provider's rating stays in the details line

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
The system SHALL add a title to My list or remove it when the user presses My list, keeping the page and the banner in agreement and the list matching the button however fast the user presses. The button SHALL say what it does in words, "Add to My list" or "Remove from My list", with no glyph, on every platform.

#### Scenario: Add and remove
- **GIVEN** a title not in My list
- **WHEN** the user presses My list on its page, and presses it again
- **THEN** the first press adds it, the button reads "Remove from My list", and the banner's My list button agrees
- **AND** the second removes it and both read "Add to My list" again
- **AND** however fast the user presses, the list ends up matching the button

#### Scenario: Words, not a plus
- **WHEN** a title's page shows on iPhone, iPad, Mac or Apple TV
- **THEN** My list reads "Add to My list" in the same style as Trailer beside it, with no plus or check

#### Scenario: iPhone
- **WHEN** a title's page shows on iPhone
- **THEN** Play spans the width, and My list and Trailer sit under it with their words in full

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on and the title is in My list
- **WHEN** it reads the button
- **THEN** it says "Remove from My list, On My list"

### Requirement: Trailer
The system SHALL offer a Trailer button when the provider gives a trailer link, opening it outside the app on iPhone, iPad and Mac, and on Apple TV only when the link is a video file or stream the app can play, playing it in the app.

#### Scenario: A trailer link
- **GIVEN** the provider gives a trailer link for the title, on iPhone, iPad or Mac
- **WHEN** the user presses Trailer
- **THEN** the link opens outside the app

#### Scenario: A playable trailer on Apple TV
- **GIVEN** the provider's trailer link on Apple TV points at a video file or an HLS stream
- **WHEN** the user presses Trailer
- **THEN** the trailer plays full screen in the app, and Menu or its end goes back to the title page without saving a place in Continue watching

#### Scenario: No Trailer button
- **WHEN** the title has no link, or on Apple TV the link is a web page such as YouTube
- **THEN** there is no Trailer button

### Requirement: When details or episodes do not load
The system SHALL say which part of the page failed to load, with Try again, and SHALL still let a movie whose details failed be played and added to My list. Each failure SHALL be kept in the device log with a reason, such as the server's status, the network error code or where the answer stopped making sense, and never with an address, login or the answer itself.

#### Scenario: The provider fails
- **GIVEN** the provider fails to answer for the details or the episodes
- **WHEN** the page is showing
- **THEN** the part that failed reads "Could not load details" or "Could not load episodes", or the offline message when that is the cause, with Try again
- **AND** a movie whose details failed can still be played and added to My list

#### Scenario: Offline with a provider login
- **GIVEN** the device has no network
- **WHEN** a series page from a provider with a login asks for its episodes
- **THEN** the page shows the offline message, not "Could not load episodes"

#### Scenario: The reason is kept
- **GIVEN** the provider answers a series with an error status or an answer that cannot be read
- **WHEN** the page shows "Could not load episodes"
- **THEN** the device log says why, with no address, login or answer text in it

#### Scenario: A login not on this device
- **GIVEN** a title whose source login has not reached this device
- **WHEN** the page shows or the user presses Play
- **THEN** it shows "<source>: waiting for its login to sync from iCloud" with Try again, and Play plays nothing

#### Scenario: A slow provider
- **WHEN** the provider is slow
- **THEN** the name and poster show at once, and only the details and episodes wait

### Requirement: Pick a season
The system SHALL group a series' episodes into seasons, specials and other episodes, open on the season holding the episode Play would start, and show only the picked season's episodes in order.

#### Scenario: Pick Season 3
- **GIVEN** a series with seasons 1, 2 and 3, specials (season 0) and episodes with no season
- **WHEN** the user opens its page and picks Season 3 by tap, click, the arrow keys, or on Apple TV by resting on it
- **THEN** the picker lists "Season 1", "Season 2", "Season 3", "Specials" and "Other", opens on the season that holds the episode Play would start, and after the pick shows only Season 3's episodes in order with its episode count

#### Scenario: Many seasons
- **GIVEN** a series with fifteen seasons
- **WHEN** its page shows on iPhone, iPad, Mac or Apple TV
- **THEN** the season chips that do not fit scroll within their row, and none of them covers the episode count at the end of the row

#### Scenario: One group only
- **GIVEN** a series whose episodes form one group
- **WHEN** its page shows
- **THEN** there is no season picker

### Requirement: What each episode shows
The system SHALL show each episode with a picture, number, title, length and one line of description, marking finished episodes Watched and showing progress for ones in progress. An episode with a description SHALL offer Description in its menu, which shows the whole description.

#### Scenario: Episodes in every state
- **GIVEN** episodes watched to the end, part-way, barely or not at all, some without a picture, title or description
- **WHEN** the user looks at the episode list
- **THEN** each row shows a picture, or a tile with the episode number, the number, the title, the length and one line of description
- **AND** a finished episode shows a full bar and "Watched" instead of its length, one in progress shows its bar and the minutes left, and one barely started looks unwatched
- **AND** missing fields are left out

#### Scenario: Reading an episode's description
- **GIVEN** an episode whose description is longer than its line
- **WHEN** the user long-presses its row on Apple TV, or opens its menu on iPhone, iPad or Mac, and picks Description
- **THEN** the episode's number, title, length and whole description show on a page of their own that Menu, Done or Escape closes
- **AND** an episode without a description has no Description item

#### Scenario: No episodes or unreadable ones
- **GIVEN** a series with no episodes, or with episodes the provider listed but could not describe
- **WHEN** the page shows
- **THEN** a series with none says "No episodes available", and unreadable ones are counted under the list as "<n> episodes could not be read from the provider's list."

#### Scenario: Watched outside Antuna
- **GIVEN** an episode watched outside Antuna
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
The system SHALL play a chosen episode from where the user stopped, save its progress as it plays, and return to the page with the episode that played last in view and everything up to date, both when the user leaves playback and when the episode ends with no next episode to play.

#### Scenario: Watch an episode
- **GIVEN** the episode list
- **WHEN** the user selects an episode, or presses Play for the up-next one
- **THEN** it plays from where they stopped and its progress is saved as it plays
- **AND** when it ends or they leave playback they are back on the page with that episode's season showing, the episode in view, and its bar, the UP NEXT mark and the Play button up to date

#### Scenario: Several episodes in a row
- **GIVEN** the user played an episode from the page and the next ones started from Up next
- **WHEN** they leave playback, or the last one ends with no next episode
- **THEN** they are back on the page with the season of the episode that played last showing and that episode in view

### Requirement: Back to where you were
The system SHALL return the user from a title page to the section they came from, at the same scroll position and without reloading, with the starting poster or button in view. On Apple TV, leaving a title played from a Continue watching card or from Recently watched SHALL put the highlight back on that card.

#### Scenario: Go back
- **GIVEN** the page was opened from a movie or series poster deep in a row, from the banner, or from search results
- **WHEN** the user goes back with Menu (Apple TV), the back button or Escape (iPad, Mac), or the back button or an edge swipe (iPhone)
- **THEN** the section shows the same rows at the same scroll position without reloading, with the poster or button they started from focused on Apple TV and in view elsewhere
- **AND** from search, Search shows with the query still there

#### Scenario: Back from a title played from a poster on Apple TV
- **GIVEN** the viewer played a title from a Continue watching card, or a movie from Recently watched
- **WHEN** they leave playback with Menu, or it ends
- **THEN** the rows show at the same place with that card or poster focused, not the banner

### Requirement: The page shows in one go
The system SHALL keep a title page hidden while its details load and SHALL show it whole, with a short fade, once they arrive or fail. A load longer than 0.3 seconds SHALL show the Antuna mark tuning in the middle of the screen until then, and Got it before the page. Back SHALL stay reachable meanwhile.

#### Scenario: A slow load
- **GIVEN** a series whose provider takes half a second to answer
- **WHEN** the user opens its page
- **THEN** the mark tunes on the ground, with no name, details, buttons or episodes
- **AND** when the details arrive the mark plays Got it and the whole page fades in, episodes included

#### Scenario: A fast load
- **GIVEN** a title whose details arrive within 0.3 seconds
- **WHEN** the user opens its page
- **THEN** the page fades in whole and the mark never shows

#### Scenario: Details already known
- **GIVEN** a title whose details the banner, the expanded card or an earlier visit already asked for
- **WHEN** the user opens its page
- **THEN** the page shows at once

#### Scenario: The details fail
- **GIVEN** a title whose provider fails to answer
- **WHEN** the load ends
- **THEN** the page shows with what is known and "Could not load details" with Try again, as before

#### Scenario: Going back while it loads
- **GIVEN** a page whose details are still loading
- **WHEN** the user taps Back on iPhone or iPad, swipes from the edge, or presses Menu on Apple TV
- **THEN** the page closes

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion on
- **WHEN** a page loads slowly
- **THEN** the mark shows still or fades as it does elsewhere, and the page still waits for its details

### Requirement: Scores from other sites
The system SHALL show a matched title's scores from other sites on its page, below the Play and My list buttons, each with the site's name, on iPhone, iPad, Mac and Apple TV, and SHALL leave out a site that has no score for the title.

#### Scenario: A matched movie
- **GIVEN** a movie matched to the movie database, with a TMDB user score of 74%
- **WHEN** its page shows
- **THEN** "TMDB 74%" shows below the buttons

#### Scenario: Scores from several sites
- **GIVEN** a matched movie with scores from more than one site
- **WHEN** its page shows
- **THEN** each score shows with its site's name, in a fixed order, and a site with no score for the title is left out

#### Scenario: No match or lookups off
- **GIVEN** a title with no match, or lookups turned off
- **WHEN** its page shows
- **THEN** no score row shows and the page keeps its layout

#### Scenario: Apple TV focus
- **GIVEN** a title page on Apple TV with a score row
- **WHEN** the user moves focus
- **THEN** the scores take no focus, and focus moves between Play, My list, Trailer and More as before

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** it reads the page
- **THEN** it reads each score with its site after the details, for example "TMDB user score 74 percent"
