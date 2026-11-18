## MODIFIED Requirements

### Requirement: Open a movie's page
The system SHALL open a movie's page at once from More info, showing what it already knows while it asks the provider for the details once. When the banner, the Apple TV preview or an earlier page already has the details, the page SHALL show them at once without asking.

#### Scenario: More info on a movie
- **GIVEN** a movie on the Movies banner and as a poster
- **WHEN** the user picks More info on the banner or in the poster's menu
- **THEN** the movie's page opens at once with its name, "Movie · <category>" and its poster, shows the details the section already has or shows that the rest is loading, and asks the provider at most once

#### Scenario: Leave before the details arrive
- **GIVEN** a page whose details are still loading
- **WHEN** the user leaves it
- **THEN** the page stops waiting and a late reply changes nothing on it
- **AND** the reply is kept, so opening the page again shows the details without asking again

#### Scenario: The source is deleted
- **GIVEN** a title's page open
- **WHEN** its source is deleted
- **THEN** the page closes and the section shows again

#### Scenario: The same title on two sources
- **GIVEN** two sources with the same title
- **WHEN** the user opens each poster
- **THEN** each opens its own page and keeps its own progress
