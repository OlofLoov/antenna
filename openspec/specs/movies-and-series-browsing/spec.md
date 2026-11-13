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
The system SHALL show the newest title in the banner with its name, category, year, length and description, move through the four newest by itself while the user is not interacting with it, and let the user page it by hand. The banner's art SHALL fill the banner and stay inside it, whatever the shape of the picture.

#### Scenario: Titles with dates added
- **GIVEN** the provider's movies have dates they were added
- **WHEN** the user opens Movies
- **THEN** the banner shows the newest title with its name, category, year, length and description
- **AND** it moves through the four newest by itself while the user is not interacting with it
- **AND** the user can page it by hand

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the banner shows
- **THEN** it never moves by itself
- **AND** paging wraps at either end

#### Scenario: Two Xtream sources
- **GIVEN** the user has two Xtream sources
- **WHEN** the banner fills
- **THEN** it picks titles from both

#### Scenario: A title with only a poster
- **GIVEN** a title in the banner has a poster and no backdrop
- **WHEN** the banner shows it, or pages to or from it
- **THEN** the poster fills the banner and nothing of it shows above, below or beside the banner
- **AND** the banner's name, details and buttons stay where the board puts them

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
- **THEN** it says "No episodes available", or "Could not load episodes" with Retry

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
The system SHALL show titles from sources that loaded under a dismissible banner naming each failed source, and SHALL show "Could not load movies" with a Retry for only the failed sources when no source has titles.

#### Scenario: Some sources failed
- **GIVEN** at least one Xtream source failed to load and others have titles
- **WHEN** the user opens the section
- **THEN** titles from the other sources still show under a banner naming each failed source, which the user can dismiss

#### Scenario: No source has titles
- **GIVEN** no source has titles because they failed
- **WHEN** the user opens the section
- **THEN** "Could not load movies" with a Retry that asks only the failed sources again takes their place
- **AND** offline, the message says so

#### Scenario: Every source answered with nothing
- **GIVEN** every source answered with no titles
- **WHEN** the user opens the section
- **THEN** it says "Nothing here yet" with a line per source

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
