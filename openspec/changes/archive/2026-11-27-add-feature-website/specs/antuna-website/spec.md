## MODIFIED Requirements

### Requirement: The pages read on a phone and in dark mode
The system SHALL lay out every page at the width of the device without zooming, follow the device's light or dark appearance on every page but the setup page, and load scripts, stylesheets and images only from the site itself and only ones the site publishes. It SHALL load no third-party script, font, tracker or analytics, set no cookie, and request nothing from any other address. The setup page SHALL load no script.

#### Scenario: A phone in dark mode
- **GIVEN** an iPhone in dark mode
- **WHEN** the user opens the Privacy Policy
- **THEN** the text is light on a dark background, fits the screen, and needs no sideways scrolling

#### Scenario: A phone in light mode
- **GIVEN** an iPhone in light mode
- **WHEN** the user opens the Terms of Use
- **THEN** the text is dark on a light background

#### Scenario: No flash of the wrong appearance
- **GIVEN** a phone in dark mode on a slow connection
- **WHEN** someone opens any page
- **THEN** the page is dark from the first moment it shows, before any script has run

#### Scenario: A feature page with screenshots
- **WHEN** someone opens a feature page
- **THEN** its screenshots load from the site itself, fit the screen, and the browser makes no request to another address

#### Scenario: Nothing else loads
- **WHEN** any page opens, or the visitor moves to another page
- **THEN** the browser requests only pages, stylesheets, scripts and images from the site itself, and stores no cookie

#### Scenario: The setup page
- **WHEN** an iPhone without Antuna opens a setup link
- **THEN** the page loads no script, image or stylesheet, as before

#### Scenario: A slow connection
- **GIVEN** a phone on a slow mobile connection
- **WHEN** someone opens the home page
- **THEN** the text shows before the screenshots and scripts finish, and the page with its scripts and first screenshot is under 500 KB
