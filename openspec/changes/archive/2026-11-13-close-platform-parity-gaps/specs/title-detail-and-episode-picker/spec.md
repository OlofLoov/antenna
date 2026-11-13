## MODIFIED Requirements

### Requirement: Trailer
The system SHALL offer a Trailer button when the provider gives a trailer link, opening it outside the app on iPhone, iPad and Mac, and on Apple TV only when the link is a video file or stream the app can play, playing it in the app.

#### Scenario: A trailer link
- **GIVEN** the provider gives a trailer link for the title, on iPhone, iPad or Mac
- **WHEN** the user presses Trailer
- **THEN** the link opens outside the app

#### Scenario: A playable trailer on Apple TV
- **GIVEN** the provider's trailer link on Apple TV points at a video file or an HLS stream
- **WHEN** the user presses Trailer
- **THEN** the trailer plays full screen in the app, and Menu or its end goes back to the title page without saving a place in Continue watching

#### Scenario: No Trailer button
- **WHEN** the title has no link, or on Apple TV the link is a web page such as YouTube
- **THEN** there is no Trailer button
