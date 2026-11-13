## MODIFIED Requirements

### Requirement: Fill the form from a copied link
The system SHALL offer, on iPhone, iPad and Mac, to fill the add-source form from a copied link, and SHALL read the clipboard only when the user taps Fill in.

#### Scenario: A link with a username and password
- **GIVEN** the user has copied a link that carries a username and password and the add-source sheet offers to fill it in
- **WHEN** they tap Fill in
- **THEN** Antenna reads the clipboard only now
- **AND** the Xtream fields are filled from the link

#### Scenario: Any other link
- **GIVEN** the user has copied a link without a username and password
- **WHEN** they tap Fill in
- **THEN** the playlist field is filled from the link

#### Scenario: The clipboard holds no link
- **GIVEN** the clipboard holds no link by the time the user taps Fill in
- **WHEN** they tap Fill in
- **THEN** the banner says so and nothing is filled

#### Scenario: No offer on Mac
- **GIVEN** the user is on a Mac and nothing on the clipboard looks like a link
- **WHEN** the add-source sheet shows
- **THEN** no fill-in banner appears

#### Scenario: On a Mac
- **GIVEN** the user is on a Mac with a link copied
- **WHEN** the add-source sheet shows
- **THEN** the fill-in banner appears, and the clipboard is read only when they click Fill in
