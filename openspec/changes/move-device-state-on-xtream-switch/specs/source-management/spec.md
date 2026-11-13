## ADDED Requirements

### Requirement: Switching to Xtream keeps what was remembered per channel
When a playlist source switches to Xtream, the system SHALL move each live channel it can map to an Xtream id in Recents and the last channel on this device, in the sound and subtitle picks on this device, and in the hand-picked guide matches, for every profile. A channel it cannot map SHALL keep its old id. Nothing moved SHALL hold a stream link or a login.

#### Scenario: Recents and the last channel
- **GIVEN** a panel playlist with "News 24" in Recents and as the last channel on this Apple TV
- **WHEN** the user switches the source to Xtream
- **THEN** "News 24" is still in Recents and the Apple TV opens on it at the next launch

#### Scenario: Language picks
- **GIVEN** the user picked Spanish sound on "Sports 1" of a panel playlist
- **WHEN** the source switches to Xtream and the user plays "Sports 1" again
- **THEN** it starts with Spanish sound

#### Scenario: Guide matches
- **GIVEN** a hand-picked guide match on "News 24" of a panel playlist
- **WHEN** the source switches to Xtream
- **THEN** "News 24" shows the same guide on every device

#### Scenario: A movie entry
- **GIVEN** a movie entry of the playlist in Recents
- **WHEN** the source switches to Xtream
- **THEN** the entry keeps its old id and nothing stored holds its link
