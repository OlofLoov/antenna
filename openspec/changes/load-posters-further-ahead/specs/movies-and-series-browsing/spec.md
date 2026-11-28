## MODIFIED Requirements

### Requirement: Browsing stays responsive
The system SHALL keep Movies and Series responding to the remote, touch and pointer for a library of 100 000 movies and 30 000 series whose rows name the cast: while it loads, while its rows and grids redraw in any order, and while details and saved positions arrive. Rows, banner, sorted grids and the people index SHALL be built away from the screen, and a redraw SHALL not walk every title. A long session's memory SHALL stay within fixed limits. Posters SHALL load ahead of the viewer.

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
- **WHEN** the banner turns, a card rests or a title page opens, each bringing a title's details
- **THEN** the names in those details reach the page and Search within a second, without every title being read again

#### Scenario: A large picture behind the banner
- **GIVEN** posters on screen and a title whose backdrop is a 4K picture
- **WHEN** the banner, the Apple TV expanded card or the title's page shows that picture
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
- **GIVEN** Movies or Series is open on Apple TV on a library of thousands of titles in dozens of rows
- **WHEN** the viewer moves across posters and up and down the rows
- **THEN** the banner and the rows are not drawn again for those moves, only the poster that loses the highlight and the one that gains it, and the screen when the highlight enters or leaves the rows

#### Scenario: Posters ahead of the highlight
- **GIVEN** Movies is open on a library of thousands of titles whose posters take a moment to arrive
- **WHEN** a poster in a row shows
- **THEN** the next six posters along that row in the direction it is scrolling start loading
- **AND** when a row shows, the posters the next two rows in the direction of the scroll show first start loading: the rows under it on the way down, the rows above on the way up
- **AND** a row that has just come into view loads nothing along it until it has been in view for half a second
- **AND** on Apple TV, when the highlight lands on a poster, the posters around its column load in the two rows past it in the direction it last moved between rows and in the one row on the other side, the nearest row first
- **AND** they are decoded at the size of a card on screen, away from the screen, as the posters on screen are
- **AND** this holds on iPhone, iPad, Mac and Apple TV

#### Scenario: A slow poster host
- **GIVEN** Movies is open on a library whose posters each take half a second to arrive
- **WHEN** posters are loading ahead and a poster on screen has not loaded yet
- **THEN** at most five posters load ahead at a time, over at most six connections to the host, and the poster on screen starts loading at once, not after the ones loading ahead
- **AND** a poster waiting its turn that the viewer has moved away from before it started is never downloaded

#### Scenario: The highlight moves on before the posters around it load
- **GIVEN** the highlight is on a poster on Apple TV and the rows by it are loading the posters around its column
- **WHEN** the highlight moves to the next poster
- **THEN** the posters both positions want keep loading, and only those the new position does not want stop

#### Scenario: Posters kept in memory
- **GIVEN** an Apple TV 4K with a large library
- **WHEN** the viewer moves through dozens of rows
- **THEN** the decoded posters kept in memory stay under 80 MB, as on iPhone, iPad and Mac, each at the size its card shows it with no room for the focus lift
- **AND** the posters loaded ahead never take memory past that limit; the posters shown longest ago go first
- **AND** the poster files kept on the device stay under 500 MB, so a poster that left memory decodes again from its file

#### Scenario: Moving along a row and down the rows on Apple TV
- **GIVEN** Apple TV on a library of 9 000 movies in 80 rows, with posters that each take a tenth of a second to arrive
- **WHEN** the viewer presses right ten times and left ten times, then moves down six rows and up six, without waiting
- **THEN** along the row at most one in ten of the posters that come into view is still loading when it appears
- **AND** down and up the rows fewer than half are, and each of those fades in when it arrives
- **AND** the screen, the banner and the rows are not drawn again for those moves
