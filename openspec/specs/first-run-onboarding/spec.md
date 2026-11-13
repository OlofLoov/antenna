# first-run-onboarding Specification

## Purpose
Takes someone who has just paid for Antenna and has nothing in it from an empty app to a playing channel. It asks for their provider, checks it, shows what loads, and lets them start watching before the guide is done.

## Requirements

### Requirement: A new user is asked for a provider
The system SHALL show the welcome screen, not an empty app, when the user has paid and has added no provider, and SHALL contact no server until the user connects.

#### Scenario: First launch with no provider
- **GIVEN** the user has paid and has added no provider
- **WHEN** they open Antenna
- **THEN** they see the welcome screen instead of an empty app
- **AND** Antenna has not contacted any server

#### Scenario: Not signed into iCloud
- **GIVEN** the device is not signed into iCloud
- **WHEN** the welcome screen shows
- **THEN** the note that providers sync through iCloud is hidden

#### Scenario: Menu on the Apple TV welcome screen
- **GIVEN** the welcome screen shows on Apple TV
- **WHEN** the user presses Menu
- **THEN** the app goes to the background, as the system does by default

#### Scenario: The purchase lapses during onboarding
- **GIVEN** the user is in onboarding and has saved a provider
- **WHEN** the purchase lapses
- **THEN** the purchase screen replaces onboarding
- **AND** the saved provider stays saved

### Requirement: A returning user goes straight to their channels
The system SHALL open on the user's channels, with no onboarding, when a provider exists whose password, if it needs one, is on this device.

#### Scenario: Provider with its password on this device
- **GIVEN** the user has a provider whose password, if it needs one, is on this device
- **WHEN** they open Antenna
- **THEN** they see their channels and no onboarding

#### Scenario: The user left during loading
- **GIVEN** the user left onboarding while it was loading, after the provider was saved
- **WHEN** they open Antenna again
- **THEN** they see their channels and no onboarding

#### Scenario: Password not yet on an iPhone, iPad or Mac
- **GIVEN** the user's providers have reached an iPhone, iPad or Mac but their passwords have not
- **WHEN** they open Antenna there
- **THEN** onboarding is not shown
- **AND** Live shows that it is waiting for the password

#### Scenario: A saved provider with no channels after a relaunch
- **GIVEN** a saved provider has no channels
- **WHEN** the user opens Antenna again
- **THEN** they see the empty home on Apple TV or the empty Live screen elsewhere, not onboarding

### Requirement: Mistakes in the form are caught before connecting
The system SHALL check the form when the user chooses Connect, using the same rules as adding a source in Settings, and SHALL say under the form what to fix without sending anything to the server.

#### Scenario: Empty field or invalid address
- **GIVEN** the user has left a required field empty or typed an address that is not valid
- **WHEN** they choose Connect
- **THEN** a message under the form says what to fix
- **AND** nothing is sent to the server

#### Scenario: A Stalker portal with a mistyped MAC address
- **GIVEN** the user picked a Stalker portal and left the portal or MAC address empty, typed a MAC address that is not six pairs of letters and digits, or typed a portal address without `http` or `https`
- **WHEN** they choose Connect
- **THEN** a message under the form says what to fix
- **AND** nothing is sent to the server

#### Scenario: Largest accessibility text size
- **GIVEN** the user has the largest accessibility text size
- **WHEN** the form shows
- **THEN** the form scrolls and Connect stays reachable

### Requirement: A failed connection says why and saves nothing
The system SHALL tell the user under the form which failure happened when a connection fails, SHALL save nothing, and SHALL keep what the user typed so they can try again.

#### Scenario: The server turns the user down
- **GIVEN** the server rejects the login, says the account is not active, answers with an error, or sends back something Antenna cannot read
- **WHEN** the user chooses Connect
- **THEN** a message under the form says which of these happened
- **AND** nothing is saved
- **AND** the fields keep what the user typed and they can try again

#### Scenario: Offline or unreachable
- **GIVEN** the device is offline or the server cannot be reached
- **WHEN** the user chooses Connect
- **THEN** a message under the form says which of these happened
- **AND** nothing is saved

#### Scenario: The portal turns the device down
- **GIVEN** a Stalker portal that does not accept the MAC address or login, refuses the device with a message of its own, or is not a Stalker portal at all
- **WHEN** the user chooses Connect
- **THEN** a message under the form says which of these happened, quoting the portal's own message when it sent one, with the MAC address left out
- **AND** nothing is saved

### Requirement: A working provider is saved once
The system SHALL save a provider whose login is accepted, whose portal signs in or whose playlist downloads, reusing an existing provider of the same type and address, SHALL keep its password in the secure password store, and SHALL then show the loading checklist.

#### Scenario: Connect succeeds
- **GIVEN** the Xtream login is accepted, the Stalker portal signs in, or the M3U playlist downloads
- **WHEN** the user chooses Connect
- **THEN** the provider is saved as when adding a source in Settings
- **AND** its password, or the portal's MAC address and login, go to the secure password store
- **AND** the loading checklist appears

