## MODIFIED Requirements

### Requirement: Who's watching at launch
The system SHALL open a "Who's watching?" screen at launch when the user has two or more profiles, listing every profile with its color, initial and name in the user's order, and SHALL open on the profile chosen. With one profile it SHALL open as before, showing no profile name or profile button; only Settings offers a way to add a profile.

#### Scenario: Two or more profiles
- **GIVEN** the profiles Dad, Mum and Kids
- **WHEN** the user opens Antenna
- **THEN** the "Who's watching?" screen lists Dad, Mum and Kids, each with its color and initial, before any channel plays
- **AND** choosing Kids opens Antenna on Kids's favorites, last channel and history

#### Scenario: One profile
- **GIVEN** a single profile
- **WHEN** the user opens Antenna
- **THEN** no "Who's watching?" screen appears and no profile name or button is shown
- **AND** Settings lists Profiles with "Add a profile"

#### Scenario: Focus on Apple TV
- **GIVEN** the "Who's watching?" screen on Apple TV
- **WHEN** it appears
- **THEN** focus is on the profile last used on this Apple TV, or the first profile when none was
- **AND** Back on this screen goes to the Apple TV Home Screen, since there is nothing behind it

#### Scenario: The focused circle shows whole
- **GIVEN** the "Who's watching?" screen, or the profile button at the top of Settings, on Apple TV
- **WHEN** a profile circle has focus and lifts
- **THEN** the whole circle and its shadow show, with nothing cut from its sides

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** a profile tile is focused
- **THEN** it reads the profile's name and "profile"
