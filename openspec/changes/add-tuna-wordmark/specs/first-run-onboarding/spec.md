## ADDED Requirements

### Requirement: The welcome says hello
The welcome screen SHALL show the Antuna wordmark above its title on iPhone, iPad, Mac and Apple TV, and SHALL play Hello once when the screen first appears.

#### Scenario: First launch
- **GIVEN** the user has paid and has added no provider
- **WHEN** the welcome screen opens
- **THEN** the wordmark writes itself, the a says hello, and the mark comes to rest above "Welcome to Antuna"

#### Scenario: Back from the form
- **GIVEN** the welcome screen played Hello
- **WHEN** the user opens Add a source and comes back without saving
- **THEN** the mark stands still and does not play Hello again

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the welcome screen opens
- **THEN** the still wordmark fades in
