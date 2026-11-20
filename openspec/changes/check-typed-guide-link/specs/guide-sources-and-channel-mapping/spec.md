# Spec Delta

## MODIFIED Requirements

### Requirement: Add a guide link
The system SHALL add a guide link the user enters to the end of the playlist's guide list and start downloading it, and SHALL refuse a link that is not a web address, is already listed, or whose first bytes show it is not a guide. A link the first bytes cannot decide on SHALL be saved.

#### Scenario: Adding a link
- **GIVEN** the Guide sources screen for a playlist
- **WHEN** the user enters a guide link and saves it
- **THEN** Save reads "Checking…" for at most a few seconds and cannot be pressed again
- **AND** the link joins the end of the list and starts downloading

#### Scenario: A bad or repeated link
- **GIVEN** the user enters a link that is not a web address, or one already in the list
- **WHEN** they save it
- **THEN** it is refused with a message

#### Scenario: A link that is not a guide
- **GIVEN** the user enters a link whose server answers "not found", refuses the login, sends a web page, or sends something that is neither an XMLTV guide nor a compressed file
- **WHEN** they save it
- **THEN** the form stays open with a message under the field that says which, and nothing is added

#### Scenario: A link that cannot be checked
- **GIVEN** the user enters a link whose server does not answer within a few seconds, answers with a server error or "too many requests", or sends too little to tell
- **WHEN** they save it
- **THEN** it is saved and starts downloading, and its row reports what the download finds

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user adds a guide
- **THEN** it is saved, and its row says it will retry when the device is back online

#### Scenario: Cancel while checking
- **GIVEN** Save reads "Checking…"
- **WHEN** the user cancels the form
- **THEN** the check stops and nothing is added
