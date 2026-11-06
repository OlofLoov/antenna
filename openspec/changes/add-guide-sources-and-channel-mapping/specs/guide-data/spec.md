# Spec Delta

## MODIFIED Requirements

### Requirement: Find the guide for each source
The system SHALL use every guide link a playlist names, the guide link saved with the source, the provider's guide for an Xtream login, and links the user added, each once, in the user's order, skipping turned-off guides. The provider's guide SHALL start turned off when the user saved a guide link of their own. Working this out SHALL send nothing over the network.

#### Scenario: Order of preference
- **GIVEN** a source
- **WHEN** the app works out where its guides live
- **THEN** it lists the links the playlist names, the saved link, the Xtream provider's link and the user's added links in the user's order, and nothing goes over the network

#### Scenario: A link named twice
- **GIVEN** a playlist that names the same guide link twice
- **WHEN** its guides load for the first time
- **THEN** that guide is listed and downloaded once

#### Scenario: The provider's guide with a link of the user's own
- **GIVEN** an Xtream source with a guide link the user saved
- **WHEN** its guides are listed
- **THEN** the provider's own guide is listed turned off, and the user can turn it on

#### Scenario: No guide
- **GIVEN** a playlist with no guide link, or a Stalker portal without one
- **WHEN** the app works out where its guide lives
- **THEN** the source has no guide

#### Scenario: Link changed on another device
- **GIVEN** a guide link changed on another device
- **WHEN** the next refresh runs
- **THEN** the new link is used

### Requirement: Programmes land on the right channels
The system SHALL match programmes to channels within each source by guide id, ignoring spaces and newlines around the ids and otherwise matching exactly, case included, whichever of the guide and the channel list loads first. A guide entry the user picked by hand for a channel SHALL take the place of the channel's own guide id.

#### Scenario: Ids with spaces, a channel without an id, two sources
- **GIVEN** a channel and a programme whose guide ids differ only by spaces around them, a channel with no guide id, and two sources whose guides both use the id "one"
- **WHEN** the guide and the channel list have both loaded, in either order
- **THEN** the first channel gets its programme, the channel without an id gets none and reports no data, and each source's channels get programmes only from that source's guide

#### Scenario: Stalker source with a guide link
- **GIVEN** a Stalker source with its own guide link
- **WHEN** the guide loads
- **THEN** it downloads, and every programme is unmatched until the source has channels

#### Scenario: A hand-picked entry
- **GIVEN** a channel with no guide id that the user matched by hand to a guide entry
- **WHEN** the guide and the channel list have both loaded
- **THEN** the channel gets that entry's programmes
