## MODIFIED Requirements

### Requirement: Category id as number or string
The system SHALL read a category id given as a number or a string into the same string form. A category row that lacks `category_id` or `category_name`, or has either null, SHALL be dropped and the other rows kept.

#### Scenario: Mixed category ids
- **GIVEN** categories with `category_id` 7 in one item, "8" in another and 3.5 in a third
- **WHEN** they are decoded
- **THEN** the category ids are "7", "8" and "3.5"

#### Scenario: Category missing its name or id
- **GIVEN** a category list whose first item lacks `category_name`, and whose second lacks `category_id`, followed by a valid item
- **WHEN** it is decoded
- **THEN** only the valid item is returned

#### Scenario: Repeated category id
- **GIVEN** categories with ids `7` and `"7"`
- **WHEN** they are decoded
- **THEN** both are returned with the id "7" and nothing is deduplicated

## ADDED Requirements

### Requirement: Channels load without categories
The system SHALL load a provider's live channels when the category call fails or returns no usable rows, leaving every channel without a group. A channel whose category row was dropped SHALL have no group, and the other channels SHALL keep theirs.

#### Scenario: The category call fails
- **GIVEN** a panel whose live category call answers with status 500 or an HTML page, and whose stream list answers normally
- **WHEN** the provider's channels are loaded
- **THEN** every channel loads with no group

#### Scenario: One category row is broken
- **GIVEN** categories "1" named "News" and "2" with a null name, and a stream in each
- **WHEN** the provider's channels are loaded
- **THEN** the first channel is in "News" and the second has no group
