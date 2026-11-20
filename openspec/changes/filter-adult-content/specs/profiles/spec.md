# Spec Delta

## MODIFIED Requirements

### Requirement: What each profile keeps
The system SHALL keep favorites, hidden groups, watch progress, My list, recent searches, recently watched and whether adult content shows per profile and sync them per profile, and SHALL keep the last channel and the sound and subtitle picks per channel per profile on each device. A new profile SHALL start with adult content hidden.

#### Scenario: Favorites apart
- **GIVEN** Dad favorited Sport One and Kids favorited Cartoon Club
- **WHEN** each opens Favorites, or the overlay's Favorites group
- **THEN** Dad sees only Sport One and Kids only Cartoon Club

#### Scenario: Hidden groups apart
- **GIVEN** Kids hid every group but Kids
- **WHEN** Dad opens the channel list
- **THEN** Dad sees every group

#### Scenario: Last channel apart
- **GIVEN** Dad last watched News 24 and Kids last watched Cartoon Club on this Apple TV
- **WHEN** Kids is chosen at launch
- **THEN** Cartoon Club plays

#### Scenario: Language picks apart
- **GIVEN** Dad picked German sound on Sport One on this device
- **WHEN** Kids tunes Sport One on the same device
- **THEN** it starts by Kids's preferences, not with German sound

#### Scenario: Adult content apart
- **GIVEN** Dad turned on Show adult content with the passcode
- **WHEN** the Apple TV switches to Kids, or a new profile is added
- **THEN** that profile hides adult content
- **AND** Dad's other devices show adult content in Dad's profile without asking again
