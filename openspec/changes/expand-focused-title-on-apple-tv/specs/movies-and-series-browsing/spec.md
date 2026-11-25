## RENAMED Requirements

- FROM: `### Requirement: Preview of the focused title on Apple TV`
- TO: `### Requirement: Expanded card for the focused title on Apple TV`

## MODIFIED Requirements

### Requirement: Rows in a predictable order
The system SHALL show, after Continue watching and My list, Recently watched, Recently added newest first and one row per category that has titles in the provider's order, each headed with its name and number of titles, leaving out a row with nothing in it.

#### Scenario: Provider categories
- **GIVEN** the provider's movies and categories
- **WHEN** the user opens Movies
- **THEN** after Continue watching and My list come Recently watched, Recently added, newest first, and one row per category that has titles, in the provider's order
- **AND** each row is headed with its name and number of titles

#### Scenario: Rows with nothing in them
- **GIVEN** a profile that has watched nothing
- **WHEN** the user opens Movies
- **THEN** there is no Recently watched row, and Recently added follows My list

#### Scenario: Two sources with the same category
- **GIVEN** two Xtream sources share a category name
- **WHEN** the rows show
- **THEN** their titles merge into one row

#### Scenario: Thousands of categories
- **GIVEN** the provider has thousands of categories
- **WHEN** the user scrolls
- **THEN** rows load as they scroll into view and only visible rows fetch posters

#### Scenario: Missing or broken poster
- **GIVEN** a title's poster is missing or broken
- **WHEN** its poster shows
- **THEN** the title's name shows on a plain tile, never an empty frame

#### Scenario: A poster still loading
- **GIVEN** a title's poster is not in memory yet
- **WHEN** its card shows
- **THEN** the card holds a quiet shape the size of the poster, with no name on it
- **AND** the poster fades in over about 0.2 seconds when it arrives, or appears at once with Reduce Motion on

#### Scenario: A poster already in memory
- **GIVEN** a title's poster is in memory, as when the viewer scrolls back to it or it loaded ahead
- **WHEN** its card shows
- **THEN** the poster shows in the card's first frame, with no shape before it and no fade

#### Scenario: Entries without a name or id
- **GIVEN** the provider lists entries without a name or id
- **WHEN** the rows fill
- **THEN** those entries are skipped

#### Scenario: VoiceOver reads a poster
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a poster
- **THEN** it is read as title, year and, when in progress, the minutes left

### Requirement: Expanded card for the focused title on Apple TV
On Apple TV the poster with the highlight in a row of Movies or Series SHALL grow at once into a landscape card the height of a poster, with the posters after it moving aside. The card SHALL show the title's picture, category and name at once, and its facts and up to two lines of plot once the provider has answered. The provider SHALL be asked about a title only after the highlight has stayed on it for 0.8 seconds. No preview SHALL show at the top of the section, and the focused row SHALL rest just under the tab bar with the rows below it in view. iPhone, iPad and Mac SHALL show no expanded card.

#### Scenario: Resting on a poster
- **GIVEN** the viewer is on Movies on Apple TV with the highlight on the banner
- **WHEN** they move down to a poster in Recently added and stay on it
- **THEN** the banner scrolls away, the row rests just under the tab bar with the next rows below it, and the poster grows into a card with the title's category and name
- **AND** 0.8 seconds later the provider is asked, and its backdrop, year, length and plot fade into the card when it answers

#### Scenario: Moving quickly along a row
- **GIVEN** the highlight is on a poster in a row
- **WHEN** the viewer swipes across ten posters without stopping and stops on the eleventh
- **THEN** each poster grows into a card while it has the highlight and shrinks back as it leaves
- **AND** the provider is asked only about the eleventh, once it has had the highlight for 0.8 seconds

#### Scenario: Moving to another row
- **WHEN** the viewer moves down from one row to the next
- **THEN** the card in the row they left shrinks back to a poster, the new row comes up to rest under the tab bar, and the poster they land on grows into a card

#### Scenario: Moving up to the row above
- **GIVEN** the highlight is in a row below the first
- **WHEN** the viewer moves up to the row above, once or twice in quick succession
- **THEN** that row comes down in one movement and rests whole just under the tab bar, as a row does after moving down

#### Scenario: Details still loading
- **GIVEN** the provider has not answered for the title the highlight is on
- **WHEN** the card grows
- **THEN** it shows the category, the name and the poster, whole at its trailing side over a blurred copy of itself
- **AND** the facts and plot fade in under the name, and the backdrop over the poster, when the provider answers, without the card changing size