#### Scenario: The same provider was added on another device
- **GIVEN** a provider with the same type and address was added on another device meanwhile
- **WHEN** the user connects to it here
- **THEN** that provider is reused and appears once

#### Scenario: The password cannot be stored
- **GIVEN** the secure password store refuses the password
- **WHEN** the user chooses Connect
- **THEN** the user sees the same message as when adding a source in Settings

### Requirement: The checklist shows real progress
The system SHALL turn each checklist line done or failed as the login, playlist, channels, movies and guide finish or fail, with real numbers, and SHALL show the guide's download progress while it runs.

#### Scenario: Lines fill in with numbers
- **GIVEN** the loading checklist is showing
- **WHEN** the login, playlist, channels, movies and guide finish or fail
- **THEN** each line turns done or failed with real numbers: live channels and groups, movies and series, guide days and how many channels have a guide
- **AND** the account line gives when the account expires and how many screens it allows when the server says
- **AND** the guide line shows its download progress while it runs

#### Scenario: No guide at all
- **GIVEN** a playlist without a guide link, or an Xtream account without a guide
- **WHEN** the checklist shows
- **THEN** there is no guide line

#### Scenario: The movie list is slow
- **GIVEN** a very large Xtream account whose movie list is slow
- **WHEN** the movies line has waited its limit
- **THEN** the line stops waiting and says movies and series are available without counts

#### Scenario: The account has no expiry date
- **GIVEN** an Xtream account whose server gives a screen count but no expiry date
- **WHEN** the login line turns done
- **THEN** the account line shows only the screen count, such as "2 connections", with no " · " before it
- **AND** when the server gives neither, the login line shows "Signed in" with nothing beneath

#### Scenario: VoiceOver reads a line
- **GIVEN** VoiceOver is on
- **WHEN** the user moves to a checklist line
- **THEN** it is read as one item with its state, title and detail

### Requirement: A summary when everything has loaded
The system SHALL show a summary of what the provider added once every checklist line is done or failed, leaving out anything that came to nothing or failed.

#### Scenario: Everything has finished
- **GIVEN** the loading checklist is showing
- **WHEN** every line is done or failed
- **THEN** the user sees a summary of what the provider added, leaving out anything that came to nothing or failed
- **AND** on Apple TV the first channel is already playing behind it

#### Scenario: No guide or no movie counts
- **GIVEN** the provider has no guide, or the movies line stopped waiting for counts
- **WHEN** the summary shows
- **THEN** it does not mention a guide, or leaves out the movie and series numbers

### Requirement: Start watching without waiting for the guide
The system SHALL let the user start watching once the channels have loaded, close onboarding, play the first channel of the first group, and keep loading the guide in the background.

#### Scenario: Start watching while the guide loads
- **GIVEN** the channels have loaded and the guide may still be loading
- **WHEN** the user chooses Start watching
- **THEN** onboarding closes
- **AND** the first channel of the first group plays, full screen on Apple TV and in Live elsewhere
- **AND** the guide keeps loading in the background until it is done

### Requirement: Add a second provider
The system SHALL let the user add another provider from the summary, and SHALL then name both providers and add up their numbers without restarting the first provider's guide download.

#### Scenario: A second provider finishes loading
- **GIVEN** the user is on the summary
- **WHEN** they add a second provider and it finishes loading
- **THEN** the summary names both providers and adds up their numbers
- **AND** the first provider's guide keeps downloading without starting over

### Requirement: Fill the form from a copied link
The system SHALL offer, on iPhone and iPad, to fill the add-source form from a copied link, and SHALL read the clipboard only when the user taps Fill in.

#### Scenario: A link with a username and password
- **GIVEN** the user has copied a link that carries a username and password and the add-source sheet offers to fill it in
- **WHEN** they tap Fill in
- **THEN** Antenna reads the clipboard only now
- **AND** the Xtream fields are filled from the link

#### Scenario: Any other link
- **GIVEN** the user has copied a link without a username and password
- **WHEN** they tap Fill in
- **THEN** the playlist field is filled from the link

#### Scenario: The clipboard holds no link
- **GIVEN** the clipboard holds no link by the time the user taps Fill in
- **WHEN** they tap Fill in
- **THEN** the banner says so and nothing is filled

#### Scenario: No offer on Mac
- **GIVEN** the user is on a Mac with a link copied
- **WHEN** the add-source sheet shows
- **THEN** no fill-in banner appears

### Requirement: Sign in again on an Apple TV
The system SHALL ask on Apple TV for the username and password of each Xtream provider, and the MAC address of each Stalker portal, whose login is not on this device, with the server or portal filled in, SHALL keep each login on this Apple TV without adding a provider, and SHALL then show the loading checklist.

#### Scenario: Providers synced without passwords
- **GIVEN** every provider is an Xtream login and none of their passwords is on this Apple TV
- **WHEN** the user opens Antenna on Apple TV
- **THEN** they are asked for the username and password of each provider in turn with the server already filled in
- **AND** each password is kept on this Apple TV without adding a new provider
- **AND** after the last one the loading checklist appears

