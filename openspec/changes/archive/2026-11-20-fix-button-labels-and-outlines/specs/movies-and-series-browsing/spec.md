## MODIFIED Requirements

### Requirement: Keep a list for later
The system SHALL add a title to My list from the banner button or the poster's menu, offer removal in both places once added, show it in the My list row latest first, and undo both on removal. The banner button SHALL read "Add to My list" or "Remove from My list", in words with no glyph.

#### Scenario: Adding to My list
- **GIVEN** a title that is not in My list
- **WHEN** the user adds it with the banner's My list button or from the poster's menu
- **THEN** the button and menu offer to remove it instead, the button reading "Remove from My list"
- **AND** the My list row appears or gains the title, latest additions first

#### Scenario: Removing from My list
- **GIVEN** a title in My list
- **WHEN** the user removes it
- **THEN** the button and menu offer to add it again, and the title leaves the row

#### Scenario: A change on another device
- **GIVEN** the section is open
- **WHEN** My list or a saved position changes on another device
- **THEN** the open section shows the change without reopening it

#### Scenario: Words on every platform
- **WHEN** the banner shows on iPhone, iPad, Mac or Apple TV
- **THEN** My list reads "Add to My list" in the same style as More info, with no plus or check

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
- **THEN** Play and Info take the first row, and Trailer, with its glyph and the word "Trailer", and My list take the second, all within the screen width
