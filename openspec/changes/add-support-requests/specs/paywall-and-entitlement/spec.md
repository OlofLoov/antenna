## MODIFIED Requirements

### Requirement: Nothing works before the app is unlocked
The system SHALL show only the paywall and the Report a problem form it links to until the app is unlocked, and SHALL contact no source, playlist or guide before then. The form SHALL contact only the support service.

#### Scenario: First launch without a purchase
- **GIVEN** a device with no purchase on its Apple Account
- **WHEN** the app launches
- **THEN** the paywall is the only thing shown, and no source, playlist or guide is contacted

#### Scenario: A source waiting for its login
- **GIVEN** a user whose only source is still waiting for its login
- **WHEN** the app launches without a purchase
- **THEN** the user sees the same paywall as anyone else

#### Scenario: Reporting a problem before buying
- **GIVEN** the paywall on any device
- **WHEN** the user chooses "Report a problem" at the bottom of the paywall
- **THEN** the form opens with "Not unlocked" in the "What will be sent" list, sending contacts only the support service, and closing the form returns to the paywall

#### Scenario: Apple TV focus on the paywall
- **GIVEN** the paywall on Apple TV
- **WHEN** it appears
- **THEN** focus starts where it did before this change, and "Report a problem" is reached by moving down past Restore
