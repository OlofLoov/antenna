# movies-and-series-browsing Specification

## Purpose
Gives people whose Xtream subscription includes movies and series a streaming-app view of them on every device: a banner of new titles, rows by category, genre grids, a list for later, and resume where they stopped.

## Requirements

### Requirement: Movies and Series appear when your provider has them
The system SHALL list Movies and Series in the sidebar or tab bar whenever the user has at least one Xtream source, before its login arrives or it answers, with Series behind a switch inside Movies on iPhone, and SHALL list neither without an Xtream source.

#### Scenario: An Xtream source exists
- **GIVEN** the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet
- **WHEN** the user looks at the tab bar or sidebar
- **THEN** Movies and Series are listed, and on iPhone Movies has its Movies | Series switch

#### Scenario: No Xtream source
- **GIVEN** the user has no Xtream source
- **WHEN** the user looks at the tab bar or sidebar
- **THEN** neither Movies nor Series appears

### Requirement: New titles up front
The system SHALL show the newest title in the banner with its name, category, year, length and description, move through the four newest by itself while the user is not interacting with it, and let the user page it by hand. On Apple TV, focus resting on the banner's buttons SHALL not stop it; each move between the buttons SHALL start the wait again. The banner SHALL fade from one title to the next, and its art SHALL stay inside it, keep its proportions, and never be stretched.

#### Scenario: Titles with dates added
- **GIVEN** the provider's movies have dates they were added
- **WHEN** the user opens Movies
- **THEN** the banner shows the newest title with its name, category, year, length and description
- **AND** it moves through the four newest by itself while the user is not interacting with it
- **AND** the user can page it by hand

#### Scenario: Focus on the banner on Apple TV
- **GIVEN** Movies is open on Apple TV with focus on the banner's Play button
- **WHEN** eight seconds pass without a press
- **THEN** the banner fades to the next title and focus stays on the banner
- **AND** moving between Play, More info, Trailer and My list starts the eight seconds again

#### Scenario: Holding the banner on iPhone, iPad and Mac
- **GIVEN** a finger on the banner, or the pointer over it
- **WHEN** eight seconds pass
- **THEN** the banner stays on its title until the finger lifts or the pointer leaves

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the banner shows
- **THEN** it never moves by itself
- **AND** paging wraps at either end

#### Scenario: Two Xtream sources
- **GIVEN** the user has two Xtream sources
- **WHEN** the banner fills
- **THEN** it picks titles from both

#### Scenario: Moving to the next title
- **GIVEN** the banner shows a title
- **WHEN** it moves to the next title, by itself or by hand
- **THEN** the picture and the words fade across to the next title
- **AND** the banner never shows the empty placeholder between two titles that have pictures

#### Scenario: A title with a backdrop
- **GIVEN** the provider's info call for a title answers with a backdrop within 1.5 seconds
- **WHEN** the banner shows the title
- **THEN** the backdrop shows, without the poster showing first
- **AND** it fills the banner at its own proportions, cut at the edges rather than stretched

#### Scenario: A title with only a poster
- **GIVEN** a title in the banner has a poster and no backdrop
- **WHEN** the banner shows it, or pages to or from it
- **THEN** nothing of the poster shows above, below or beside the banner
- **AND** the banner's name, details and buttons stay where the board puts them
- **AND** on iPad, Mac and Apple TV the whole poster shows at the right of the banner over a blurred copy of itself
- **AND** on iPhone the poster fills the banner

#### Scenario: A poster sent as the backdrop
- **GIVEN** the provider's backdrop for a title is a tall picture, such as its poster
- **WHEN** the banner shows the title on iPad, Mac or Apple TV
- **THEN** the whole picture shows at the right of the banner over a blurred copy of itself, as for a title with only a poster
- **AND** it is never enlarged to a strip of its middle

### Requirement: Keep a list for later
The system SHALL add a title to My list from the banner button or the poster's menu, offer removal in both places once added, show it in the My list row latest first, and undo both on removal.

#### Scenario: Adding to My list
- **GIVEN** a title that is not in My list
- **WHEN** the user adds it with the banner's My list button or from the poster's menu
- **THEN** the button and menu offer to remove it instead
- **AND** the My list row appears or gains the title, latest additions first

