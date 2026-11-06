# Spec Delta

## ADDED Requirements

### Requirement: Shell state belongs to the current Apple TV user
The system SHALL keep the shell's on-device state, such as the last channel, separately for each Apple TV user, and write it as it changes so a user switch loses nothing.

#### Scenario: Launch after a user switch
- **GIVEN** user A last watched channel 104 and user B last watched channel 7 on the same Apple TV
- **WHEN** B switches to A and Antenna opens
- **THEN** channel 104 plays
