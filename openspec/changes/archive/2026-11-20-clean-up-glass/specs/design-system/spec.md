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