#### Scenario: Removing from My list
- **GIVEN** a title in My list
- **WHEN** the user removes it
- **THEN** the button and menu offer to add it again, and the title leaves the row

#### Scenario: A change on another device
- **GIVEN** the section is open
- **WHEN** My list or a saved position changes on another device
- **THEN** the open section shows the change without reopening it

### Requirement: Continue watching
The system SHALL list movies and episodes stopped part-way through together in Continue watching, most recent first, with progress and what is left, drop finished movies, show "Next episode" for a series until none is left, and hide the row when nothing is in progress.

#### Scenario: Titles in progress
- **GIVEN** the user has stopped movies and episodes part-way through
- **WHEN** the user opens Movies or Series
- **THEN** Continue watching lists them together, most recent first
- **AND** each has a progress bar and the minutes left for a movie, or the season and episode for a series

#### Scenario: Finished titles
- **GIVEN** a movie was watched to the end, or a series episode was finished
- **WHEN** Continue watching shows
- **THEN** the movie leaves the row
- **AND** the series shows "Next episode" until no unwatched episode is left

#### Scenario: Nothing in progress
- **GIVEN** nothing is in progress
- **WHEN** the user opens Movies or Series
- **THEN** the Continue watching row is not shown

#### Scenario: A title that is not loaded
- **GIVEN** a saved position or list entry for a title that is not loaded
- **WHEN** the rows show
- **THEN** it is not shown or counted, and it is kept

### Requirement: Rows in a predictable order
The system SHALL show, after Continue watching and My list, Recently added newest first and one row per category that has titles in the provider's order, each headed with its name and number of titles.

#### Scenario: Provider categories
- **GIVEN** the provider's movies and categories
- **WHEN** the user opens Movies
- **THEN** after Continue watching and My list come Recently added, newest first, and one row per category that has titles, in the provider's order
- **AND** each row is headed with its name and number of titles

#### Scenario: Two sources with the same category
- **GIVEN** two Xtream sources share a category name
- **WHEN** the rows show
- **THEN** their titles merge into one row

#### Scenario: Thousands of categories
- **GIVEN** the provider has thousands of categories
- **WHEN** the user scrolls
- **THEN** rows load as they scroll into view and only visible rows fetch posters

#### Scenario: Missing or broken poster
- **GIVEN** a title's poster is missing or broken
- **WHEN** its poster shows
- **THEN** the title's name shows on a plain tile, never an empty frame

#### Scenario: Entries without a name or id
- **GIVEN** the provider lists entries without a name or id
- **WHEN** the rows fill
- **THEN** those entries are skipped

#### Scenario: VoiceOver reads a poster
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a poster
- **THEN** it is read as title, year and, when in progress, the minutes left

### Requirement: Browse a genre or sort the lot
The system SHALL replace the rows with a poster grid and count when the user picks a genre, My list, All movies, See all on Continue watching, or a sort on iPad and Mac, opening it as its own screen on Apple TV, and SHALL bring the rows back on All, the section or Recently added.

#### Scenario: Picking a genre
- **GIVEN** the rows are showing
- **WHEN** the user picks a genre, My list, All movies, or See all on Continue watching, or on iPad and Mac picks Title or Year in the sort menu
- **THEN** a poster grid of those titles in the chosen order takes the rows' place with the count above it

#### Scenario: On Apple TV
- **GIVEN** the user is on Apple TV
- **WHEN** they open a grid
- **THEN** it opens as its own screen that Menu closes

#### Scenario: Back to the rows
- **GIVEN** a grid is showing on iPhone, iPad or Mac
- **WHEN** the user picks All on iPhone, the section in the sidebar on iPad and Mac, or "Recently added" in the sort menu
- **THEN** the rows come back

### Requirement: Play a series from the next episode
The system SHALL show that a series poster is working while its episode list loads and then start the episode Play on its title page starts: the one last in progress, else the first unwatched one after the last one finished. It SHALL say when a series has no episodes or its list fails.

#### Scenario: Selecting a series
- **GIVEN** a series poster
- **WHEN** the user selects it
- **THEN** the poster shows it is working while the episode list loads
- **AND** the episode last in progress resumes, or with none in progress, the first unwatched episode after the last one finished starts

