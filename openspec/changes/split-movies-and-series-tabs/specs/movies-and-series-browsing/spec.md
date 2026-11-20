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
