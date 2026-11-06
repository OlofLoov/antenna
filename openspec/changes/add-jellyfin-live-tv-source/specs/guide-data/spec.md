# Spec Delta

## ADDED Requirements

### Requirement: Guide from a source that serves programmes directly
The system SHALL take programmes for a source that serves them in batches straight from that source, instead of downloading an XMLTV file, and show progress batch by batch.

#### Scenario: A Jellyfin source's guide
- **GIVEN** a Jellyfin source with channels loaded
- **WHEN** the guide refreshes
- **THEN** the programmes come from the server in batches of channels, with no XMLTV download, and the loading progress counts batches

#### Scenario: Refresh fails
- **GIVEN** a Jellyfin source with a guide already loaded
- **WHEN** a refresh fails as no connection
- **THEN** the previous guide is kept
