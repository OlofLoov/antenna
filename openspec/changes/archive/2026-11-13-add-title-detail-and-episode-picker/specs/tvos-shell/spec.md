# Spec Delta

## ADDED Requirements

### Requirement: The tab bar stays hidden on a title page
The system SHALL hide the Apple TV tab bar and clock while a movie or series page is open, and swiping up from the page's top SHALL not reach the tab bar.

#### Scenario: Open a title page
- **GIVEN** the Movies tab on Apple TV
- **WHEN** the user opens a movie's page and swipes up from its topmost button
- **THEN** the tab bar and clock stay hidden and the page stays open
