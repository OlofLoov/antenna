# Spec Delta

## ADDED Requirements

### Requirement: A source can wait for its credential
The system SHALL report a source whose password has not reached this device as waiting for its credential, separately from a source that loaded or failed.

#### Scenario: Password not synced yet
- **GIVEN** a source that needs a password and whose Keychain item has not arrived on this device
- **WHEN** the sources load
- **THEN** that source reports waiting for its credential, sends no request, and the other sources load
