# Spec Delta

## MODIFIED Requirements

### Requirement: Group list and order
The system SHALL list Favorites, then Recents when it has channels, then All channels, then for each source in input order its named groups and finally its Ungrouped group. A source's named groups SHALL follow the provider's category order when there is one, else first appearance. When the user has set group rules, the list SHALL follow the user's order after Favorites, Recents and All channels and leave out hidden groups and, while locks are closed, locked ones.

#### Scenario: Two sources, one with a category order
- **GIVEN** source A first with groups "Sport", "News" and two channels with no group, and source B second with channels in "Kids", "Sport", "Docs" and one whose group is "  ", and B's category order "Sport", " ", "Kids", "Sport", "Radio"
- **WHEN** the catalogue is built
- **THEN** the groups are Favorites, All channels, A Sport, A News, A Ungrouped, B Sport, B Kids, B Docs, B Ungrouped

#### Scenario: Category order rules
- **GIVEN** a source with a category order
- **WHEN** the catalogue is built
- **THEN** names with no channels ("Radio") are left out, a name listed twice is used once at its first position, empty or whitespace-only names are ignored, and groups the order does not list follow the listed ones in first-appearance order

#### Scenario: Ungrouped channels
- **GIVEN** channels whose group is missing, empty or only whitespace
- **WHEN** the catalogue is built
- **THEN** they fall in their source's Ungrouped group, which follows the named groups and is absent when the source has no such channels

#### Scenario: Group names
- **GIVEN** group names that differ only in case, or in spacing inside, before or after the name
- **WHEN** the catalogue is built
- **THEN** they stay separate groups, because only empty and whitespace-only names are normalized

#### Scenario: Sources interleaved in the input
- **GIVEN** input whose channels from sources A and B are mixed, with A's first channel ahead of B's
- **WHEN** the catalogue is built
- **THEN** A counts as the first source and B as the second, and each source's channels are taken in position order

#### Scenario: Recents in the group list
- **GIVEN** the two-source catalogue and a recents list naming two channels that resolve
- **WHEN** the catalogue is built
- **THEN** the groups are Favorites, Recents, All channels, then the source groups as before
- **AND** with no recents that resolve, Recents is absent

#### Scenario: No group rules
- **GIVEN** the user has set no group rules
- **WHEN** the catalogue is built
- **THEN** every group query gives the same result as without group management

#### Scenario: The user's order, hidden and locked groups
- **GIVEN** the user moved B Kids above A Sport, hid A News and locked B Docs, with locks closed
- **WHEN** the catalogue is built
- **THEN** the groups are Favorites, All channels, B Kids, A Sport, then the rest in their usual order without A News and B Docs
