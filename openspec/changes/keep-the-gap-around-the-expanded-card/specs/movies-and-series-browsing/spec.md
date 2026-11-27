## MODIFIED Requirements

### Requirement: Expanded card for the focused title on Apple TV
On Apple TV only, the poster with the highlight in a row of Movies or Series SHALL grow at once into a landscape card the height of a poster, with the posters after it moving aside. The card SHALL show the title's picture, category and name at once, and its facts and up to two lines of plot once the provider has answered. The provider SHALL be asked only once the highlight has rested on a title for 0.8 seconds. The focused row SHALL rest just under the tab bar with the rows below it in view.

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
- **AND** that poster is at the same position in its row as the one they left, or the row's last poster when the row is shorter

#### Scenario: Down the rows and back up
- **GIVEN** the highlight is on the first poster of Recently added
- **WHEN** the viewer moves down six rows and back up six
- **THEN** the highlight is on the first poster of Recently added again

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

#### Scenario: The card keeps the row's spacing
- **GIVEN** the highlight is on a poster in the middle of a row
- **WHEN** the poster has grown into its card
- **THEN** the gap between the card and the poster before it, and between the card and the poster after it, is the gap between any two posters in the row

#### Scenario: The highlight is the card
- **WHEN** a poster grows into its card, or the card goes as the highlight leaves
- **THEN** the lift and shadow of the highlight are the card's own and wrap the card as it is drawn
- **AND** no lift, edge or shadow at the poster's size shows around or under the card