#### Scenario: No episodes or a failed list
- **GIVEN** a series has no episodes, or its episode list fails to load
- **WHEN** the user selects it
- **THEN** it says "No episodes available", or "Could not load episodes" with Try again

### Requirement: Resume where you left off
The system SHALL start a movie the user stopped part-way through within five seconds of where they stopped, from any place it can be played, and SHALL start a movie barely started or already finished from the beginning.

#### Scenario: Resuming a movie
- **GIVEN** a movie the user stopped part-way through
- **WHEN** the user plays it from the banner, a poster, My list or a search result
- **THEN** it starts within five seconds of where they stopped

#### Scenario: Barely started or finished
- **GIVEN** a movie barely started or already finished
- **WHEN** the user plays it
- **THEN** it starts from the beginning

#### Scenario: Leaving a movie
- **GIVEN** a movie is playing
- **WHEN** the user leaves it
- **THEN** they return to the poster that started it
- **AND** the last live channel starts again the next time they open Live

### Requirement: When sources fail
The system SHALL show titles from sources that loaded under a dismissible banner naming each failed source, and SHALL show "Could not load movies" with Try again for only the failed sources when no source has titles.

#### Scenario: Some sources failed
- **GIVEN** at least one Xtream source failed to load and others have titles
- **WHEN** the user opens the section
- **THEN** titles from the other sources still show under a banner naming each failed source, which the user can dismiss

#### Scenario: No source has titles
- **GIVEN** no source has titles because they failed
- **WHEN** the user opens the section
- **THEN** "Could not load movies" with Try again that asks only the failed sources again takes their place
- **AND** offline, the message says so

#### Scenario: Every source answered with nothing
- **GIVEN** every source answered with no titles
- **WHEN** the user opens the section
- **THEN** it says "Nothing here yet" with a line per source and Open Settings

#### Scenario: A login not yet arrived
- **GIVEN** a source's login has not arrived from iCloud
- **WHEN** the user opens the section
- **THEN** the source is named as waiting for it
- **AND** it is tried again when the section opens and when the app returns to the foreground

### Requirement: Series work the same way
The system SHALL apply every Movies requirement to Series, ordering series by when each last changed and showing the number of seasons in the banner instead of a length.

#### Scenario: Opening Series
- **GIVEN** the provider has series
- **WHEN** the user opens Series
- **THEN** the banner, rows, grids, My list and Continue watching behave as in Movies, with series ordered by when each series last changed
- **AND** the banner shows the number of seasons instead of a length

#### Scenario: A title that is both
- **GIVEN** the provider lists a title as both a movie and a series
- **WHEN** the sections show
- **THEN** it shows once in each section

### Requirement: Your place is saved as you watch
The system SHALL save the position of a playing movie or episode every 30 seconds and when the user pauses or stops, skips or scrubs, the app goes to the background, or the title ends, and Continue watching and Resume SHALL show it from then on.

#### Scenario: Saving the position
- **GIVEN** a movie or episode is playing
- **WHEN** 30 seconds pass, or the user pauses or stops, the app goes to the background, or the title ends
- **THEN** the position is saved
- **AND** Continue watching and Resume show it from then on

#### Scenario: Closing right after a skip
- **GIVEN** the user skipped or scrubbed a movie to a new point
- **WHEN** they close it before the picture at the new point shows
- **THEN** Resume starts from the point they moved to

### Requirement: Search from the section
The system SHALL open Search set to movies or series with the field ready and any typed text carried over when the user taps the search button on iPhone or types in the toolbar field on iPad and Mac, and Apple TV SHALL use its Search tab instead.

#### Scenario: Search on iPhone, iPad or Mac
- **GIVEN** the Movies or Series section on iPhone, iPad or Mac
- **WHEN** the user taps the search button on iPhone, or types in the toolbar's search field on iPad and Mac
- **THEN** Search opens set to movies or series with the field ready for typing and any text already typed carried over

#### Scenario: Apple TV
- **GIVEN** the Movies or Series section on Apple TV
- **WHEN** the user looks for a search button
- **THEN** there is none, and the Search tab is the way to search

