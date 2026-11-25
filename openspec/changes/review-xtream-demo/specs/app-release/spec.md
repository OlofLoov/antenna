## ADDED Requirements

### Requirement: App Review can open Movies and Series
The system SHALL serve, from the Antuna site, a demo Xtream Codes server that the review notes name with a demo username and password. It SHALL list the reviewer test channels with their guide, a few movies and one series with one season of episodes, all with made-up names, descriptions and abstract art served from the Antuna site, and every channel, movie and episode SHALL play one of Apple's public sample streams. The app SHALL not name, bundle or link the server.

#### Scenario: The reviewer adds the demo server
- **GIVEN** a reviewer with the server address, username and password from the review notes
- **WHEN** they add them as an Xtream source on iPhone, iPad or Mac
- **THEN** Live lists the test channels, the Guide shows what is on now and next on each, Movies lists the demo movies with posters and Series lists the demo series

#### Scenario: A movie plays
- **GIVEN** the demo server added as a source
- **WHEN** the reviewer opens a movie's page and presses Play
- **THEN** the movie plays one of Apple's sample streams and can be paused and skipped through

#### Scenario: An episode plays
- **GIVEN** the demo server added as a source
- **WHEN** the reviewer opens the series and picks an episode
- **THEN** the episode plays one of Apple's sample streams

#### Scenario: On Apple TV
- **GIVEN** the demo server added on Apple TV with the Siri Remote, or on an iPhone signed in to the same iCloud account
- **WHEN** the reviewer opens Movies and Series on the TV
- **THEN** both list the demo titles and each title plays

#### Scenario: Nothing outside the site and Apple's samples
- **WHEN** someone reads every answer the demo server gives
- **THEN** every address in them is on the Antuna site, and every stream leads only to Apple's sample streams

#### Scenario: Searching the app for the server
- **WHEN** someone searches the app's code and resources for the demo server's address or login
- **THEN** it is not there

### Requirement: The review server answers only the demo login
The system SHALL answer the demo server's requests only for the demo username and password from the review notes, and SHALL answer any other login as an Xtream Codes panel answers a wrong password.

#### Scenario: A wrong password
- **WHEN** someone adds the demo server with the demo username and any other password
- **THEN** the app says it could not sign in, asks to check the username and password, and adds no source

#### Scenario: A stream address with another login
- **WHEN** someone opens a demo stream address with a login other than the demo one
- **THEN** the server refuses it and leads to no stream

#### Scenario: Asking for the files directly
- **WHEN** someone asks the site for the demo server's answer files by their own addresses
- **THEN** the site answers not found
