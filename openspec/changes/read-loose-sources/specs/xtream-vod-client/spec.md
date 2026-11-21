## RENAMED Requirements

- FROM: `### Requirement: Category lists fail whole`
- TO: `### Requirement: Broken category rows are skipped`

## MODIFIED Requirements

### Requirement: Broken category rows are skipped
The system SHALL drop a category row whose id or name is missing or null, read an id or a name sent as a number as its text, and keep the other rows in server order. When the movie or series category call fails, the movies or series SHALL still load, with no categories. No call SHALL let a raw decoder error escape.

#### Scenario: Second row without a name
- **GIVEN** a movie or series category list of three rows where the second lacks `category_name` or has it null
- **WHEN** it is requested
- **THEN** the first and third rows are returned

#### Scenario: A name sent as a number
- **GIVEN** a category row with `category_name` 2024
- **WHEN** it is requested
- **THEN** the category is named "2024"

#### Scenario: The category call fails
- **GIVEN** a panel whose movie category call answers with an error page or status 500, and whose movie list answers normally
- **WHEN** the movies are loaded
- **THEN** every movie loads and none is in a category

#### Scenario: Account call on HTML
- **GIVEN** the account call answered by an HTML page
- **WHEN** it runs
- **THEN** it fails as a decoding error at path ""