### Requirement: Rating and trailer on the banner
The system SHALL show the provider's rating in the banner's facts line, written as a star and the number out of ten with one decimal, and SHALL offer a Trailer button on the banner whenever the title's page would offer one, opening the trailer the same way the page does.

#### Scenario: A rated movie
- **GIVEN** the banner shows a movie the provider rates 7.4, from 2024, 2 h 08 min long
- **WHEN** the banner shows it
- **THEN** the facts line reads "2024 · 2 h 08 min · ★ 7.4", followed by its badges

#### Scenario: Rating before the details arrive
- **GIVEN** the provider's list gives a title a rating and its info call has not answered
- **WHEN** the banner shows the title
- **THEN** the rating shows at once, and the year and length join it when the info call answers

#### Scenario: No rating
- **GIVEN** the provider sends no rating, or a rating of 0
- **WHEN** the banner shows the title
- **THEN** the facts line has no star and no placeholder

#### Scenario: VoiceOver reads the rating
- **GIVEN** VoiceOver is on
- **WHEN** it reads the banner's facts line for a title rated 7.4
- **THEN** it says "rated 7.4 out of 10"

#### Scenario: A trailer on iPhone, iPad or Mac
- **GIVEN** the provider gives the banner title a trailer link, a YouTube page included
- **WHEN** the user presses Trailer on the banner on iPhone, iPad or Mac
- **THEN** the link opens outside the app

#### Scenario: A playable trailer on Apple TV
- **GIVEN** the banner title's trailer link points at a video file or an HLS stream
- **WHEN** the viewer selects Trailer on the banner on Apple TV
- **THEN** the trailer plays full screen, and Menu or its end goes back to the banner with Trailer highlighted, without saving a place in Continue watching

#### Scenario: A YouTube trailer on Apple TV
- **GIVEN** the banner title's trailer link is a YouTube page
- **WHEN** the banner shows it on Apple TV
- **THEN** there is no Trailer button, as on the title page

#### Scenario: Paging past a title with a trailer
- **GIVEN** the banner shows a title with a Trailer button and the next title has none
- **WHEN** the viewer pages to the next title from My list on Apple TV
- **THEN** the Trailer button goes, My list keeps the highlight, and paging right from My list still works

#### Scenario: The trailer link arrives late
- **GIVEN** the highlight is on My list and the title's info call has not answered
- **WHEN** the answer arrives with a trailer link
- **THEN** Trailer appears before My list and the highlight stays on My list

#### Scenario: iPhone
- **WHEN** the banner shows a title with a trailer on iPhone
- **THEN** Trailer is a button with the trailer glyph and the spoken label "Trailer", between Info and My list, and the four buttons fit the screen width

### Requirement: Preview of the focused title on Apple TV
On Apple TV the system SHALL show, at the top of Movies and Series while the highlight is in a row, a preview of the title the highlight rests on: its picture, name, category, facts and up to three lines of its plot, with the focused row just below. The preview SHALL change only after the highlight has stayed on a poster for 0.8 seconds, and SHALL fade from one title to the next. iPhone, iPad and Mac SHALL show no preview.

#### Scenario: Resting on a poster
- **GIVEN** the viewer is on Movies on Apple TV with the highlight on the banner
- **WHEN** they move down to a poster in Recently added and stay on it
- **THEN** the banner scrolls away, the row moves up under the top of the screen, and 0.8 seconds later the top shows that title's backdrop, name, category, year, length and plot

#### Scenario: Moving quickly along a row
- **GIVEN** the preview shows a title
- **WHEN** the viewer swipes across ten posters without stopping and stops on the eleventh
- **THEN** the preview keeps the first title until the eleventh has been focused for 0.8 seconds, then fades to it
- **AND** the provider is not asked about the ten posters passed on the way

#### Scenario: Moving to another row
- **WHEN** the viewer moves down from one row to the next
- **THEN** the new row takes the place just under the preview, the row above leaves the screen, and the preview changes once the highlight rests

#### Scenario: Details still loading
- **GIVEN** the provider has not answered for the title the highlight rests on
- **WHEN** the preview changes to it
- **THEN** the name and category show at once, the previous picture stays until the new one is ready or 1.5 seconds pass, and the facts and plot fade in when the provider answers