#### Scenario: A title with only a poster
- **GIVEN** the provider sends no backdrop for the focused title
- **WHEN** the card shows it
- **THEN** the poster stays whole at the card's trailing side over a blurred copy of itself, with the facts and plot beside it

#### Scenario: The details fail or the device is offline
- **GIVEN** the provider fails to answer for the focused title, or the Apple TV is offline
- **WHEN** the card shows it
- **THEN** it shows the category, the name and the poster, and no error
- **AND** the card can still be played or opened

#### Scenario: A playlist title
- **GIVEN** the focused title comes from an M3U playlist
- **WHEN** the card shows it
- **THEN** it shows the group, the name and the logo or poster, and the provider is not asked

#### Scenario: Continue watching
- **GIVEN** the highlight is on an episode in Continue watching
- **WHEN** it rests there
- **THEN** the card keeps its landscape size and progress bar, and no card in the row grows or shrinks

#### Scenario: Back to the banner
- **GIVEN** the highlight is on a card in the first row
- **WHEN** the viewer moves up
- **THEN** the card shrinks back to a poster, the banner scrolls back with the title it showed before, and the highlight is on Play

#### Scenario: Menu from a row
- **GIVEN** the highlight is on a card in a row
- **WHEN** the viewer presses Menu
- **THEN** the rows scroll back to the top with the banner showing and the highlight moves to the tab bar

#### Scenario: Back from a title page
- **GIVEN** the viewer opened a title page, or played a title, from a poster in a row
- **WHEN** they press Menu on the page, or leave playback
- **THEN** the same poster has the highlight and is a card at once, with the details it had, without waiting

#### Scenario: Genres row
- **WHEN** the viewer moves down to the Genres row
- **THEN** no card is expanded and the provider is not asked

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** the highlight rests on a card whose plot is known
- **THEN** VoiceOver reads the title's name, year and minutes left as before, then the plot as its hint

#### Scenario: Reduce Motion
- **GIVEN** Reduce Motion is on
- **WHEN** the highlight moves along a row or between rows
- **THEN** the card and the posters change size and place without sliding, and the rows move into place without sliding

#### Scenario: iPad
- **WHEN** the viewer moves the pointer over posters on iPad or Mac
- **THEN** no card grows and the banner does not change

### Requirement: Title details are asked once per title
The system SHALL ask the provider for a title's details at most once per launch for the banner, the Apple TV expanded card and a Continue watching card together, one request at a time for the cards, and SHALL use that answer when the title's page opens. Retry on a page SHALL ask again.

#### Scenario: Banner, preview and page
- **GIVEN** a title was shown in the banner, so its details were asked for
- **WHEN** the viewer rests on its poster and then opens its page
- **THEN** the provider is asked once in all, and the page shows the details without loading

#### Scenario: Resting on several posters
- **GIVEN** the provider answers slowly
- **WHEN** the viewer rests on three posters in turn before the first answer arrives
- **THEN** the first request finishes, the second poster is skipped, and the third is asked about next

#### Scenario: Retry on a page
- **GIVEN** a title's details failed for its expanded card
- **WHEN** the viewer opens its page and presses Retry
- **THEN** the provider is asked again

#### Scenario: A series in Continue watching
- **GIVEN** a series in Continue watching whose card shows its season and episode
- **WHEN** the viewer opens the series' page
- **THEN** the provider was asked about the series once in all
- **AND** a card whose episodes failed to load does not ask again each time it scrolls back into view

### Requirement: Browsing stays responsive
The system SHALL keep Movies and Series responding to the remote, touch and pointer for a library of 100 000 movies and 30 000 series whose rows name the cast: while it loads, while its rows and grids redraw in any order, and while details and saved positions arrive. Rows, banner, sorted grids and the people index SHALL be built away from the screen, and a redraw SHALL not walk every title. What a long session keeps in memory SHALL stay within fixed limits. Posters SHALL load ahead of where the viewer is going, so most posters the highlight or the scroll reaches are already there, and a poster that is not SHALL fade in when it arrives.

#### Scenario: A large library loads
- **GIVEN** a source with 100 000 movies
- **WHEN** its list arrives
- **THEN** the rows and the banner appear together without the screen freezing while they are built

