## MODIFIED Requirements

### Requirement: Back to where you were
The system SHALL return the user from a title page to the section they came from, at the same scroll position and without reloading, with the starting poster or button in view. On Apple TV, leaving a title played from a poster SHALL put the highlight back on that poster.

#### Scenario: Go back
- **GIVEN** the page was opened from a poster deep in a row, from the banner, or from search results
- **WHEN** the user goes back with Menu (Apple TV), the back button or Escape (iPad, Mac), or the back button or an edge swipe (iPhone)
- **THEN** the section shows the same rows at the same scroll position without reloading, with the poster or button they started from focused on Apple TV and in view elsewhere
- **AND** from search, Search shows with the query still there

#### Scenario: Back from a title played from a poster on Apple TV
- **GIVEN** the viewer played a movie from a poster deep in a row, or a title from a Continue watching card
- **WHEN** they leave playback with Menu, or it ends
- **THEN** the rows show at the same place with that poster focused and its preview showing, not the banner
