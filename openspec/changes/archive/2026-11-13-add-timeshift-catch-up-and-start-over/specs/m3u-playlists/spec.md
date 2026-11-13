# Spec Delta

## ADDED Requirements

### Requirement: Catch-up style, source and correction
The system SHALL read an entry's `catchup` style, `catchup-source` template and `catchup-correction` hours, and SHALL ignore a correction that is not a number without dropping the channel.

#### Scenario: Full catch-up details
- **GIVEN** an entry with `catchup="shift"`, `catchup-source="?utc={utc}"` and `catchup-correction="-1"`
- **WHEN** it is parsed
- **THEN** the channel has the shift style, that source template and a correction of minus one hour

#### Scenario: A correction that is not a number
- **GIVEN** an entry with `catchup-correction="abc"`
- **WHEN** it is parsed
- **THEN** the channel is kept and has no correction
