## ADDED Requirements

### Requirement: The loading screen tunes in
The loading screen at launch SHALL show the Antuna wordmark playing Tuning above the list of sources, for as long as the screen shows. The rows keep their own spinners and counts.

#### Scenario: Sources loading at launch
- **GIVEN** the user has sources and none has finished loading
- **WHEN** they open Antuna on Apple TV
- **THEN** the wordmark above the list leans its antennae while each row shows how far its source has got

#### Scenario: The first channel starts
- **GIVEN** the loading screen with the mark tuning
- **WHEN** a channel starts playing
- **THEN** the loading screen and its mark go at once, with no wait for the mark
