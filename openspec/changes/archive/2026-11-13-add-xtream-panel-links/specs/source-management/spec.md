## ADDED Requirements

### Requirement: Xtream panel playlist links are recognized
The system SHALL treat a web link whose last path part is `get.php` and whose query holds a non-empty username and password as an Xtream login. The server SHALL be the link's scheme, host, port and any path before `get.php`; the username and password SHALL be the query values with percent escapes decoded.

#### Scenario: A panel link with a port
- **GIVEN** the link `http://tv.example.net:8080/get.php?username=anna&password=s3cret&type=m3u_plus&output=ts`
- **WHEN** the app reads it
- **THEN** it is an Xtream login with server `http://tv.example.net:8080`, username `anna` and password `s3cret`

#### Scenario: A panel under a path
- **GIVEN** the link `https://example.net/panel/get.php?username=anna&password=s3cret`
- **WHEN** the app reads it
- **THEN** the server is `https://example.net/panel`

#### Scenario: Not a panel link
- **GIVEN** a playlist link that is not `get.php`, or a `get.php` link without a username or password
- **WHEN** the app reads it
- **THEN** it is not an Xtream login

### Requirement: The add form offers Xtream for a panel link
The system SHALL show "This link is an Xtream login. Add it as Xtream to get Movies, Series and the guide." under the playlist link of the add form, on every platform, while the link is an Xtream panel link, with a button "Use Xtream". The button SHALL switch the form to Xtream with the server, username and password filled in from the link, and keep the name. Connect without the button SHALL still add the link as a playlist.

#### Scenario: Pasting a panel link
- **GIVEN** the add form with type M3U playlist
- **WHEN** the user enters a panel link
- **THEN** the offer shows under the link

#### Scenario: Using Xtream
- **GIVEN** the offer on screen
- **WHEN** the user taps Use Xtream
- **THEN** the form shows Xtream with the server, username and password from the link and the name as typed

#### Scenario: An ordinary playlist link
- **GIVEN** the add form with type M3U playlist
- **WHEN** the user enters a link that is not a panel link
- **THEN** no offer shows

### Requirement: A playlist source switches to Xtream in place
The system SHALL offer the same switch in the details of a playlist source whose saved link is an Xtream panel link. Switching SHALL check the login with the panel first and change nothing when the check fails. A switch that works SHALL keep the source's name, place in the list and guide link, put the login in the Keychain and leave no login in the synced source, and move favorites and own-group channels of live channels loaded from that link to the same channels' Xtream ids.

#### Scenario: Switching an existing playlist
- **GIVEN** a playlist source named "Home" added from a panel link, with a favorite channel
- **WHEN** the user switches it to Xtream in its details and the panel accepts the login
- **THEN** "Home" is an Xtream login in the same place, the favorite still shows, and Movies and Series appear

#### Scenario: The panel turns the login down
- **GIVEN** a playlist source added from a panel link whose login no longer works
- **WHEN** the user switches it to Xtream
- **THEN** the details say why and the source stays a playlist

#### Scenario: Already added as Xtream
- **GIVEN** an Xtream login for the same server and username
- **WHEN** the user switches the playlist source to Xtream
- **THEN** the details say "This source is already added." and nothing changes
