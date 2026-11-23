## MODIFIED Requirements

### Requirement: App Review gets a test source outside the app
The system SHALL serve a reviewer playlist and a matching guide from the
Antuna site on Antuna's own domain, made only of freely available public
test streams, and SHALL not name, bundle or link that playlist anywhere in
the app.

#### Scenario: The reviewer adds the source
- **GIVEN** a reviewer with the address from the review notes
- **WHEN** they add it as a playlist source and enter nothing else
- **THEN** Live lists the test channels, each plays, and the guide shows programmes for them from the guide address the playlist names

#### Scenario: Searching the app for the playlist
- **WHEN** someone searches the app's code and resources for the reviewer playlist's address, on either domain
- **THEN** it is not there

#### Scenario: The review notes and the playlist agree
- **WHEN** someone reads the review notes and the playlist
- **THEN** both name addresses on Antuna's domain, and none on antenna.code-crave.se

## ADDED Requirements

### Requirement: The App Store addresses are on Antuna's domain
The system SHALL give App Store Connect a support address and a privacy policy address on Antuna's domain, in every listing language, and the support address SHALL open a page that says how to get help.

#### Scenario: Checking the listing
- **WHEN** the listing check runs
- **THEN** every language's support and privacy addresses are https addresses on Antuna's domain, and it fails on one that names antenna.code-crave.se

#### Scenario: A buyer follows the support link
- **WHEN** someone follows the App Store's support link
- **THEN** a page on Antuna's domain opens that says how to get help
