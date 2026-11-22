## MODIFIED Requirements

### Requirement: Browse a genre or sort the lot
The system SHALL replace the rows with a poster grid and count when the user picks a genre, My list, All movies, See all on Continue watching, or a sort on iPad and Mac, opening it as its own screen on Apple TV, and SHALL bring the rows back on All, the section or Recently added.

#### Scenario: Picking a genre
- **GIVEN** the rows are showing
- **WHEN** the user picks a genre, My list, All movies, or See all on Continue watching, or on iPad and Mac picks Title or Year in the sort menu
- **THEN** a poster grid of those titles in the chosen order takes the rows' place with the count above it

#### Scenario: On Apple TV
- **GIVEN** the user is on Apple TV
- **WHEN** they open a grid
- **THEN** it opens as its own screen that Menu closes

#### Scenario: Back to the rows
- **GIVEN** a grid is showing on iPhone, iPad or Mac
- **WHEN** the user picks All on iPhone, the section in the sidebar on iPad and Mac, or "Recently added" in the sort menu
- **THEN** the rows come back

#### Scenario: Letters after Z
- **GIVEN** the device language is Swedish, and titles "Zorro", "Ängel", "Åsa", "Öga" and "Émile"
- **WHEN** the user sorts by Title
- **THEN** the order is "Émile", "Zorro", "Åsa", "Ängel", "Öga"; in Danish or Norwegian Æ, Ø and Å come after Z in that order, and in other languages accented letters sort with their plain letter
