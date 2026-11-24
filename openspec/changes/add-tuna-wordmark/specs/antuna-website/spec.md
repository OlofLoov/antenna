## ADDED Requirements

### Requirement: The header shows the wordmark
Every page of the site SHALL show the Antuna wordmark in its header, linking home, in near-white letters with teal tips on the dark page and near-black letters with darker teal tips on the light page. Screen readers SHALL read it as "Antuna". The browser tab SHALL show the app icon.

#### Scenario: Dark mode
- **GIVEN** a visitor whose device is in dark mode
- **WHEN** they open any page
- **THEN** the header shows the light wordmark on the dark page, with the page showing through the play triangle

#### Scenario: Light mode
- **GIVEN** a visitor whose device is in light mode
- **WHEN** they open any page
- **THEN** the header shows the dark wordmark with darker teal tips

#### Scenario: A screen reader
- **WHEN** a screen reader reaches the header
- **THEN** it reads a link named "Antuna"
