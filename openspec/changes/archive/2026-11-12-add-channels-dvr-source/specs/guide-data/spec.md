# Spec Delta

## ADDED Requirements

### Requirement: Guide address worked out from the source
The system SHALL fetch the guide for a source that knows its own guide address from that address when the user has set no guide link, sending the source's proxy password with the request.

#### Scenario: A Channels DVR source with a proxy password
- **GIVEN** a Channels DVR source with a proxy username and password and no guide link set by hand
- **WHEN** the guide refreshes
- **THEN** it downloads seven days of guide from the server's own guide address with the username and password sent
