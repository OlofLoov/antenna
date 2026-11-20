# Proposal

## Why

On 2026-11-19 the owner answered the first open question of `refresh-visual-design`: the Apple TV shell moves from its own tab bar to the system `TabView`, with Settings as the last tab and the clock drawn by the page. The system bar is Liquid Glass, sits where Apple's own apps put it, hides as content scrolls and handles Menu the way viewers know from the TV app.

`refresh-visual-design` PR 7 put the custom bar on glass with system focus, so it meets the design rules today. Moving to `TabView` replaces the shell's layering, its focus routing and its Menu handling, which about 140 lines of the Apple TV UI tests depend on. That is a change of its own, with its own PRs, so the shell is never half moved on main.

## What Changes

- The Apple TV shell hosts Live, Guide, Movies, Series, Search and Settings as system tabs, in that order. Settings stops being a cover over the current tab.
- The Antenna mark leaves the bar. The clock moves into each page that shows one: Live's info bar and overlay, the Guide's header, the Movies and Series hero. The profile button moves to the top of Settings.
- Menu over the full-screen picture shows the system bar, as the TV app does; Menu from the bar goes to the Home Screen. The shell's own bar raising, dimming and Back handling go.
- The tab bar deviations in `tvos-shell` (the open tab filled white, the opaque bar color) go, since the system draws the bar.

## Capabilities

### Modified Capabilities
- `tvos-shell`: the tabs and their order, opening Settings, the bar's place, and the deviations from the design rules.

## Impact

- Platforms: Apple TV only. iPhone, iPad and Mac already use the system `TabView`.
- Code: `Apps/Shared/Views/Shell/` (`ShellView`, `ShellBarLayer`, `ShellModel` and its navigation), `Apps/Shared/Components/ShellTabBar/`, `SettingsView` on Apple TV.
- Tests: `ShellUITests`, `GuideUITests`, `TopShelfTVUITests`, `ControlHintsTVUITests` and every Apple TV test that asserts focus on `shell.tab.*` or `shell.settings`.
- Boards: `TV-Shell-TabView` (new), then `TV-Shell-Menu`, `TV-Shell-FocusedTab`, `TV-Shell-Guide-Menu` and `TV-Shell-Menu-Profile` redrawn when the screen ships.
- Depends on: `refresh-visual-design` archived.
