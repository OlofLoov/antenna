## ADDED Requirements

### Requirement: Ratings on a ten-point scale
The system SHALL read a movie row's, a series row's and an info body's rating on a scale of ten. It SHALL use `rating` when it is above 0 and at most 10, else `rating_5based` doubled when that is above 0 and at most 5. A value above its scale, 0 or below, or not a number SHALL give no rating.

#### Scenario: Both fields
- **GIVEN** a movie row with `rating` "7.4" and `rating_5based` 3.7
- **WHEN** it is decoded
- **THEN** the rating is 7.4

#### Scenario: Only the five-point field
- **GIVEN** a movie row, a series row and an info body each with no `rating` and `rating_5based` "3.6"
- **WHEN** they are decoded
- **THEN** each rating is 7.2

#### Scenario: A series row
- **GIVEN** a `get_series` row with `rating` "8.1"
- **WHEN** it is decoded
- **THEN** the series has rating 8.1

#### Scenario: Out of scale
- **GIVEN** `rating` 74 with no `rating_5based`, and another row with `rating_5based` 7
- **WHEN** they are decoded
- **THEN** neither has a rating