#### Scenario: Progress saved while browsing
- **GIVEN** Movies is open on a library of 100 000 movies with titles in Continue watching
- **WHEN** a position is saved, on this device or from another one
- **THEN** Continue watching and Recently watched update without the screen pausing
- **AND** posters whose progress did not change are not drawn again

#### Scenario: All movies
- **GIVEN** a library of 100 000 movies
- **WHEN** the user opens All movies, or a genre, and moves through its grid
- **THEN** the grid is sorted once when it opens, not again as focus moves

#### Scenario: Sorting by title or year
- **GIVEN** a library of 100 000 movies on iPad or Mac
- **WHEN** the user picks Title or Year
- **THEN** the screen keeps responding while the order is worked out, and the grid shows in that order once it is ready

#### Scenario: A playlist series the kept load does not have
- **GIVEN** a playlist source whose kept load lacks a series the banner or a page asks about
- **WHEN** several such series are asked about within five minutes
- **THEN** the playlist is fetched again at most once in those five minutes

#### Scenario: A fast scroll past many posters
- **GIVEN** Movies is open on a large library whose posters load slowly
- **WHEN** the user flicks quickly through rows or a grid
- **THEN** posters that scrolled away stop downloading, and the posters on screen load next

#### Scenario: A drag that starts on the banner
- **GIVEN** Movies or Series is open on iPhone or iPad
- **WHEN** the user drags up from the banner to scroll the rows
- **THEN** the screen follows the finger, and the banner holds its title until the finger lifts

#### Scenario: Details arrive while a person's page or Search is open
- **GIVEN** a library of 100 000 movies and 30 000 series whose rows name the cast, with Search or a person's page open
- **WHEN** the banner turns, a card rests or a title page opens, each bringing a title's details
- **THEN** the names in those details reach the page and Search within a second, without every title being read again

#### Scenario: A large picture behind the banner
- **GIVEN** posters on screen and a title whose backdrop is a 4K picture
- **WHEN** the banner, the Apple TV expanded card or the title's page shows that picture
- **THEN** it is kept at the size of the window, and the posters on screen stay without loading again

#### Scenario: A full poster folder
- **GIVEN** the posters kept on the device reached their limit
- **WHEN** the user scrolls on to posters not seen before
- **THEN** the oldest posters go in one batch, not one at a time with each new poster

#### Scenario: A long evening on Apple TV
- **GIVEN** an Apple TV with a large library
- **WHEN** the viewer rests on hundreds of series in turn
- **THEN** episode lists are kept for the latest 100 series asked about and for series with saved progress, and the older ones are let go

#### Scenario: Moving through the rows on Apple TV
- **GIVEN** Movies or Series is open on Apple TV on a library of thousands of titles in dozens of rows
- **WHEN** the viewer moves across posters and up and down the rows
- **THEN** the banner and the rows are not drawn again for those moves, only the poster that loses the highlight and the one that gains it, and the screen when the highlight enters or leaves the rows

#### Scenario: Posters ahead of the highlight
- **GIVEN** Movies is open on a library of thousands of titles whose posters take a moment to arrive
- **WHEN** a poster in a row shows
- **THEN** the next three posters along that row in the direction it is scrolling start loading
- **AND** when a row shows, the posters the next row in the direction of the scroll shows first start loading: the row under it on the way down, the row above on the way up
- **AND** a row that has just come into view loads nothing along it until it has been in view for half a second
- **AND** on Apple TV, while the highlight rests on a poster, the rows above and below it load the posters around its column, which they show once the highlight moves into them
- **AND** they are decoded at the size of a card on screen, away from the screen, as the posters on screen are
- **AND** this holds on iPhone, iPad, Mac and Apple TV

#### Scenario: Posters kept in memory
- **GIVEN** an Apple TV 4K with a large library
- **WHEN** the viewer moves through dozens of rows
- **THEN** the decoded posters kept in memory stay under 50 MB, as on iPhone, iPad and Mac, each at the size its card shows it with no room for the focus lift
- **AND** the poster files kept on the device stay under 500 MB, so a poster that left memory decodes again from its file

#### Scenario: Moving along a row and down the rows on Apple TV
- **GIVEN** Apple TV on a library of 9 000 movies in 80 rows, with posters that each take a tenth of a second to arrive
- **WHEN** the viewer presses right ten times and left ten times, then moves down six rows and up six, without waiting
- **THEN** along the row at most one in ten of the posters that come into view is still loading when it appears
- **AND** down and up the rows fewer than half are, and each of those fades in when it arrives
- **AND** the screen, the banner and the rows are not drawn again for those moves
