## Purpose

Lets movie and series watchers see everything their own sources have with an actor or director: from a name on a title page or from Search, a person's page lists their movies and series that the user can play.

## ADDED Requirements

### Requirement: A person's page
The system SHALL open a person's page showing their photo or initials, name, main department and how many titles the user's sources have with them, with rows for the movies and series they acted in and the titles they directed, newest release first, each row hidden when empty, on iPhone, iPad, Mac and Apple TV.

#### Scenario: An actor with films and a series
- **GIVEN** an actor whose filmography has 40 movies and 5 series, of which the user's sources have 6 movies and 3 series
- **WHEN** the user opens their page
- **THEN** it shows their name, "Acting · 9 in your sources", a Movies row of the 6 and a Series row of the 3, newest release first, and no Directed row

#### Scenario: Selecting a poster
- **GIVEN** a person's page
- **WHEN** the user selects a poster
- **THEN** the title's page opens, as from any poster

#### Scenario: No photo
- **GIVEN** a person with no photo in the movie database
- **WHEN** their page shows
- **THEN** their initials show in the circle

#### Scenario: Going back
- **GIVEN** a person's page opened from a title page or from Search
- **WHEN** the user goes back with Menu, the back button, Escape or an edge swipe
- **THEN** they return there with the name they picked in view, focused on Apple TV

#### Scenario: Apple TV focus
- **GIVEN** a person's page on Apple TV
- **WHEN** it opens
- **THEN** the first poster of the first row has focus, and the tab bar stays hidden as on a title page

### Requirement: Only titles your sources have
The system SHALL list on a person's page only titles the user's loaded sources have, matched by the provider's database id or by cleaned-up name and year, each once, from the source first in the user's order, and SHALL never show a title no source has.

#### Scenario: A film not in any source
- **GIVEN** an actor's best-known film is in none of the user's sources
- **WHEN** their page shows
- **THEN** that film is not on it

#### Scenario: Nothing in the sources
- **GIVEN** a person with no title in the user's sources
- **WHEN** their page opens
- **THEN** it shows their name and "Nothing with Mira Holt in your sources."

#### Scenario: A playlist without ids
- **GIVEN** a playlist movie "EN | The Long Harbor (2024)" and an actor in that film
- **WHEN** the actor's page opens
- **THEN** the movie is in their Movies row

### Requirement: A person's page never asks the provider
The system SHALL build a person's page from the movie database and the titles already loaded, and SHALL make no request to the user's provider to build it.

#### Scenario: A large catalogue
- **GIVEN** a source with 40,000 movies
- **WHEN** the user opens a person's page
- **THEN** the provider receives no request, and one request goes to the movie database for the person's filmography

### Requirement: A person's filmography is kept on the device
The system SHALL keep a person's filmography on the device for seven days, show it at once when the page opens again, and when offline show what it kept or say it is offline with Retry.

#### Scenario: Opening a page again offline
- **GIVEN** a person's page opened yesterday, and the device now offline
- **WHEN** the user opens it again
- **THEN** it shows the same rows from what was kept

#### Scenario: Never opened and offline
- **GIVEN** a person whose page was never opened, and the device offline
- **WHEN** the user picks them
- **THEN** the page shows their name and "You're offline. Connect to the internet and try again." with Retry

#### Scenario: The database fails
- **GIVEN** the movie database answers with an error
- **WHEN** the user opens a person's page
- **THEN** it shows "Could not load this filmography" with Retry

### Requirement: Pick someone in the cast
The system SHALL show the cast and director of a matched title as names the user can select, at most 15 in billing order with the director last, each opening that person's page, and SHALL show the provider's cast as plain text for a title with no match or with lookups off.

#### Scenario: A matched movie
- **GIVEN** a movie matched to the movie database
- **WHEN** the user selects "Mira Holt" under Cast and crew on its page
- **THEN** Mira Holt's page opens

#### Scenario: No match
- **GIVEN** a title with no match, whose provider gives a cast
- **WHEN** its page shows
- **THEN** the cast and director show as text and cannot be selected

#### Scenario: Apple TV focus
- **GIVEN** a matched title's page on Apple TV
- **WHEN** the user moves down from the buttons
- **THEN** focus lands on the first name, and left and right move along the names

#### Scenario: VoiceOver
- **GIVEN** VoiceOver is on
- **WHEN** it reaches a name
- **THEN** it reads the name, the role when it is Director, and "button"

### Requirement: Find a person in Search
The system SHALL add a People section to Search results once the user has typed three or more letters and paused, listing up to three people from the movie database who have at least one title in the user's sources, with their photo or initials, name and count, and SHALL leave it out offline or with lookups off.

#### Scenario: Typing a name
- **GIVEN** lookups are on and the device is online
- **WHEN** the user types "mira" and stops typing
- **THEN** a People section lists Mira Holt with "Acting · 9 in your sources", and picking her opens her page

#### Scenario: Nobody in the sources
- **GIVEN** the only people matching the text have no title in the user's sources
- **WHEN** the results show
- **THEN** there is no People section

#### Scenario: Lookups off or offline
- **GIVEN** lookups are off, or the device is offline
- **WHEN** the user searches
- **THEN** no People section shows, no text is sent, and the other sections work as before

#### Scenario: What is sent
- **WHEN** the People section is filled
- **THEN** only the typed text goes to the movie database, after a pause in typing, and never anything about the user or their sources
