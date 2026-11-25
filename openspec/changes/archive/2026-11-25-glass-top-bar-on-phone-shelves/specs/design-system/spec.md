## MODIFIED Requirements

### Requirement: Liquid Glass stays on the navigation layer
Tab bars, toolbars, floating controls over video, and buttons in sheets MUST
use Liquid Glass through the system components or the glass effect. Rows,
cards, posters, the guide grid and other content MUST NOT use glass; panels
in the content layer use the materials in the reference. Glass MUST NOT sit
on glass. A glass element MUST NOT also have a fill, a stroke or border, or a
shadow of its own; the system draws its edge and highlight. An element is
either glass or a plain surface, never both.

#### Scenario: The player controls over video
- **WHEN** the player controls show over a playing picture on iPhone, iPad or Mac
- **THEN** the buttons sit on glass and the picture shows through them

#### Scenario: Glass on a content card
- **WHEN** a reviewer finds the glass effect on a row, poster or guide block
- **THEN** it fails this requirement

#### Scenario: Glass is never combined with a fill or a stroke
- **WHEN** a reviewer finds a glass button, capsule or card that also draws a background color, an outline or a drop shadow
- **THEN** it fails this requirement

#### Scenario: Round buttons over the picture look alike
- **GIVEN** a title is playing full screen on iPhone, iPad or Mac with the controls shown
- **WHEN** the viewer looks at Close, the track buttons and the skip and pause buttons
- **THEN** each one sits on glass with the same edge, and none is a dark disc

#### Scenario: The top bar of Movies and Series on iPhone
- **WHEN** the user scrolls Movies or Series on iPhone
- **THEN** the genre button in the top bar is a glass capsule with no fill or outline of its own
- **AND** the bar behind it is clear, with the system's blur over the posters passing under it and no glass of its own

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
- **AND** the top of the picture, above the band, is not darkened

#### Scenario: The iPhone header on a white picture
- **GIVEN** the banner shows a title whose picture is white at the top
- **WHEN** the user opens Series or Movies on iPhone
- **THEN** "Series" or "Movies" and "All series" or "All movies" sit in the top bar above the picture, not on it
- **AND** the white top of the picture shows as it is, with no band over it

#### Scenario: A title page in Arabic
- **GIVEN** the app is in Arabic
- **WHEN** the viewer opens a title page on Apple TV, iPad or Mac
- **THEN** the darkest part of the backdrop is at the right, under the copy
