# Spec Delta

## ADDED Requirements

### Requirement: The guide is kept per Apple TV user
The system SHALL keep the downloaded guide on Apple TV for the current user only, so two users with the same source each download and store their own copy.

#### Scenario: Two users with the same source
- **GIVEN** users A and B on one Apple TV who each added the same source
- **WHEN** B opens Antenna after A's guide has downloaded
- **THEN** B's guide downloads again rather than using A's copy
