## ADDED Requirements

### Requirement: Report a problem from Settings
The system SHALL list a "Report a problem" row in Settings on iPhone, iPad, Mac and Apple TV that opens the Report a problem form with nothing filled in.

#### Scenario: The row on every device
- **GIVEN** Settings on iPhone, iPad, Mac or Apple TV
- **WHEN** the user looks at the list
- **THEN** a "Report a problem" row shows under About, and choosing it opens the form empty

#### Scenario: Apple TV focus
- **GIVEN** Settings on Apple TV
- **WHEN** focus reaches "Report a problem" and the user presses select
- **THEN** the form opens with focus on "What happened?", and Menu from the empty form returns focus to the row

#### Scenario: A playback error earlier
- **GIVEN** a channel failed a few minutes ago
- **WHEN** the user opens the form from Settings
- **THEN** the text is empty and the "What will be sent" list still shows that error as the last playback error
