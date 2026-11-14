## ADDED Requirements

### Requirement: Rating and trailer on the banner
The system SHALL show the provider's rating in the banner's facts line, written as a star and the number out of ten with one decimal, and SHALL offer a Trailer button on the banner whenever the title's page would offer one, opening the trailer the same way the page does.

#### Scenario: A rated movie
- **GIVEN** the banner shows a movie the provider rates 7.4, from 2024, 2 h 08 min long
- **WHEN** the banner shows it
- **THEN** the facts line reads "2024 · 2 h 08 min · ★ 7.4", followed by its badges

#### Scenario: Rating before the details arrive
- **GIVEN** the provider's list gives a title a rating and its info call has not answered
- **WHEN** the banner shows the title
- **THEN** the rating shows at once, and the year and length join it when the info call answers

#### Scenario: No rating
- **GIVEN** the provider sends no rating, or a rating of 0
- **WHEN** the banner shows the title
- **THEN** the facts line has no star and no placeholder

#### Scenario: VoiceOver reads the rating
- **GIVEN** VoiceOver is on
- **WHEN** it reads the banner's facts line for a title rated 7.4
- **THEN** it says "rated 7.4 out of 10"

#### Scenario: A trailer on iPhone, iPad or Mac
- **GIVEN** the provider gives the banner title a trailer link, a YouTube page included
- **WHEN** the user presses Trailer on the banner on iPhone, iPad or Mac
- **THEN** the link opens outside the app

#### Scenario: A playable trailer on Apple TV
- **GIVEN** the banner title's trailer link points at a video file or an HLS stream
- **WHEN** the viewer selects Trailer on the banner on Apple TV
- **THEN** the trailer plays full screen, and Menu or its end goes back to the banner with Trailer highlighted, without saving a place in Continue watching

#### Scenario: A YouTube trailer on Apple TV
- **GIVEN** the banner title's trailer link is a YouTube page
- **WHEN** the banner shows it on Apple TV
- **THEN** there is no Trailer button, as on the title page

#### Scenario: Paging past a title with a trailer
- **GIVEN** the banner shows a title with a Trailer button and the next title has none
- **WHEN** the viewer pages to the next title from My list on Apple TV
- **THEN** the Trailer button goes, My list keeps the highlight, and paging right from My list still works

#### Scenario: The trailer link arrives late
- **GIVEN** the highlight is on My list and the title's info call has not answered
- **WHEN** the answer arrives with a trailer link
- **THEN** Trailer appears before My list and the highlight stays on My list

#### Scenario: iPhone
- **WHEN** the banner shows a title with a trailer on iPhone
- **THEN** Trailer is a button with the trailer glyph and the spoken label "Trailer", between Info and My list, and the four buttons fit the screen width
