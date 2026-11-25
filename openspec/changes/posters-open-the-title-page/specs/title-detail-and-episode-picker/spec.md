## MODIFIED Requirements

### Requirement: Open a movie's page
The system SHALL open a movie's page at once from its poster outside Continue watching and Recently watched, from a search result or a person's page, and from More info on the banner or in a poster's menu, showing what it already knows while it asks the provider for the details once. When the banner, the Apple TV preview or an earlier page already has the details, the page SHALL show them at once without asking.

#### Scenario: Select a movie
- **GIVEN** a movie as a poster in a row or grid, in search results or on a person's page
- **WHEN** the user selects the poster
- **THEN** the movie's page opens at once with its name, "Movie · <category>" and its poster, shows the details the section already has or shows that the rest is loading, asks the provider at most once, and nothing starts playing

#### Scenario: More info on a movie
- **GIVEN** a movie on the Movies banner, in Continue watching or in Recently watched
- **WHEN** the user picks More info on the banner or in the card's menu
- **THEN** the movie's page opens at once, as from its poster

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

### Requirement: Back to where you were
The system SHALL return the user from a title page to the section they came from, at the same scroll position and without reloading, with the starting poster or button in view. On Apple TV, leaving a title played from a Continue watching card or from Recently watched SHALL put the highlight back on that card.

#### Scenario: Go back
- **GIVEN** the page was opened from a movie or series poster deep in a row, from the banner, or from search results
- **WHEN** the user goes back with Menu (Apple TV), the back button or Escape (iPad, Mac), or the back button or an edge swipe (iPhone)
- **THEN** the section shows the same rows at the same scroll position without reloading, with the poster or button they started from focused on Apple TV and in view elsewhere
- **AND** from search, Search shows with the query still there

#### Scenario: Back from a title played from a poster on Apple TV
- **GIVEN** the viewer played a title from a Continue watching card, or a movie from Recently watched
- **WHEN** they leave playback with Menu, or it ends
- **THEN** the rows show at the same place with that card focused and its preview showing, not the banner
