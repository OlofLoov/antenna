## MODIFIED Requirements

### Requirement: Back from a tab goes to the tab bar
The system SHALL move the highlight to the open tab in the bar, keeping the tab open, when the user presses Back anywhere on the top level of Guide, Movies, Series, Search or Settings. Movies, Series and Search SHALL scroll back to their top as the highlight reaches the bar. A screen opened from a tab SHALL close on Back first. Swiping up from a page's top does not reach the system bar; Back does. Swiping down from Movies or Series in the bar SHALL land on the banner's Play button.

#### Scenario: Back from a lower row
- **GIVEN** Movies is open with the highlight on a poster four rows down
- **WHEN** the user presses Back
- **THEN** the rows scroll back to the top with the banner showing and the highlight moves to Movies in the tab bar
- **AND** a swipe down lands on the banner's Play button

#### Scenario: Back at the banner
- **GIVEN** Movies, Series or Search is open with the highlight on its topmost item
- **WHEN** the user presses Back
- **THEN** the highlight moves to that tab in the bar and the tab stays open

#### Scenario: Swipe up at the banner
- **GIVEN** Movies is open with the highlight on the banner's Play button
- **WHEN** the user swipes up
- **THEN** the highlight stays on Play and the bar stays hidden

#### Scenario: Back on the Guide
- **GIVEN** the Guide is open with the highlight in the grid
- **WHEN** the user presses Back
- **THEN** the bar appears over the guide with the highlight on Guide, and the guide keeps the programme that was highlighted

#### Scenario: Back from a genre grid
- **GIVEN** a genre grid opened from the Movies rows
- **WHEN** the user presses Back
- **THEN** the grid closes and the rows show with the highlight back on the banner, and the bar does not take the highlight

#### Scenario: Swipe down after moving along the bar
- **GIVEN** the viewer moved along the bar from Movies to Series and back, or pressed Back on the banner
- **WHEN** they swipe down onto Movies
- **THEN** the highlight lands on the banner's Play button, not on the banner button or the poster nearest the tab
