## ADDED Requirements

### Requirement: Preview of the focused title on Apple TV
On Apple TV the system SHALL show, at the top of Movies and Series while the highlight is in a row, a preview of the title the highlight rests on: its picture, name, category, facts and up to three lines of its plot, with the focused row just below. The preview SHALL change only after the highlight has stayed on a poster for 0.8 seconds, and SHALL fade from one title to the next. iPhone, iPad and Mac SHALL show no preview.

#### Scenario: Resting on a poster
- **GIVEN** the viewer is on Movies on Apple TV with the highlight on the banner
- **WHEN** they move down to a poster in Recently added and stay on it
- **THEN** the banner scrolls away, the row moves up under the top of the screen, and 0.8 seconds later the top shows that title's backdrop, name, category, year, length and plot

#### Scenario: Moving quickly along a row
- **GIVEN** the preview shows a title
- **WHEN** the viewer swipes across ten posters without stopping and stops on the eleventh
- **THEN** the preview keeps the first title until the eleventh has been focused for 0.8 seconds, then fades to it
- **AND** the provider is not asked about the ten posters passed on the way

#### Scenario: Moving to another row
- **WHEN** the viewer moves down from one row to the next
- **THEN** the new row takes the place just under the preview, the row above leaves the screen, and the preview changes once the highlight rests

#### Scenario: Details still loading
- **GIVEN** the provider has not answered for the title the highlight rests on
- **WHEN** the preview changes to it
- **THEN** the name and category show at once, the previous picture stays until the new one is ready or 1.5 seconds pass, and the facts and plot fade in when the provider answers

#### Scenario: A title with only a poster
- **GIVEN** the provider sends no backdrop for the focused title
- **WHEN** the preview shows it
- **THEN** the whole poster shows at the right of the preview over a blurred copy of itself, as on the banner

#### Scenario: The details fail or the device is offline
- **GIVEN** the provider fails to answer for the focused title, or the Apple TV is offline
- **WHEN** the preview shows it
- **THEN** it shows the name, the category and the poster, and no error
- **AND** the poster can still be played or opened

#### Scenario: A playlist title
- **GIVEN** the focused title comes from an M3U playlist
- **WHEN** the preview shows it
- **THEN** it shows the name, the group and the logo or poster, and the provider is not asked

#### Scenario: Continue watching
- **GIVEN** the highlight rests on an episode in Continue watching
- **WHEN** the preview shows it
- **THEN** it shows the series' backdrop, name and plot

#### Scenario: Back to the banner
- **GIVEN** the preview shows a title
- **WHEN** the viewer moves up from the first row
- **THEN** the preview fades out, the banner scrolls back with the title it showed before, and the highlight is on Play

#### Scenario: Menu from a row
- **GIVEN** the preview shows a title
- **WHEN** the viewer presses Menu
- **THEN** the rows scroll back to the top with the banner showing and the highlight moves to the tab bar

#### Scenario: Back from a title page
- **GIVEN** the viewer opened a title page from a poster with the preview showing
- **WHEN** they press Menu on the page
- **THEN** the same poster has the highlight and its preview shows at once, without waiting

#### Scenario: Genres row
- **WHEN** the viewer moves down to the Genres row
- **THEN** the preview keeps the last title it showed

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the highlight rests on a poster whose plot is known
- **THEN** VoiceOver reads the poster's name, year and minutes left as before, then the plot as its hint

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the highlight moves between rows
- **THEN** the rows move into place without sliding, and the preview still fades between titles

#### Scenario: iPad
- **WHEN** the viewer moves the pointer over posters on iPad or Mac
- **THEN** no preview shows and the banner does not change

### Requirement: Title details are asked once per title
The system SHALL ask the provider for a title's details at most once per launch for the banner and the preview together, one preview request at a time, and SHALL use that answer when the title's page opens. Retry on a page SHALL ask again.

#### Scenario: Banner, preview and page
- **GIVEN** a title was shown in the banner, so its details were asked for
- **WHEN** the viewer rests on its poster and then opens its page
- **THEN** the provider is asked once in all, and the page shows the details without loading

#### Scenario: Resting on several posters
- **GIVEN** the provider answers slowly
- **WHEN** the viewer rests on three posters in turn before the first answer arrives
- **THEN** the first request finishes, the second poster is skipped, and the third is asked about next

#### Scenario: Retry on a page
- **GIVEN** a title's details failed for its preview
- **WHEN** the viewer opens its page and presses Retry
- **THEN** the provider is asked again
