## MODIFIED Requirements

### Requirement: The checklist shows real progress
The system SHALL turn each checklist line done or failed as the login, playlist, channels, movies and guide finish or fail, with real numbers, and SHALL show the guide's download progress while it runs.

#### Scenario: Lines fill in with numbers
- **GIVEN** the loading checklist is showing
- **WHEN** the login, playlist, channels, movies and guide finish or fail
- **THEN** each line turns done or failed with real numbers: live channels and groups, movies and series, guide days and how many channels have a guide
- **AND** the account line gives when the account expires and how many screens it allows when the server says
- **AND** the guide line shows its download progress while it runs

#### Scenario: No guide at all
- **GIVEN** a playlist without a guide link, or an Xtream account without a guide
- **WHEN** the checklist shows
- **THEN** there is no guide line

#### Scenario: The movie list is slow
- **GIVEN** a very large Xtream account whose movie list is slow
- **WHEN** the movies line has waited its limit
- **THEN** the line stops waiting and says movies and series are available without counts

#### Scenario: The account has no expiry date
- **GIVEN** an Xtream account whose server gives a screen count but no expiry date
- **WHEN** the login line turns done
- **THEN** the account line shows only the screen count, such as "2 connections", with no " · " before it
- **AND** when the server gives neither, the login line shows "Signed in" with nothing beneath

#### Scenario: VoiceOver reads a line
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a checklist line
- **THEN** it is read as one item with its state, title and detail

#### Scenario: Back while loading on Apple TV
- **GIVEN** the loading checklist is showing on Apple TV and at least one line is still loading
- **WHEN** the user presses Back
- **THEN** the app goes to the Apple TV Home Screen
