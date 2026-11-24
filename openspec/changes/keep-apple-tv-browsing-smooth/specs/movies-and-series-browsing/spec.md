## MODIFIED Requirements

### Requirement: Browsing stays responsive
The system SHALL keep Movies and Series responding to the remote, touch and pointer for a library of 100 000 movies and 30 000 series whose rows name the cast: while it loads, while its rows and grids redraw in any order, and while details and saved positions arrive. Rows, banner, sorted grids and the people index SHALL be built away from the screen, and a redraw SHALL not walk every title. What a long session keeps in memory SHALL stay within fixed limits. On Apple TV a move of the highlight SHALL redraw the posters it moves between, the rows' place and the preview, and not the banner or the other rows.

#### Scenario: A large library loads
- **GIVEN** a source with 100 000 movies
- **WHEN** its list arrives
- **THEN** the rows and the banner appear together without the screen freezing while they are built

#### Scenario: Progress saved while browsing
- **GIVEN** Movies is open on a library of 100 000 movies with titles in Continue watching
- **WHEN** a position is saved, on this device or from another one
- **THEN** Continue watching and Recently watched update without the screen pausing
- **AND** posters whose progress did not change are not drawn again

#### Scenario: All movies
- **GIVEN** a library of 100 000 movies
- **WHEN** the user opens All movies, or a genre, and moves through its grid
- **THEN** the grid is sorted once when it opens, not again as focus moves

#### Scenario: Sorting by title or year
- **GIVEN** a library of 100 000 movies on iPad or Mac
- **WHEN** the user picks Title or Year
- **THEN** the screen keeps responding while the order is worked out, and the grid shows in that order once it is ready

#### Scenario: A playlist series the kept load does not have
- **GIVEN** a playlist source whose kept load lacks a series the banner or a page asks about
- **WHEN** several such series are asked about within five minutes
- **THEN** the playlist is fetched again at most once in those five minutes

#### Scenario: A fast scroll past many posters
- **GIVEN** Movies is open on a large library whose posters load slowly
- **WHEN** the user flicks quickly through rows or a grid
- **THEN** posters that scrolled away stop downloading, and the posters on screen load next

#### Scenario: A drag that starts on the banner
- **GIVEN** Movies or Series is open on iPhone or iPad
- **WHEN** the user drags up from the banner to scroll the rows
- **THEN** the screen follows the finger, and the banner holds its title until the finger lifts

#### Scenario: Details arrive while a person's page or Search is open
- **GIVEN** a library of 100 000 movies and 30 000 series whose rows name the cast, with Search or a person's page open
- **WHEN** the banner turns, a preview rests or a title page opens, each bringing a title's details
- **THEN** the names in those details reach the page and Search within a second, without every title being read again

#### Scenario: A large picture behind the banner
- **GIVEN** posters on screen and a title whose backdrop is a 4K picture
- **WHEN** the banner, the Apple TV preview or the title's page shows that picture
- **THEN** it is kept at the size of the window, and the posters on screen stay without loading again

#### Scenario: A full poster folder
- **GIVEN** the posters kept on the device reached their limit
- **WHEN** the user scrolls on to posters not seen before
- **THEN** the oldest posters go in one batch, not one at a time with each new poster

#### Scenario: A long evening on Apple TV
- **GIVEN** an Apple TV with a large library
- **WHEN** the viewer rests on hundreds of series in turn
- **THEN** episode lists are kept for the latest 100 series asked about and for series with saved progress, and the older ones are let go

#### Scenario: Moving through the rows on Apple TV
- **GIVEN** Movies or Series is open on Apple TV on a library of thousands of titles in dozens of rows, with the preview showing
- **WHEN** the viewer moves across posters and up and down the rows
- **THEN** the banner and the rows are not drawn again for those moves, only when the titles, the saved positions or My list change
- **AND** the rows that pass under the preview fade into the background without the rows being drawn off screen first
