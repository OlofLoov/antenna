# channel-catalogue Specification

## Purpose
Gives the screens that list channels one set of answers about the loaded channels: which groups exist and in what order, what number each channel has, what to draw when a logo is missing, which favorites can be shown, and which channel a typed number reaches. It serves the user who wants several subscriptions "merged into one channel list and one guide", the living-room viewer who wants "to flip channels quickly with the remote, by up and down or by typing a number", and the viewer who wants "my favorite channels together in one list". No screen uses these answers yet, so the channel lists on every platform still show channels in load order.

## Requirements

### Requirement: Source tagging and position
The system SHALL tag each channel parsed from a source with that source's id and its 0-based position in the source's list, changing nothing else.

#### Scenario: Tagging a source's list
- **GIVEN** channels parsed from a source with id S
- **WHEN** they are tagged with S
- **THEN** every channel carries source S and a position equal to its 0-based index in playlist or stream list order, and nothing else changes

### Requirement: Group list and order
The system SHALL list Favorites, then Recents when it has channels, then All channels, then for each source in input order its named groups and finally its Ungrouped group. A source's named groups SHALL follow the provider's category order when there is one, else first appearance.

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

### Requirement: Group counts
The system SHALL count the channels in each group, with every count equal to the number of rows that group lists.

#### Scenario: Counts for the two-source catalogue
- **GIVEN** the two-source catalogue with 3, 4, 2, 5, 6, 1, 1 channels in A Sport, A News, A Ungrouped, B Sport, B Kids, B Docs, B Ungrouped, and two favorites resolving to two distinct channels
- **WHEN** each group is counted
- **THEN** Favorites is 2, All channels is 22, every other group's count is its channel count, and every count equals the number of rows listed

### Requirement: Provider numbers pass through
The system SHALL keep a provider's channel number unchanged.

#### Scenario: Numbers 104 and 7
- **GIVEN** channels numbered 104 and 7 by the provider
- **WHEN** the catalogue is built
- **THEN** their numbers are 104 and 7

#### Scenario: Collisions within one source
- **GIVEN** two channels in one source with the same provider number
- **WHEN** the catalogue is built
- **THEN** both keep the number and are ordered by position

### Requirement: Number fallback
The system SHALL treat a number outside 1 to 99,999 as no number, and SHALL number unnumbered channels from one above the highest provider number, in source order then position. The ceiling SHALL apply to provider numbers only.

#### Scenario: Highest provider number 300
- **GIVEN** channels without a number, channels numbered 0, -3 and 100,000, across sources whose highest number within 1 to 99,999 is 300
- **WHEN** the catalogue is built
- **THEN** the 0, -3 and 100,000 channels count as unnumbered, and the unnumbered channels get 301, 302 and so on in source order then position, the same for identical input

#### Scenario: Partial load
- **GIVEN** sources that finish loading one after another
- **WHEN** the catalogue is rebuilt after each one
- **THEN** fallback numbers can shift until every source has loaded

### Requirement: Number fallback base case
The system SHALL number channels from 1 when no channel has a provider number within 1 to 99,999.

#### Scenario: No provider numbers
- **GIVEN** channels none of which has a number within 1 to 99,999
- **WHEN** the catalogue is built
- **THEN** they are numbered 1, 2 and so on in source order then position

### Requirement: Sort within a group
The system SHALL order a group's rows by assigned number, then by position.

#### Scenario: Equal numbers
- **GIVEN** source A with channels numbered 3 (position 0), 5 (position 9) and 5 (position 2), all in "Sport"
- **WHEN** A Sport's rows are listed
- **THEN** the order is 3, then 5 at position 2, then 5 at position 9

#### Scenario: Empty names
- **GIVEN** channels with empty names
- **WHEN** a group's rows are listed
- **THEN** their order is unaffected, because the sort never reads the name

### Requirement: All channels order
The system SHALL order All channels by assigned number, then source order, then position.

#### Scenario: Two sources
- **GIVEN** the channels of source A numbered 3, 5 (position 2) and 5 (position 9), and source B second with a channel numbered 5
- **WHEN** All channels is listed
- **THEN** the order is 3 (A), 5 (A, position 2), 5 (A, position 9), 5 (B)

### Requirement: Initials
The system SHALL derive up to four upper-case initials from a channel name, counting only letters and digits: the first four counting characters of a single counting word, or else the first counting character of each of the first four words that have one. A name with none SHALL give "?".

#### Scenario: Examples
- **GIVEN** the names "Sport One", "Eurosport 1", "BBC - One", "Arena HD", "a b c d e", "news24", "24/7" and "** HD **"
- **WHEN** their initials are derived
- **THEN** they are "SO", "E1", "BO", "AH", "ABCD", "NEWS", "247" and "HD"

