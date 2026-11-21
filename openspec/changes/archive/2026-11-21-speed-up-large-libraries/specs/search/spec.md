## ADDED Requirements

### Requirement: Typing keeps up with a large library
The system SHALL keep the Search field following each letter typed, on every platform, while the sources hold 100 000 movies and 30 000 series, and SHALL leave the results on screen untouched when searching again finds the same answer.

#### Scenario: Typing on Apple TV
- **GIVEN** an Apple TV whose sources hold 100 000 movies and 30 000 series
- **WHEN** the viewer types a name letter by letter on the on-screen keyboard
- **THEN** each letter shows in the field without a pause, and the results follow once typing stops

#### Scenario: Results that did not change
- **GIVEN** Search showing results for a query
- **WHEN** Search looks again a few seconds later and finds the same channels, programmes, titles and people
- **THEN** the results on screen are not drawn again

#### Scenario: People while names arrive
- **GIVEN** Search showing people for a query
- **WHEN** a title's details bring new names
- **THEN** the People section updates without the field pausing
