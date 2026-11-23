## MODIFIED Requirements

### Requirement: Each bundle declares its privacy
The system SHALL ship a privacy manifest in each app and in the Top Shelf
extension that says Antuna does not track, contacts no tracking domain, and
names a permitted reason for each required-reason API the bundle calls. The
iOS and tvOS app manifests SHALL declare the data a problem report collects,
each for App Functionality, not linked to the user and not for tracking, and the Top Shelf extension
SHALL declare that it collects no data.

#### Scenario: Reading the manifest
- **WHEN** someone opens the built Apple TV app
- **THEN** the app and its Top Shelf extension each contain a privacy manifest saying no tracking
- **AND** the app's manifest lists customer support data and other diagnostic data, each for App Functionality, not linked to the user and not for tracking, and no email address
- **AND** the extension's manifest lists no collected data

#### Scenario: The iOS app adds crash and hang data
- **WHEN** someone opens the built iOS app
- **THEN** its manifest lists the same data as the Apple TV app plus crash data and performance data, each for App Functionality, not linked to the user and not for tracking

#### Scenario: An API that needs a reason
- **WHEN** a bundle checks free disk space, reads file dates or uses its own preferences
- **THEN** its privacy manifest lists that kind of API with the reason that matches the use
