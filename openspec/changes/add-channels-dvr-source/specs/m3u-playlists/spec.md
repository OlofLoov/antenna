# Spec Delta

## ADDED Requirements

### Requirement: Title-first channel names
The system SHALL offer a parsing option that names a channel from its title after the comma before its `tvg-name`, for sources whose title is the name the user set.

#### Scenario: Title first
- **GIVEN** an entry with `tvg-name="KGWDT"` and the title "NBC"
- **WHEN** it is parsed with the title-first option
- **THEN** the channel is named "NBC"

#### Scenario: Empty title
- **GIVEN** an entry with `tvg-name="KGWDT"` and an empty title
- **WHEN** it is parsed with the title-first option
- **THEN** the channel is named "KGWDT"

### Requirement: Minor channel numbers
The system SHALL read a channel number with a part after the dot, such as 6.1, as a major and a minor number.

#### Scenario: An over-the-air number
- **GIVEN** an entry with `tvg-chno="6.1"`
- **WHEN** it is parsed
- **THEN** the channel has major number 6 and minor number 1

#### Scenario: A whole number
- **GIVEN** an entry with `tvg-chno="104"`
- **WHEN** it is parsed
- **THEN** the channel has number 104 and no minor number
