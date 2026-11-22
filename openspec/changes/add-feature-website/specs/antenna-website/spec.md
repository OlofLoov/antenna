## MODIFIED Requirements

### Requirement: The pages read on a phone and in dark mode
The system SHALL lay out every page at the width of the device without zooming, follow the device's light or dark appearance on every page but the setup page, load images only from the site itself and only images the site publishes, and load no scripts, fonts, trackers or other files, and nothing from any other address.

#### Scenario: A phone in dark mode
- **GIVEN** an iPhone in dark mode
- **WHEN** the user opens the Privacy Policy
- **THEN** the text is light on a dark background, fits the screen, and needs no sideways scrolling

#### Scenario: A phone in light mode
- **GIVEN** an iPhone in light mode
- **WHEN** the user opens the Terms of Use
- **THEN** the text is dark on a light background

#### Scenario: A feature page with screenshots
- **WHEN** someone opens a feature page
- **THEN** its screenshots load from the site itself, fit the screen, and the browser makes no request to another address

#### Scenario: Nothing else loads
- **WHEN** any page opens
- **THEN** the browser makes no request beyond the page, the site's stylesheet and the site's own images

#### Scenario: A slow connection
- **GIVEN** a phone on a slow mobile connection
- **WHEN** someone opens the home page
- **THEN** the text shows before the screenshots finish, and the page with its first screenshot is under 500 KB
