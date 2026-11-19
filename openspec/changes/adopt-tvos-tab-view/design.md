# Design

## Context

The owner's answer of 2026-11-19 to `refresh-visual-design` open question 1, recorded there as decision 9. The shell today is one `ZStack` in `ShellScreen`: the picture, the live layer, the open tab's content, the zap bar, the info panel, the scrim, the bar and the overlay, with one `FocusState<ShellFocus?>` routing focus between them and `ShellModel.menu(from:)` deciding what Menu does.

Board: `TV-Shell-TabView` (the system bar over Live with the dimmed picture, Settings as the last tab).

Design-system requirements it follows: "Liquid Glass stays on the navigation layer", "Content clears the tab bar", "Focus is the lifted white card", "Apple TV content stays in the safe area".

## Goals / Non-Goals

**Goals:**
- The system tab bar on Apple TV, with the system's Menu and focus behavior.
- Live keeps playing full screen under the bar; Movies, Series and Search keep pausing it.

**Non-Goals:**
- Changes to the channel overlay, zap bar, guide grid or multi-view.

## Decisions

### 1. Live is a tab whose page is the picture

Options considered:
- **The picture behind the `TabView`.** The engine's surface stays where it is and every tab draws over it. Live's page is clear. Keeps the stream untouched when tabs change, but the system bar's backdrop expects content of its own.
- **The picture inside Live's page.** Moves the surface into the tab, so leaving Live tears it down and the Guide's small picture needs a second surface.

Decision: the picture stays behind the `TabView`, and Live's page is clear. The Guide's small picture keeps its frame.

### 2. Settings is the last tab

Settings moves from a full-screen cover to a tab after Search. The profile button moves to the top of Settings' lead column. "Closing Settings" becomes moving to another tab.

### 3. The clock moves into the pages

The system bar has no trailing slot. Live's info bar and overlay already show the time; the Guide header shows it; Movies and Series show it in the hero's top right inside the safe area.

## Risks / Trade-offs

- [Focus routing] → `ShellFocus.tab(_)` and `.settings` go; the system owns focus in the bar. Tests that assert `shell.tab.*` focus move to the tab bar's buttons by label.
- [Menu] → the system handles Menu from the bar, so `ShellBack` keeps only the layers inside a page.

## Migration Plan

None. No stored data changes; the restored tab keeps its key.

## Open Questions

None.
