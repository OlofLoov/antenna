## ADDED Requirements

### Requirement: A panel playlist falls back to the panel's guide
The system SHALL use the Xtream panel's guide for a playlist source added from an Xtream panel link when the user entered no guide link and the playlist names none. Working this out SHALL send nothing over the network, and the guide link SHALL be logged without its login.

#### Scenario: A panel playlist without a guide link
- **GIVEN** a playlist source added from `http://tv.example.net:8080/get.php?username=anna&password=s3cret` whose header names no guide
- **WHEN** its guide loads
- **THEN** it downloads the panel's guide for that login

#### Scenario: A guide link of the user's own
- **GIVEN** the same source with a guide link entered by the user
- **WHEN** its guide loads
- **THEN** it uses the entered link and the panel's guide stays turned off

#### Scenario: The playlist names a guide
- **GIVEN** a panel playlist whose header names a guide
- **WHEN** its guide loads
- **THEN** it uses the header's guide and the panel's guide stays turned off
