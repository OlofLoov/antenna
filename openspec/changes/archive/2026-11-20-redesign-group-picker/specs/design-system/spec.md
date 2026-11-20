# Spec Delta

## MODIFIED Requirements

### Requirement: Layouts mirror in right-to-left languages
In a right-to-left language every screen MUST mirror its horizontal layout:
what sits at the leading edge in English sits at the right edge, rows and
chips run from the right, and back and disclosure arrows point the other
way. Photos, posters, channel logos and the video picture MUST NOT be
flipped.

#### Scenario: A channel row in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the viewer opens the Live list on any platform
- **THEN** each row reads from the right in the order the English row reads from the left
- **AND** on iPhone, iPad and Mac that is the logo tile, the name with its channel number after it, the current programme and progress bar
- **AND** on Apple TV that is the channel number, logo tile, name, current programme and progress bar
- **AND** the catch-up glyph sits at the row's left edge

#### Scenario: Group chips in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer looks at the day chips in the Guide or the genre chips in Movies
- **THEN** the first chip is at the right and the chips scroll toward the left

#### Scenario: The group button and sheet in Arabic
- **GIVEN** the app is in Arabic on iPhone
- **WHEN** the viewer looks at the group button above the Live list and opens it
- **THEN** the group's name starts at the right with the count and chevron to its left
- **AND** in the Groups sheet each row reads from the right, with the checkmark at the right and the count at the left

#### Scenario: A channel logo with text in it
- **GIVEN** the app is in Arabic
- **WHEN** a channel logo that contains Latin letters is shown
- **THEN** the logo is drawn as supplied, not mirrored

#### Scenario: The Apple TV channel overlay
- **GIVEN** the app is in Arabic on Apple TV
- **WHEN** the viewer opens the channel overlay
- **THEN** the groups column is at the right, the channels in the middle and now and next at the left
