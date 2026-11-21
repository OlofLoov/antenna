## MODIFIED Requirements

### Requirement: Title details are asked once per title
The system SHALL ask the provider for a title's details at most once per launch for the banner, the preview and a Continue watching card together, one preview request at a time, and SHALL use that answer when the title's page opens. Retry on a page SHALL ask again.

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

#### Scenario: A series in Continue watching
- **GIVEN** a series in Continue watching whose card shows its season and episode
- **WHEN** the viewer opens the series' page
- **THEN** the provider was asked about the series once in all
- **AND** a card whose episodes failed to load does not ask again each time it scrolls back into view

### Requirement: Browsing stays responsive
The system SHALL keep Movies and Series responding to the remote, touch and pointer while a library of 100 000 movies and 30 000 series whose rows name the cast loads, while its rows redraw, while a grid of all of it opens in any order, and while details and saved positions arrive. Building the rows, the banner, the sorted grids and the people the titles name SHALL happen away from the screen, and redrawing the rows or a grid SHALL not walk every title. A poster that scrolls off screen SHALL stop loading once nothing on screen waits for it, and a finger moving on the banner SHALL not redraw it on every move. What the app keeps in memory for a long session SHALL stay within fixed limits.

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
