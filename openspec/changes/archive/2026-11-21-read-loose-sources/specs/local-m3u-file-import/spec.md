## MODIFIED Requirements

### Requirement: See what's in the file before importing
The system SHALL read a file before importing it and show how many channels and groups it holds, whether a guide link was found and how many entries were skipped, with the name and guide link filled in.

#### Scenario: A typical file
- **GIVEN** a playlist file with 412 channels in 18 groups, a guide link and 3 entries that are not links
- **WHEN** the import sheet has read it
- **THEN** it says "412 channels in 18 groups", that a guide link was found, and that 3 entries were skipped, with the name and guide link filled in

#### Scenario: A file name imported before
- **GIVEN** a file whose name was imported before
- **WHEN** the sheet has read it
- **THEN** it asks whether to replace that source or import it as new

#### Scenario: An old Windows encoding
- **GIVEN** a file whose text is in Latin-1 or Windows-1252, with a channel named "München" and a group "Españoles"
- **WHEN** the sheet reads it
- **THEN** it imports, and the name and group read "München" and "Españoles"
