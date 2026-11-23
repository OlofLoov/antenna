# browse-by-person Specification

## Purpose
Lets movie and series watchers see everything their own sources have with an actor or director: from a name on a title page or from Search, a person's page lists their movies and series that the user can play. People are matched by the names the provider sends.

## Requirements

### Requirement: Pick someone in the cast
The system SHALL show the cast and directors the provider gives for a title as names the user can select, at most 15, the cast in the provider's order and the directors last, each opening that person's page, on iPhone, iPad, Mac and Apple TV. Names the provider leaves blank or fills with placeholders SHALL not show.

#### Scenario: A movie with a cast
- **GIVEN** a movie whose provider gives the cast "Mira Holt, Jonas Reeve" and the director "Sanna Weiss"
- **WHEN** the user selects "Mira Holt" under Cast and crew on its page
- **THEN** Mira Holt's page opens

#### Scenario: No names
- **GIVEN** a title whose provider gives no cast or director, or only "N/A"
- **WHEN** its page shows
- **THEN** there is no Cast and crew row

#### Scenario: A long cast
- **GIVEN** a series whose provider lists 30 cast names and one director
- **WHEN** its page shows
- **THEN** the first 14 cast names show, then the director

#### Scenario: Apple TV focus
- **GIVEN** a title page with names on Apple TV
- **WHEN** the user moves down from the buttons
- **THEN** focus lands on the first name, and left and right move along the names

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** it reaches a name
- **THEN** it reads the name, "Director" for a director, and "button"

#### Scenario: Right-to-left
- **GIVEN** the app in Arabic
- **WHEN** a title page shows Latin names
- **THEN** each name reads left to right inside its chip, untranslated, and the chips run from the right

### Requirement: The same person across titles
The system SHALL treat two names as the same person when they are equal once case, accents, dots and extra spaces are ignored, SHALL split a provider's list at commas, slashes, vertical bars, semicolons and line breaks, and SHALL show a person under the spelling of the first title that names them.

#### Scenario: Case and accents
- **GIVEN** one movie lists "Zoë Brandt" and another "ZOE BRANDT"
- **WHEN** the user opens Zoë Brandt's page
- **THEN** both movies are on it

#### Scenario: Other separators
- **GIVEN** a cast written "Mira Holt / Jonas Reeve | Adaeze Okafor"
- **WHEN** the title page shows
- **THEN** it shows three names

#### Scenario: A part in brackets
- **GIVEN** a cast entry "Jonas Reeve (voice)"
- **WHEN** the title page shows
- **THEN** the name reads "Jonas Reeve" and matches his other titles

### Requirement: A person's page
The system SHALL open a person's page showing their initials, name, whether they mostly act or direct, and how many titles the user's sources have with them, with rows for the movies and series they acted in and the titles they directed, newest first, each row hidden when empty, on iPhone, iPad, Mac and Apple TV.

#### Scenario: An actor with films and a series
- **GIVEN** an actor named in 6 movies and 3 series of the user's sources
- **WHEN** the user opens their page
- **THEN** it shows their initials, their name, "Acting · 9 in your sources", a Movies row of the 6 and a Series row of the 3, newest first, and no Directed row

#### Scenario: Only the title they came from
- **GIVEN** a person named only in the movie whose page the user came from
- **WHEN** their page opens
- **THEN** it shows "Acting · 1 in your sources" and that movie, and the note that titles whose names Antuna has not seen yet may be missing

#### Scenario: Selecting a poster
- **GIVEN** a person's page
- **WHEN** the user selects a poster
- **THEN** the title's page opens, as from any poster

#### Scenario: Going back
- **GIVEN** a person's page opened from a title page or from Search
- **WHEN** the user goes back with Menu, the back button, Escape or an edge swipe
- **THEN** they return there with the name they picked in view, focused on Apple TV

#### Scenario: Apple TV focus
- **GIVEN** a person's page on Apple TV
- **WHEN** it opens
- **THEN** the first poster of the first row has focus, and the tab bar stays hidden as on a title page

#### Scenario: Right-to-left
- **GIVEN** the app in Arabic
- **WHEN** a person's page shows a Latin name
- **THEN** the name reads left to right, untranslated, and the count line around it is in Arabic

### Requirement: Only titles your sources have
The system SHALL list on a person's page only titles the user's loaded sources have, each once per source, and SHALL leave out titles whose source is gone.

#### Scenario: A source removed
- **GIVEN** a person named in titles from two sources, and one source is deleted
- **WHEN** their page opens
- **THEN** only the other source's titles show

#### Scenario: Nothing left
- **GIVEN** a person whose only titles have left the user's sources
- **WHEN** their page opens
- **THEN** it shows their name and "Nothing with Mira Holt in your sources."

### Requirement: A person's page never asks the provider
The system SHALL build a person's page from names the provider has already sent, in its movie and series lists or in details the app asked for to show a banner, a preview or a title page, and SHALL make no request to the provider to build it.

#### Scenario: A large catalogue
- **GIVEN** a source with 40,000 movies
- **WHEN** the user opens a person's page
- **THEN** the provider receives no request

#### Scenario: Names in the list
- **GIVEN** a panel whose series list gives each series' cast
- **WHEN** the user opens an actor's page without having opened any series
- **THEN** every series that lists the actor is on it

#### Scenario: Names from details
- **GIVEN** a panel whose movie list has no cast, and the user has opened three movies with Mira Holt
- **WHEN** the user opens her page
- **THEN** those three movies are on it, with the note that titles whose names Antuna has not seen yet may be missing

#### Scenario: Offline
- **GIVEN** the device is offline
- **WHEN** the user opens a person's page
- **THEN** it shows the titles from names already received, as online

### Requirement: Names the provider sent are kept
The system SHALL keep the cast and directors from details answers on the device for 30 days after the answer arrived, so a person's page lists those titles after the app restarts, and SHALL drop the names of a source when it is deleted.

#### Scenario: After a restart
- **GIVEN** the user opened a movie with Mira Holt yesterday
- **WHEN** the app restarts and the user opens Mira Holt's page from another title
- **THEN** yesterday's movie is on it

### Requirement: Find a person in Search
The system SHALL add a People section to Search results, listing up to three people whose names have a word starting with each typed word, among the names the provider has sent, ordered by how many titles the sources have with them, each with initials, name and count, and SHALL send nothing anywhere to fill it.

#### Scenario: Typing a name
- **GIVEN** Mira Holt is named in 9 titles
- **WHEN** the user types "mira h"
- **THEN** a People section lists Mira Holt with "Acting · 9 in your sources", and picking her opens her page

#### Scenario: Nobody by that name
- **GIVEN** no name the provider sent matches the text
- **WHEN** the results show
- **THEN** there is no People section

#### Scenario: Narrowed to one kind
- **GIVEN** the user picked the Movies chip
- **WHEN** results show
- **THEN** there is no People section
