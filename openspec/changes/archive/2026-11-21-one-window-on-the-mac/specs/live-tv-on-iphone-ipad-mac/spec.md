## ADDED Requirements

### Requirement: One window on the Mac
The system SHALL keep at most one Antenna window open on a Mac. File > New Window SHALL open a window only when none is open and SHALL be dimmed while one is. A file, link or Handoff that arrives SHALL go to the open window. On iPad the app SHALL keep one window.

#### Scenario: New Window with a window open
- **GIVEN** Antenna is open in a window on a Mac
- **WHEN** the user presses Command-N or opens the File menu
- **THEN** no second window opens, and New Window is dimmed

#### Scenario: New Window after closing the window
- **GIVEN** the user closed Antenna's window and the app is still running
- **WHEN** the user chooses File > New Window
- **THEN** one window opens

#### Scenario: A playlist file opened from Finder
- **GIVEN** Antenna is open in a window on a Mac
- **WHEN** the user opens a playlist file with Antenna
- **THEN** the import sheet shows in that window and no other window opens

#### Scenario: iPad
- **GIVEN** Antenna on an iPad
- **WHEN** the user tries to open a second Antenna window from the dock or the app switcher
- **THEN** Antenna keeps its one window
