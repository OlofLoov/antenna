## MODIFIED Requirements

### Requirement: My list from the page
The system SHALL add a title to My list or remove it when the user presses My list, keeping the page and the banner in agreement and the list matching the button however fast the user presses. The button SHALL say what it does in words, "Add to My list" or "Remove from My list", with no glyph, on every platform.

#### Scenario: Add and remove
- **GIVEN** a title not in My list
- **WHEN** the user presses My list on its page, and presses it again
- **THEN** the first press adds it, the button reads "Remove from My list", and the banner's My list button agrees
- **AND** the second removes it and both read "Add to My list" again
- **AND** however fast the user presses, the list ends up matching the button

#### Scenario: Words, not a plus
- **WHEN** a title's page shows on iPhone, iPad, Mac or Apple TV
- **THEN** My list reads "Add to My list" in the same style as Trailer beside it, with no plus or check

#### Scenario: iPhone
- **WHEN** a title's page shows on iPhone
- **THEN** Play spans the width, and My list and Trailer sit under it with their words in full

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on and the title is in My list
- **WHEN** it reads the button
- **THEN** it says "Remove from My list, On My list"