#### Scenario: Nothing to count
- **GIVEN** an empty name, or one with only punctuation
- **WHEN** its initials are derived
- **THEN** they are "?"

### Requirement: Favorites resolve to loaded channels
The system SHALL resolve a favorite to the loaded channel with its channel id and, when the favorite names a source, that source; the first match in All channels order wins. Rows SHALL follow sort order, ties by All channels order. Unresolved favorites SHALL be listed apart.

#### Scenario: Four favorites
- **GIVEN** favorites X (order 1, no source), Y (order 0, source A), W (order 2, source B) and Z (channel not loaded), with X's channel in A and B, A first in All channels order, Y's channel in A and W's channel in A only
- **WHEN** the Favorites rows are listed
- **THEN** X resolves to the A copy, Y to its A channel, W to nothing; the rows are Y then X; W and Z are not listed or counted and are the unresolved favorites, ordered by sort order then channel id

#### Scenario: Source deleted
- **GIVEN** a favorite whose source has been deleted
- **WHEN** the catalogue is built
- **THEN** the favorite is unresolved

### Requirement: One row per favorite channel
The system SHALL list a channel once in Favorites however many favorites resolve to it, at the lowest sort order among them.

#### Scenario: Duplicate favorites
- **GIVEN** several favorites resolving to the same channel, such as one with and one without a source, or two identical ones from a sync race
- **WHEN** the Favorites rows are listed
- **THEN** the channel appears once, at the position of the lowest sort order among them

### Requirement: Removal set
The system SHALL report, for a channel, every favorite with that channel id whose source is unset or equals the channel's source, and nothing else.

#### Scenario: Favorites to remove
- **GIVEN** the duplicate favorites of one channel and that channel C
- **WHEN** the favorites to remove for C are asked for
- **THEN** every favorite whose channel id is C's and whose source is unset or C's is returned, and no other

#### Scenario: Favorite without a source
- **GIVEN** a favorite with no source and two copies of its channel
- **WHEN** either copy is unfavorited
- **THEN** the favorite is removed, because it matches every copy even though only the first copy holds its row

### Requirement: Favorite predicate
The system SHALL report a channel as a favorite exactly when its removal set is not empty.

#### Scenario: Badge
- **GIVEN** the duplicate favorites of one channel
- **WHEN** a channel is checked
- **THEN** it is a favorite exactly when its removal set is not empty

### Requirement: Adding a favorite
The system SHALL create a new favorite for a channel that is not already one, with the channel's id and source and a sort order one above the highest existing, or 0 when there are none. For a channel that is already a favorite it SHALL create nothing.

#### Scenario: Next sort order
- **GIVEN** a channel C from source S that is not a favorite, and favorites whose highest sort order is 4
- **WHEN** C is added
- **THEN** the new favorite has C's id, source S, sort order 5 and no stored record yet

#### Scenario: First favorite and repeat add
- **GIVEN** no favorites, or a channel that is already a favorite
- **WHEN** the channel is added
- **THEN** the first case gives sort order 0 and the second creates nothing

### Requirement: Distinct keys for equal ids
The system SHALL key each row by source, channel id and position, so channels with equal ids are both listed.

#### Scenario: Equal ids
- **GIVEN** two channels with the same id from the same or different sources
- **WHEN** rows are keyed
- **THEN** each has a distinct key and both are listed

### Requirement: Build is deterministic
The system SHALL build the same groups and the same row keys in every group from the same input.

#### Scenario: Built twice
- **GIVEN** any input
- **WHEN** the catalogue is built twice from it
- **THEN** both builds have identical groups and identical row keys in every group

### Requirement: Digit prefix match
The system SHALL match typed digits, leading zeros stripped, to the lowest assigned number across All channels whose decimal form starts with them, ties by source order then position. Empty digits after stripping, or any non-digit, SHALL match nothing.

#### Scenario: Prefixes
- **GIVEN** channels numbered 1, 10, 104 and 1040 in source A and 104 in source B
- **WHEN** "1", "10", "104", "0104", "0" and "" are typed
- **THEN** they match 1, 10, 104 (A), 104 (A), nothing and nothing

#### Scenario: Longer prefixes and non-digits
- **GIVEN** the same channels
- **WHEN** "104" then "1040" are typed, or a string with a letter
- **THEN** "1040" matches 1040, and a string with any non-digit matches nothing

#### Scenario: Number in two sources
- **GIVEN** a number present in two sources
- **WHEN** it is typed
- **THEN** only the first source's channel is reached

### Requirement: Position in group
The system SHALL report a row's 1-based position in a group and the group's size, and nothing for a row not in the group.

