# Tasks

## 1. The system bar (PR 1)

- [x] 1.1 Draw `TV-Shell-TabView` states: over Movies, over the Guide, with Settings focused
- [x] 1.2 Host Live, Guide, Movies, Series, Search and Settings in a `TabView` on Apple TV, with the picture behind it and Live's page clear (tvos-shell/the-tabs-in-order)
- [x] 1.3 Move Settings into its tab and the profile button to the top of its lead column (tvos-shell/open-settings)
- [x] 1.4 Move the clock into the info bar, the overlay, the Guide header and the Movies and Series hero
- [x] 1.5 Remove `ShellTabBar`, `ShellBarLayer`, the bar's focus cases and the shell's Menu handling for the bar

## 2. Tests (PR 1)

- [x] 2.1 Move `ShellUITests`, `GuideUITests`, `TopShelfTVUITests` and `ControlHintsTVUITests` to the system bar's buttons, and run them on a simulator

## 3. Verify

- [x] 3.1 `/opsx:verify adopt-tvos-tab-view` passes
