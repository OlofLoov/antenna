# Spec Delta

## ADDED Requirements

### Requirement: The shell hosts multi-view
The system SHALL show multi-view inside the Apple TV shell, and when multi-view ends it SHALL keep the surviving tile's player as the shell's playing channel rather than starting a new one.

#### Scenario: Leave multi-view inside the shell
- **GIVEN** multi-view open in the Apple TV shell with tile 2 highlighted
- **WHEN** the user presses Menu
- **THEN** tile 2's channel plays full screen without a reload and the tab bar stays hidden
