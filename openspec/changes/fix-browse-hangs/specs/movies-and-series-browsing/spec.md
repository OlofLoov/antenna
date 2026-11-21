## MODIFIED Requirements

### Requirement: Browsing stays responsive
The system SHALL keep Movies and Series responding to the remote, touch and pointer while a library of 50 000 movies and 10 000 series loads, while its rows redraw, and while a grid of all of it opens. Building the rows and the banner SHALL happen away from the screen, and redrawing the rows or a grid SHALL not walk every title. A poster that scrolls off screen SHALL stop loading once nothing on screen waits for it, and a finger moving on the banner SHALL not redraw it on every move.

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

#### Scenario: A fast scroll past many posters
- **GIVEN** Movies is open on a large library whose posters load slowly
- **WHEN** the user flicks quickly through rows or a grid
- **THEN** posters that scrolled away stop downloading, and the posters on screen load next

#### Scenario: A drag that starts on the banner
- **GIVEN** Movies or Series is open on iPhone or iPad
- **WHEN** the user drags up from the banner to scroll the rows
- **THEN** the screen follows the finger, and the banner holds its title until the finger lifts
