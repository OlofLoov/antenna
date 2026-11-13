## MODIFIED Requirements

### Requirement: One accent color
The accent blue from the reference MUST be the only accent color. It SHALL
appear only on progress fills, the guide's now line, the NOW and UP NEXT
badges, links, the selected iPhone tab and the app icon. Nothing else is
tinted.

#### Scenario: A tinted icon
- **WHEN** a reviewer finds an icon or label tinted in a color other than the accent
- **THEN** it fails this requirement

#### Scenario: Accent on a decorative element
- **WHEN** the accent appears on something that is not progress, the now line, a NOW or UP NEXT badge, a link, the selected iPhone tab or the app icon
- **THEN** it fails this requirement

#### Scenario: The app icon
- **WHEN** a reviewer checks the app icon
- **THEN** its mark is in the accent blue on the ground color, and no other color appears in it
