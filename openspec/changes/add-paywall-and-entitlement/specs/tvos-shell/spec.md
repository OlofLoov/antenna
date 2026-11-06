# Spec Delta

## ADDED Requirements

### Requirement: The shell waits for the unlock
The system SHALL open the Apple TV shell, and tune any channel at launch, only once the app is unlocked, and SHALL show the paywall in its place until then.

#### Scenario: Launch without a purchase
- **GIVEN** an Apple TV with no purchase on its Apple Account and a source already synced
- **WHEN** the app launches
- **THEN** the paywall shows, the shell does not open and no channel is tuned