#### Scenario: A Stalker portal synced without its MAC address
- **GIVEN** the providers are Xtream logins and Stalker portals and none of their logins is on this Apple TV
- **WHEN** the user opens Antenna on Apple TV
- **THEN** each portal asks for its MAC address, and a login and password only if the provider gave one, with the portal address already filled in
- **AND** the portal is checked the way Connect checks it before the MAC address is kept on this Apple TV

### Requirement: A provider with no live channels
The system SHALL offer Browse movies in place of Start watching when a provider has movies or series but no live channels, and SHALL offer only a way back to the form when it has nothing, removing what that attempt saved.

#### Scenario: Movies or series but no live channels
- **GIVEN** the provider connected but has no live channels and has movies or series
- **WHEN** the checklist finishes
- **THEN** the user is offered Browse movies instead of Start watching

#### Scenario: Nothing at all
- **GIVEN** the provider connected but has no live channels, movies or series
- **WHEN** the checklist finishes
- **THEN** the only way on is back to the form
- **AND** going back removes what this attempt saved

### Requirement: Add a Stalker portal
The system SHALL offer a Stalker portal as a third kind of provider on every platform, SHALL connect with only the portal address and the MAC address the provider registered, and SHALL send a login and password only when the user typed one.

#### Scenario: A portal with only a MAC address
- **GIVEN** a provider that gave the user a portal address and a MAC address and nothing else
- **WHEN** the user picks Stalker portal, fills in those two and chooses Connect
- **THEN** Antenna signs in to the portal and shows the loading checklist with the portal's channels
- **AND** the user was never asked to fill in a login or password

#### Scenario: A portal that also has a login
- **GIVEN** a provider that gave the user a login and password for the portal as well
- **WHEN** the user fills in the optional login and password and chooses Connect
- **THEN** Antenna signs in with them

#### Scenario: Picking the portal on Apple TV
- **GIVEN** the "What kind of source?" step on Apple TV
- **WHEN** the user selects the Stalker portal card with the remote
- **THEN** the portal form opens, like the M3U and Xtream cards do

### Requirement: Add a Jellyfin server
The system SHALL offer a Jellyfin server as a kind of provider on every platform, SHALL connect with the server address, username and password, SHALL check the address is a Jellyfin server before sending the password, and SHALL say which failure happened when it does not connect.

#### Scenario: A Jellyfin server with Live TV
- **GIVEN** a user with a Jellyfin server address, username and password
- **WHEN** the user picks Jellyfin, fills in those three and chooses Connect
- **THEN** Antenna signs in to the server and shows the loading checklist with the server's Live TV channels

#### Scenario: Not a Jellyfin server
- **GIVEN** an address where something other than a Jellyfin server answers
- **WHEN** the user chooses Connect
- **THEN** a message under the form says no Jellyfin server answered there
- **AND** the password was not sent and nothing is saved

#### Scenario: The server keeps the account out or its certificate is not trusted
- **GIVEN** a server that turns down the password, does not let this account sign in from this device, or has a certificate Antenna cannot verify
- **WHEN** the user chooses Connect
- **THEN** a message under the form says which of these happened, and for the certificate suggests `http` on the home network or a trusted certificate
- **AND** nothing is saved

#### Scenario: Picking Jellyfin on Apple TV
- **GIVEN** the "What kind of source?" step on Apple TV
- **WHEN** the user selects the Jellyfin card with the remote
- **THEN** the Jellyfin form opens, like the other cards do

#### Scenario: A Jellyfin server synced without its password
- **GIVEN** the providers are logins and none of them is on this Apple TV, one of them a Jellyfin server
- **WHEN** the user opens Antenna on Apple TV
- **THEN** the Jellyfin server asks for its username and password with the server address already filled in
- **AND** the server is checked the way Connect checks it before the login is kept on this Apple TV

### Requirement: Add a Channels DVR server
The system SHALL offer a Channels DVR server as a kind of provider on every platform, SHALL connect with only the address the server shows, and SHALL show the server's version in the loading checklist.

#### Scenario: A server at home
- **GIVEN** a Channels DVR server on the home network at 192.168.1.20
- **WHEN** the user picks Channels DVR, types "192.168.1.20" and chooses Connect
- **THEN** Antenna checks the server, shows the loading checklist with a Server line naming its version, and lists its channels
- **AND** the user was never asked for a password

#### Scenario: Local network access refused
- **GIVEN** an iPhone, iPad or Mac where Antenna may not reach the home network, and a server address at home
- **WHEN** Connect cannot reach the server
- **THEN** the message under the form also asks the user to allow local network access for Antenna in Settings

#### Scenario: Picking the server on Apple TV
- **GIVEN** the "What kind of source?" step on Apple TV
- **WHEN** the user selects the Channels DVR card with the remote
- **THEN** the server form opens, like the other cards do
