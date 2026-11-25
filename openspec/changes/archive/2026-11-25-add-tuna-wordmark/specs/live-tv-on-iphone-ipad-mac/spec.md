## ADDED Requirements

### Requirement: The loading list tunes in
While sources load and no channel is listed yet, the list on iPhone, iPad and Mac SHALL show the Antuna a playing Tuning above the sources, each with its spinner or count.

#### Scenario: Sources loading
- **GIVEN** the user has sources and none has finished loading
- **WHEN** they open Antuna on an iPhone
- **THEN** the a above the sources leans its antennae while each source shows a spinner or its count

#### Scenario: Channels arrive
- **GIVEN** the loading list with the mark tuning
- **WHEN** the first source's channels arrive
- **THEN** the channel list replaces the loading list at once
