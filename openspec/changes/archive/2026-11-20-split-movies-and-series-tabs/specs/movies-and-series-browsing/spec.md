## ADDED Requirements

### Requirement: Pick a genre from a list on iPhone
The system SHALL show on iPhone, and in a narrow iPad window, one genre button over the Movies and Series banners in place of a row of genre chips, reading the open list's name and count. The button SHALL open a half-height Genres sheet with a search field, listing All, My list and every genre with its count and a checkmark on the open one. Picking one SHALL close the sheet and show that list as the chips did.

#### Scenario: Opening the sheet
- **GIVEN** Movies is open on iPhone with the rows showing
- **WHEN** the user looks at the top of the banner
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

## MODIFIED Requirements

### Requirement: Movies and Series appear when your provider has them
The system SHALL list Movies and Series in the sidebar or tab bar whenever the user has at least one Xtream source, before its login arrives or it answers, each as a tab or section of its own on every device, and SHALL list neither without an Xtream source.

#### Scenario: An Xtream source exists
- **GIVEN** the user has at least one Xtream source, whether or not its login has reached this device or it has answered yet
- **WHEN** the user looks at the tab bar or sidebar
- **THEN** Movies and Series are listed, each on its own, with no Movies | Series switch on iPhone

#### Scenario: No Xtream source
- **GIVEN** the user has no Xtream source
- **WHEN** the user looks at the tab bar or sidebar
- **THEN** neither Movies nor Series appears

### Requirement: Search from the section
The system SHALL open Search set to movies or series with the field ready and any typed text carried over when the user types in the Movies or Series toolbar field on iPad and Mac. On iPhone the tab bar's search button SHALL be the way to search, with no search button of the section's own, and Apple TV SHALL use its Search tab.

#### Scenario: Search on iPhone, iPad or Mac
- **GIVEN** the Movies or Series section on iPhone, iPad or Mac
- **WHEN** the user taps the search button at the trailing end of the iPhone tab bar, or types in the toolbar's search field on iPad and Mac
- **THEN** Search opens with the field ready for typing, set to movies or series with the typed text carried over on iPad and Mac
- **AND** on iPhone the section has no search button of its own, and the Movies and Series chips narrow the results once there are some

#### Scenario: Apple TV
- **GIVEN** the Movies or Series section on Apple TV
- **WHEN** the user looks for a search button
- **THEN** there is none, and the Search tab is the way to search
