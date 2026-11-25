## ADDED Requirements

### Requirement: A pinned top bar on iPhone
On iPhone, and in a narrow iPad window, the system SHALL show Movies and Series under a bar pinned at the top of the screen with the section's name, the genre button and the profile button. The banner SHALL start below the bar, never under it, and rows and posters SHALL scroll under the bar, where the system blurs them so the bar stays legible over any picture.

#### Scenario: Opening Movies
- **WHEN** the user opens Movies on iPhone
- **THEN** "Movies", the genre button reading "All movies" and the profile button are in a bar at the top
- **AND** the banner's picture starts below the bar

#### Scenario: A light picture in the banner
- **GIVEN** the banner shows a title whose picture is white
- **WHEN** the user opens Series on iPhone
- **THEN** "Series" and "All series" with its count and chevron are as legible as over a dark picture, since the picture is below the bar

#### Scenario: Scrolling the rows
- **GIVEN** Movies is open on iPhone
- **WHEN** the user scrolls down past the banner and the first rows
- **THEN** the bar stays where it was with the name, the genre button and the profile button
- **AND** the posters passing under the bar are blurred there

#### Scenario: A picked genre
- **GIVEN** Movies is open on iPhone and the user has scrolled down
- **WHEN** the user picks Drama in the Genres sheet
- **THEN** the genre button in the bar reads Drama and its count

#### Scenario: No titles yet
- **GIVEN** the user's sources are still loading their movies
- **WHEN** the user opens Movies on iPhone
- **THEN** the bar shows "Movies" and the profile button, with no genre button until there are titles

#### Scenario: A narrow iPad window
- **GIVEN** the app shares the screen with another app on iPad and its window is narrow
- **WHEN** the user opens Movies
- **THEN** Movies shows the same bar and banner as on iPhone

## MODIFIED Requirements

### Requirement: Pick a genre from a list on iPhone
The system SHALL show on iPhone, and in a narrow iPad window, one genre button in the top bar of Movies and Series in place of a row of genre chips, reading the open list's name and count. The button SHALL open a half-height Genres sheet with a search field, listing All, My list and every genre with its count and a checkmark on the open one. Picking one SHALL close the sheet and show that list as the chips did.

#### Scenario: Opening the sheet
- **GIVEN** Movies is open on iPhone with the rows showing
- **WHEN** the user looks at the top bar
- **THEN** there are no genre chips, only the button reading "All movies" and the count
- **AND** tapping it opens the Genres sheet at half height with the search field showing

#### Scenario: Picking a genre
- **GIVEN** the Genres sheet is open
- **WHEN** the user picks Drama
- **THEN** the sheet closes, the Drama grid takes the rows' place, and the button reads Drama and its count

#### Scenario: Searching the genres
- **GIVEN** a provider with the genres "EN | Action", "DE | Action" and "EN | Drama"
- **WHEN** the user types "en action" in the sheet's search field
- **THEN** only "EN | Action" is listed, matched without regard to case or accents

#### Scenario: iPad, Mac and Apple TV
- **GIVEN** iPad or Mac in the wide layout, or Apple TV
- **WHEN** the user browses Movies or Series
- **THEN** the genres stay in the sidebar on iPad and Mac and in the chips row on Apple TV
