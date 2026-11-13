## ADDED Requirements

### Requirement: Choose when subtitles show
The system SHALL offer a Subtitles preference with Off, Auto and Always, starting at Auto, explain each choice in plain words, and carry a change to the user's other devices like the other preferences.

#### Scenario: The default
- **GIVEN** a new user
- **WHEN** they open Preferences
- **THEN** Subtitles reads Auto

#### Scenario: Picking a choice
- **GIVEN** Preferences is open
- **WHEN** the user sets Subtitles to Always
- **THEN** the row reads Always, the next stream starts by it, and the change reaches the user's other devices through iCloud

#### Scenario: Plain words
- **GIVEN** the Subtitles choices are listed
- **WHEN** the user reads them
- **THEN** a line under the row says what the current choice does, such as "Subtitles show when the sound is not in one of your languages"

#### Scenario: Apple TV
- **GIVEN** Preferences on Apple TV
- **WHEN** the user moves focus to Subtitles and presses select
- **THEN** the choices open as a list with the current one ticked, and Menu goes back without a change
