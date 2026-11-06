# Spec Delta

## ADDED Requirements

### Requirement: Archive channels use Xtream catch-up
The system SHALL give a live stream whose archive flag is above 0 the Xtream catch-up style.

#### Scenario: Archive flag set
- **GIVEN** a live stream with `tv_archive` 1
- **WHEN** it is mapped to a channel
- **THEN** the channel has the Xtream catch-up style

#### Scenario: Archive flag off
- **GIVEN** a live stream with `tv_archive` 0
- **WHEN** it is mapped to a channel
- **THEN** the channel has no catch-up style

### Requirement: Server time zone
The system SHALL read the server's time zone from the account information once per source load, and SHALL ask for it again on first need when it is missing.

#### Scenario: Time zone in the account information
- **GIVEN** account information whose server info names the time zone "Europe/Stockholm"
- **WHEN** the source loads
- **THEN** the server time zone is Europe/Stockholm and the account information is asked for once

#### Scenario: Time zone missing
- **GIVEN** the time zone was not known after the load
- **WHEN** a catch-up address is first needed
- **THEN** the account information is asked for again
