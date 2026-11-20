# Proposal

## Why

The owner, 2026-11-20: "the tab on iPhone uses the same tab for movies and series, we also have a search there, do we need them all really?"

> As a movie and series watcher on iPhone, I want Series one tap away, not behind a switch inside Movies.

> As an on-the-go viewer, I want the tab bar to hold the places I watch from, the way Apple's TV and App Store apps do, with search and my account out of the way.

Today the iPhone tab bar holds Live, Guide, Movies, Search and Settings. Series sits behind a Movies | Series switch at the top of Movies, Movies has its own search button next to the switch, and Settings takes a tab the user opens a few times a year. Switching profile on iPhone means Settings, then Profiles.

After this change the iPhone tab bar holds Live, Guide, Movies and Series, with Search as the system's round search button at its trailing end. Settings and Switch profile open from a profile button at the top right of Live, the Guide, Movies and Series. Apple TV keeps its six tabs and draws Search as the system's search tab.

## What Changes

- iPhone and a narrow iPad window: Movies and Series become two tabs, each shown only when a source offers it. The Movies | Series switch goes, and each tab keeps its own scroll position, genre, banner and Continue watching.
- iPhone and a narrow iPad window: Search becomes the system search tab (`Tab(role: .search)`), drawn as a round button at the trailing end of the tab bar. The Search screen works as before, Cancel included.
- iPhone and a narrow iPad window: Settings leaves the tab bar. A profile button at the top right of Live, the Guide, Movies and Series opens it as a sheet. With two or more profiles the button shows the current profile and opens a menu with Switch profile and Settings; with one it shows a person glyph and opens Settings.
- iPhone: the section search button in Movies goes. The tab bar's search button is the way to search there, and the Search chips narrow to movies or series.
- Apple TV: Search becomes the system search tab, drawn as a magnifying glass in its place before Settings. Movies and Series were already tabs; Settings stays the last tab (decided 2026-11-19).
- iPad and Mac wide layout: no change in place. The sidebar already lists Live, Guide, Movies, Series, Search and Sources & Settings, and the Go menu has each. Series gets the same symbol as the new iPhone tab.

Out of scope:
- A profile button in the iPad and Mac sidebar, or a Mac Settings window (Command-comma). Recorded as a follow-up in design.md.
- Searching from the Movies or Series toolbar field on iPad and Mac, which stays as it is.
- Any change to what Search finds or how it ranks.
- Restoring Settings or Search as the tab a session reopens on (neither was restored before).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: the iPhone tab bar (new requirement), the group button's row with the profile button, tap-the-open-tab on Series.
- `movies-and-series-browsing`: Movies and Series as separate tabs on iPhone; search from the section on iPhone is the tab bar's search button.
- `profiles`: switching profile on iPhone from the profile button.
- `tvos-shell`: Search drawn as the system search tab.

## Impact

- Apps: `RootView` (iPhone tab bar, Settings sheet), `ShelfCompactScreen` (one per kind, no switch), a new profile button and its face, `SettingsView` (Close in the sheet), `ShellView` (tvOS search role), UI tests on iPhone and Apple TV that opened Settings from its tab or Series from the switch.
- AntennaCore: none. The session already names Series as a tab.
- Strings: "Switch profile" in every catalog language. "Movies", "Series", "Search" and "Settings" exist.
- Boards: the iPhone tab bar on every iPhone board that shows it, `iPhone-Movies` and `iPhone-Series` without the switch, a new `iPhone-Profile-Menu`, the Settings boards as a sheet, and `TV-Shell-TabView` with the search tab.
- Depends on nothing open. The parallel `adult-content` and button-label work touch nearby files (Groups, the banner), not the tab bar.
