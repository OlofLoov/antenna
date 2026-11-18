## MODIFIED Requirements

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

## ADDED Requirements

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