#### Scenario: Fourth of 42
- **GIVEN** a group with 42 channels and a row that is fourth in it
- **WHEN** its position in that group is asked for
- **THEN** it is 4 of 42, and a row not in the group gives nothing

### Requirement: Catalogue build is fast
The system SHALL build groups, numbers, the All channels order, the digit index and the resolved Favorites for 50,000 channels in 400 groups with 100 favorites in under 200 ms in a debug test run on the reference machine. This is a benchmark run on request, not in CI.

#### Scenario: 50,000 channels
- **GIVEN** 50,000 channels in 400 groups and 100 favorites
- **WHEN** the catalogue is built with benchmarks enabled
- **THEN** it completes in under 200 ms

### Requirement: Row-key lookup
The system SHALL return the channel with exactly a given row key; failing that, the one loaded channel with the key's source and id when there is exactly one; otherwise nothing.

#### Scenario: Key held by a screen
- **GIVEN** a row key K held by a screen
- **WHEN** the channel for K is looked up
- **THEN** the channel with exactly K is returned, else the single channel with K's source and id, else nothing

### Requirement: Source group of a channel
The system SHALL report the source group a channel belongs to: its named group, or Ungrouped when it has no group.

#### Scenario: With and without a group
- **GIVEN** a channel from source A with no group and one with group "Sport"
- **WHEN** their source groups are asked for
- **THEN** they are A Ungrouped and A Sport

### Requirement: Empty catalogue
The system SHALL build a catalogue with only Favorites and All channels, both empty, when there are no channels.

#### Scenario: Zero channels
- **GIVEN** zero channels and any favorites
- **WHEN** the catalogue is built
- **THEN** the groups are Favorites and All channels with counts 0 and 0, digits match nothing, positions and row lookups give nothing, and every favorite is unresolved

### Requirement: Untagged channels are dropped
The system SHALL leave out a channel that carries no source.

#### Scenario: One untagged channel
- **GIVEN** three channels, one with no source
- **WHEN** the catalogue is built
- **THEN** All channels counts 2, no group lists the untagged channel, it has no row key and no source group

### Requirement: Favorites replaced without rebuild
The system SHALL replace the favorites of a built catalogue without changing any other group, row or number, in under 20 ms on the benchmark machine.

#### Scenario: New favorite list
- **GIVEN** the 50,000-channel catalogue and a changed favorite list
- **WHEN** the favorites are replaced
- **THEN** every other group, its rows and every number are identical to before, the Favorites rows, the favorite check, the removal sets and the unresolved list follow the new list, and the call takes under 20 ms with benchmarks enabled

### Requirement: Unknown group
The system SHALL report zero channels and no rows for a group it does not hold.

#### Scenario: Group from an unknown source
- **GIVEN** a built catalogue and a named group for an unknown source
- **WHEN** it is counted and listed
- **THEN** the count is 0 and there are no rows

### Requirement: Channel without a position is dropped
The system SHALL leave out a channel that carries a source but no position.

#### Scenario: Missing position
- **GIVEN** a channel from source S with no position, alongside tagged channels of S
- **WHEN** the catalogue is built
- **THEN** it has no row key, All channels counts only the tagged channels, no group lists it and no digits match it

### Requirement: Duplicate row key
The system SHALL keep only the first of several channels with the same source, id and position.

#### Scenario: A source's list passed twice
- **GIVEN** two input channels with the same source, id and position
- **WHEN** the catalogue is built
- **THEN** All channels lists the key once, and its channel, number and source group come from the first copy

### Requirement: Adding an untagged channel
The system SHALL refuse to create a favorite for a channel with no source, because such a favorite would match every copy of the channel.

#### Scenario: No source
- **GIVEN** a channel with no source
- **WHEN** it is added as a favorite
- **THEN** nothing is created

### Requirement: Source group of a channel from a source not loaded
The system SHALL derive the source group of a channel from a source that is not loaded from the channel's own source and group, and that group SHALL be absent from the catalogue with a count of 0.

#### Scenario: Unloaded source
- **GIVEN** a built catalogue and a tagged channel whose source is not in the input
- **WHEN** its source group is asked for
- **THEN** it is the group derived from its own source and group, which is not listed and counts 0

### Requirement: Recents replaced without rebuild
The system SHALL replace the Recents group of a built catalogue without changing any other group, row or number, within the same time bound as replacing favorites.

#### Scenario: New recents list
- **GIVEN** the 50,000-channel catalogue and a changed recents list
- **WHEN** the recents are replaced
- **THEN** every other group, its rows and every number are identical to before, Recents follows the new list newest first, and the call takes under 20 ms with benchmarks enabled

#### Scenario: An id matching two channels
- **GIVEN** a recents entry whose id matches two channels in one source
- **WHEN** the recents are replaced
- **THEN** that entry does not resolve and Recents does not list it
