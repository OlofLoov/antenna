## ADDED Requirements

### Requirement: A switch for movie database lookups
The system SHALL show a "Movie info and scores" switch under Preferences in Settings on every device, on by default, with a line saying titles are looked up in TMDB when their page opens, and SHALL carry a change to the user's other devices like the other preferences.

#### Scenario: Reading the switch
- **WHEN** the user opens Settings on iPhone, iPad, Mac or Apple TV
- **THEN** Preferences has "Movie info and scores", on, and below it the line "Titles you open are looked up in TMDB by name and year. Nothing about you or your sources is sent."

#### Scenario: Changing it on one device
- **GIVEN** an iPhone and an Apple TV on one iCloud account
- **WHEN** the user turns the switch off on the iPhone
- **THEN** the Apple TV shows it off once the change arrives, and looks nothing up from then on

#### Scenario: Apple TV focus
- **GIVEN** Settings on Apple TV
- **WHEN** focus reaches the switch and the user presses select
- **THEN** the switch changes and focus stays on it
