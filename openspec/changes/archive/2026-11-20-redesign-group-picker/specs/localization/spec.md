# Spec Delta

## MODIFIED Requirements

### Requirement: Source text is shown as it arrives
Channel names, programme titles and descriptions, group names, film and
series titles, plots, cast and track names from a source MUST be shown
exactly as the source sends them, in every app language.

#### Scenario: An English channel in a Swedish app
- **GIVEN** the app is in Swedish and a playlist names a channel "Sky Sports News"
- **WHEN** the channel list shows it
- **THEN** it reads "Sky Sports News"

#### Scenario: A provider group named in Arabic
- **GIVEN** the app is in English and a group is named in Arabic
- **WHEN** the group button, the Groups sheet or the sidebar shows it
- **THEN** the name shows in Arabic, right to left, apart from the count beside it
