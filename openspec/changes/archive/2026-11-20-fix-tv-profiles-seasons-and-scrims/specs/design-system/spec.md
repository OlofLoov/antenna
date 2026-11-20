## ADDED Requirements

### Requirement: The scrim blends into the art
Where copy sits over a picture, on the Movies and Series banner, the Apple
TV preview and the title pages, the darkening behind it MUST span the whole
picture and change smoothly, darkest under the copy and lighter away from
it, with no edge inside the picture. It MUST sit under the copy in
right-to-left languages too.

#### Scenario: The Apple TV banner
- **WHEN** the viewer opens Movies or Series on Apple TV
- **THEN** the banner art darkens gradually from the left edge toward the right, with no line where the darkening stops

#### Scenario: The iPhone banner
- **WHEN** the user opens Movies on iPhone
- **THEN** the band under the copy fades into the art above it, with no line across the picture

#### Scenario: A title page in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the viewer opens a title page on Apple TV, iPad or Mac
- **THEN** the darkest part of the backdrop is at the right, under the copy
