## MODIFIED Requirements

### Requirement: The site answers every address the app uses
The system SHALL publish, on Antuna's own domain over HTTPS, the setup page at `/setup`, the Terms of Use at `/terms`, the Privacy Policy at `/privacy` and the association file at `/.well-known/apple-app-site-association`, and that domain SHALL be the one the app's setup links, legal links and App Store addresses use.

#### Scenario: The paywall's links
- **GIVEN** the paywall on iPhone or Apple TV
- **WHEN** the user follows Terms of Use or Privacy Policy
- **THEN** a page with that title opens at Antuna's domain

#### Scenario: The setup page stays
- **WHEN** an iPhone without Antuna opens a setup link
- **THEN** the same one-line setup page as before shows, with its App Store link

#### Scenario: A folder starting with a dot
- **WHEN** the site is published
- **THEN** the association file under `/.well-known/` is published with the rest and is not left out for its folder's name

#### Scenario: The association file is JSON
- **WHEN** the association file is fetched
- **THEN** it is served as JSON, with no redirect

### Requirement: The site publishes from main
The system SHALL publish the site to Antuna's domain when a change to it lands on main, and only then, and SHALL remove from the published site any page removed from the repository.

#### Scenario: A change to a page lands
- **WHEN** a pull request that edits the Privacy Policy merges to main
- **THEN** the published Privacy Policy shows the edit after the publish run

#### Scenario: A change elsewhere lands
- **WHEN** a pull request that touches only app code merges
- **THEN** the site is not published again

#### Scenario: A page is removed
- **WHEN** a pull request that deletes a page merges
- **THEN** the page's address shows "Page not found" after the publish run
