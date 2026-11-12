# Spec Delta

## MODIFIED Requirements

### Requirement: Find the guide for each source
The system SHALL use the guide link the user entered for a source, else for a playlist the first guide link the playlist names, else for an Xtream source the provider's guide link built from the user's login, else for a Stalker portal the portal's own guide. Working this out SHALL send nothing over the network.

#### Scenario: Order of preference
- **GIVEN** a source
- **WHEN** the app works out where its guide lives
- **THEN** it uses the entered link, else the playlist's first link, else the Xtream provider's link, else the Stalker portal's own guide, and nothing goes over the network

#### Scenario: No guide
- **GIVEN** a playlist with no guide link
- **WHEN** the app works out where its guide lives
- **THEN** the source has no guide

#### Scenario: Stalker portal without a guide link
- **GIVEN** a Stalker portal source with no guide link entered
- **WHEN** the app works out where its guide lives
- **THEN** the source uses the portal's own guide

#### Scenario: Stalker session turned down while loading the guide
- **GIVEN** a Stalker portal guide download that the portal turns down
- **WHEN** the guide loads
- **THEN** the portal session is renewed once and the download is tried once more

#### Scenario: Link changed on another device
- **GIVEN** a guide link changed on another device
- **WHEN** the next refresh runs
- **THEN** the new link is used
