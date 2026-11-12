# Spec Delta

## ADDED Requirements

### Requirement: Numbers with a part after the dot
The system SHALL order channels by major then minor number and show a minor number after a dot.

#### Scenario: Ordering over-the-air numbers
- **GIVEN** channels numbered 6.2, 6.1, 7 and 6
- **WHEN** the catalogue lists them
- **THEN** they appear as 6, 6.1, 6.2, 7
