## MODIFIED Requirements

### Requirement: What the title is about
The system SHALL show a title's backdrop, year, length or seasons, genre, rating, badges, description, cast and director once the details arrive, and SHALL leave out any field the provider does not give. Every word of the description, cast and director SHALL be reachable: on Apple TV through More, which opens them on a page of their own, and elsewhere by expanding in place. The backdrop SHALL keep its proportions and show whole, or lose at most 8% at two edges to fill its area.

#### Scenario: A movie with full details
- **GIVEN** a movie whose details include year 2024, a length of 2 h 08 min, genre Thriller, rating 7.4, age rating 15, a "2160p" name, a description, cast and a director
- **WHEN** the details arrive
- **THEN** the page shows the backdrop, year, length, genre, rating and the age and 4K badges, the description cut to a few lines with More, and the cast and director

#### Scenario: More on Apple TV
- **GIVEN** a title page on Apple TV whose description runs past its lines
- **WHEN** the viewer moves up to More and presses select
- **THEN** a full-screen page shows the name, the details line, the whole description, the cast and the director over the blurred title page
- **AND** swiping down and up scrolls a text longer than the screen
- **AND** Menu closes it and focus is back on More

#### Scenario: More on iPhone, iPad and Mac
- **GIVEN** a title page whose description runs past its lines
- **WHEN** the user taps or clicks More
- **THEN** the description shows in full in place, and so do the cast and director

#### Scenario: No backdrop
- **GIVEN** a title whose provider gives a poster but no backdrop
- **WHEN** its page shows
- **THEN** the poster sits on black where the backdrop would be

#### Scenario: A 16:9 backdrop on iPhone
- **GIVEN** a title whose backdrop is 16:9
- **WHEN** its page shows on an iPhone
- **THEN** the backdrop spans the screen's width at 16:9 directly under the status bar, with nothing of it cut or covered
- **AND** a blurred copy of it fills the status bar band and fades into the page below the picture

#### Scenario: A 16:9 backdrop on iPad and Mac
- **GIVEN** a title whose backdrop is 16:9
- **WHEN** its page shows on an iPad or a Mac
- **THEN** the card is 16:9 for its width, between 380 and 560 points tall, and the backdrop shows whole
- **AND** in a window wide enough to hold the card at 560 the backdrop sits against the right, fading into its blurred copy under the copy

#### Scenario: A series on Apple TV
- **GIVEN** a series whose backdrop is 16:9
- **WHEN** its page shows on Apple TV, with the backdrop in the band above the episodes
- **THEN** the backdrop shows whole at the right of the band over a blurred copy of itself, never cut to a strip of its middle

#### Scenario: A poster sent as the backdrop
- **GIVEN** a title whose provider's backdrop is a tall picture, such as its poster
- **WHEN** its page shows
- **THEN** the whole picture shows with rounded corners over a blurred copy of itself, never enlarged to a strip of its middle
- **AND** on iPhone it sits in the middle of the 16:9 area, nearly its full height; on iPad, Mac and Apple TV it sits at the right

#### Scenario: Missing fields
- **GIVEN** a title whose provider leaves fields out
- **WHEN** the details arrive
- **THEN** a missing field is simply missing, never "Unknown"

#### Scenario: A series
- **WHEN** a series' details arrive
- **THEN** it shows its number of seasons instead of a length, counted from what the episodes say when they disagree with the provider's season count

#### Scenario: Large text and VoiceOver
- **GIVEN** a large text size and VoiceOver on
- **WHEN** the page shows
- **THEN** the details line wraps, and VoiceOver reads the name, the details, then the description

## ADDED Requirements

### Requirement: The page shows in one go
The system SHALL keep a title page hidden while its details load and SHALL show it whole, with a short fade, once they arrive or fail. A load longer than 0.3 seconds SHALL show the Antuna mark tuning in the middle of the screen until then, and Got it before the page. Back SHALL stay reachable meanwhile.

#### Scenario: A slow load
- **GIVEN** a series whose provider takes half a second to answer
- **WHEN** the user opens its page
- **THEN** the mark tunes on the ground, with no name, details, buttons or episodes
- **AND** when the details arrive the mark plays Got it and the whole page fades in, episodes included

#### Scenario: A fast load
- **GIVEN** a title whose details arrive within 0.3 seconds
- **WHEN** the user opens its page
- **THEN** the page fades in whole and the mark never shows

#### Scenario: Details already known
- **GIVEN** a title whose details the banner, the preview or an earlier visit already asked for
- **WHEN** the user opens its page
- **THEN** the page shows at once

#### Scenario: The details fail
- **GIVEN** a title whose provider fails to answer
- **WHEN** the load ends
- **THEN** the page shows with what is known and "Could not load details" with Try again, as before

#### Scenario: Going back while it loads
- **GIVEN** a page whose details are still loading
- **WHEN** the user taps Back on iPhone or iPad, swipes from the edge, or presses Menu on Apple TV
- **THEN** the page closes

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion on
- **WHEN** a page loads slowly
- **THEN** the mark shows still or fades as it does elsewhere, and the page still waits for its details
