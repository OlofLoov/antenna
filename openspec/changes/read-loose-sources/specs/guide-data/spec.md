## MODIFIED Requirements

### Requirement: Programmes land on the right channels
The system SHALL match programmes to channels within each source by guide id, ignoring spaces and newlines around the ids, whichever of the guide and the channel list loads first. An id that matches exactly SHALL win; when no guide of the source has the id exactly, an id that differs only by letter case SHALL match. An Xtream guide id sent as a number SHALL be read as its digits. A guide entry the user picked by hand for a channel SHALL take the place of the channel's own guide id, and a channel with no guide id SHALL use the entry matched by its name when there is one.

#### Scenario: Ids with spaces, a channel without an id, two sources
- **GIVEN** a channel and a programme whose guide ids differ only by spaces around them, a channel with no guide id, and two sources whose guides both use the id "one"
- **WHEN** the guide and the channel list have both loaded, in either order
- **THEN** the first channel gets its programme, the channel without an id gets none and reports no data, and each source's channels get programmes only from that source's guide

#### Scenario: Ids that differ by case
- **GIVEN** a channel with guide id "BBCOne.uk" and a guide whose programmes use "bbcone.uk"
- **WHEN** the guide and the channel list have both loaded
- **THEN** the channel gets those programmes

#### Scenario: An exact id beats one that differs by case
- **GIVEN** a channel with guide id "One", a guide with programmes for "one", and a lower guide of the same source with programmes for "One"
- **WHEN** both guides have loaded
- **THEN** the channel gets the programmes for "One"

#### Scenario: A numeric Xtream guide id
- **GIVEN** an Xtream stream whose `epg_channel_id` is the number 1234, and a guide with programmes for "1234"
- **WHEN** the guide and the channel list have both loaded
- **THEN** the channel gets those programmes

#### Scenario: Stalker source with a guide link
- **GIVEN** a Stalker source with its own guide link
- **WHEN** the guide loads
- **THEN** it downloads, and every programme is unmatched until the source has channels

#### Scenario: A hand-picked entry
- **GIVEN** a channel with no guide id that the user matched by hand to a guide entry
- **WHEN** the guide and the channel list have both loaded
- **THEN** the channel gets that entry's programmes

#### Scenario: Matched by name
- **GIVEN** a channel with no guide id whose name is the name of exactly one guide entry
- **WHEN** the guide and the channel list have both loaded
- **THEN** the channel gets that entry's programmes
