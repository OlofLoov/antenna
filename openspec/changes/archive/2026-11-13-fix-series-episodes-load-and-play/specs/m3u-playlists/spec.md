## MODIFIED Requirements

### Requirement: Playlist series show in Series
The system SHALL list a playlist's series in the Series section with the first episode's logo as the poster and its group as the category. Opening one SHALL show its title page with the seasons and the episode picker, and an episode SHALL play from its link. A series the playlist's last load in this run does not have SHALL make the playlist load once more before the page says its episodes could not load.

#### Scenario: Watching a playlist episode
- **GIVEN** a playlist with episodes of "Show" in the group "Shows"
- **WHEN** the user opens Series, picks "Show" and plays season 1 episode 2
- **THEN** the episode plays from its link

#### Scenario: A playlist with episodes only
- **GIVEN** only a playlist whose entries are episodes
- **WHEN** it loads
- **THEN** Live has no channels from it and Series lists its shows

#### Scenario: A series from an earlier load
- **GIVEN** Series shows "Show" from an earlier load of the playlist, and the load kept in this run does not have it
- **WHEN** the user opens "Show"
- **THEN** the playlist loads again, and the page lists the episodes when the new load has them, or says "Could not load episodes" when it does not