#### Scenario: A title with only a poster
- **GIVEN** the provider sends no backdrop for the focused title
- **WHEN** the preview shows it
- **THEN** the whole poster shows at the right of the preview over a blurred copy of itself, as on the banner

#### Scenario: The details fail or the device is offline
- **GIVEN** the provider fails to answer for the focused title, or the Apple TV is offline
- **WHEN** the preview shows it
- **THEN** it shows the name, the category and the poster, and no error
- **AND** the poster can still be played or opened

#### Scenario: A playlist title
- **GIVEN** the focused title comes from an M3U playlist
- **WHEN** the preview shows it
- **THEN** it shows the name, the group and the logo or poster, and the provider is not asked

#### Scenario: Continue watching
- **GIVEN** the highlight rests on an episode in Continue watching
- **WHEN** the preview shows it
- **THEN** it shows the series' backdrop, name and plot

#### Scenario: Back to the banner
- **GIVEN** the preview shows a title
- **WHEN** the viewer moves up from the first row
- **THEN** the preview fades out, the banner scrolls back with the title it showed before, and the highlight is on Play

#### Scenario: Menu from a row
- **GIVEN** the preview shows a title
- **WHEN** the viewer presses Menu
- **THEN** the rows scroll back to the top with the banner showing and the highlight moves to the tab bar

#### Scenario: Back from a title page
- **GIVEN** the viewer opened a title page from a poster with the preview showing
- **WHEN** they press Menu on the page
- **THEN** the same poster has the highlight and its preview shows at once, without waiting

#### Scenario: Genres row
- **WHEN** the viewer moves down to the Genres row
- **THEN** the preview keeps the last title it showed

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the highlight rests on a poster whose plot is known
- **THEN** VoiceOver reads the poster's name, year and minutes left as before, then the plot as its hint

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the highlight moves between rows
- **THEN** the rows move into place without sliding, and the preview still fades between titles

#### Scenario: iPad
- **WHEN** the viewer moves the pointer over posters on iPad or Mac
- **THEN** no preview shows and the banner does not change

### Requirement: Title details are asked once per title
The system SHALL ask the provider for a title's details at most once per launch for the banner and the preview together, one preview request at a time, and SHALL use that answer when the title's page opens. Retry on a page SHALL ask again.

#### Scenario: Banner, preview and page
- **GIVEN** a title was shown in the banner, so its details were asked for
- **WHEN** the viewer rests on its poster and then opens its page
- **THEN** the provider is asked once in all, and the page shows the details without loading

#### Scenario: Resting on several posters
- **GIVEN** the provider answers slowly
- **WHEN** the viewer rests on three posters in turn before the first answer arrives
- **THEN** the first request finishes, the second poster is skipped, and the third is asked about next

#### Scenario: Retry on a page
- **GIVEN** a title's details failed for its preview
- **WHEN** the viewer opens its page and presses Retry
- **THEN** the provider is asked again

### Requirement: Browsing stays responsive
The system SHALL keep Movies and Series responding to the remote, touch and pointer while a library of 50 000 movies and 10 000 series loads, while its rows redraw, and while a grid of all of it opens. Building the rows and the banner SHALL happen away from the screen, and redrawing the rows or a grid SHALL not walk every title.

#### Scenario: A large library loads
- **GIVEN** a source with 50 000 movies
- **WHEN** its list arrives
- **THEN** the rows and the banner appear together without the screen freezing while they are built

#### Scenario: Progress saved while browsing
- **GIVEN** Movies is open on a library of 50 000 movies with titles in Continue watching
- **WHEN** a position is saved, on this device or from another one
- **THEN** Continue watching and Recently watched update without the screen pausing

#### Scenario: All movies
- **GIVEN** a library of 50 000 movies
- **WHEN** the user opens All movies, or a genre, and moves through its grid
- **THEN** the grid is sorted once when it opens, not again as focus moves

#### Scenario: A playlist series the kept load does not have
- **GIVEN** a playlist source whose kept load lacks a series the banner or a page asks about
- **WHEN** several such series are asked about within five minutes
- **THEN** the playlist is fetched again at most once in those five minutes
