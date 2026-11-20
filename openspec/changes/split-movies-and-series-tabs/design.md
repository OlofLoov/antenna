# Design

## Context

See proposal.md for why. What exists on 2026-11-20:

- iPhone and a narrow iPad window: `CompactTabs` in `RootView` holds Live, Guide, Movies, Search and Settings. Movies shows when the sources offer movies or series (`TitleOffer.any`). `ShelfCompactScreen` keeps the open kind in its own state and draws `ShelfView.KindSwitch` (`movies.kind`) and the section search button (`movies.search`) over the banner.
- iPad and Mac wide layout: `LiveRegularView`'s sidebar lists Live, Guide, Movies, Series, Search and Sources & Settings, each of Movies and Series only when offered. The Go menu (`AntennaCommands`) has an item and a shortcut for each.
- Apple TV: `ShellView` holds Live, Guide, Movies, Series, Search and Settings as text tabs. The profile button sits at the top of Settings (`ProfileSwitchButton`).
- `ShelfLibrary` already keeps one model per kind, so both sections stay loaded side by side, and `LiveSession.Tab` already names Series.
- Profiles on iPhone, iPad and Mac switch from Settings, Profiles, which goes back to "Who's watching?".

Boards, under `openspec/specs/design-system/boards/`:
- New: `iPhone-Profile-Menu.dc.html`, the Live tab with the profile button's menu open.
- Changed: the tab bar on every `iPhone-*` board that draws it (Live, Guide, Movies, Series and the search button); `iPhone-Movies.dc.html` and `iPhone-Series.dc.html` with the section name and the profile button in place of the switch and the search button; the `iPhone-Settings*`, `iPhone-GuideSources*`, `iPhone-Groups*` and `iPhone-Reminders` boards drawn as a sheet with Close and no tab bar; `TV-Shell-TabView.dc.html` with the magnifying glass tab.
- Not drawn: the iPad narrow window, which is the iPhone layout at another width; the one-profile face of the button, which is the person glyph in the same place (the `ProfileCornerLabel` preview shows both).

Design-system requirements that apply: "Liquid Glass stays on the navigation layer" (the profile button is plain, with no glass, fill or stroke of its own), "Controls use system styles" (the system tab bar and its search tab, a system menu), "Accessibility identifiers follow the board", "Layouts mirror in right-to-left languages" (the system tab bar mirrors, the profile button sits at the trailing end).

## Goals / Non-Goals

**Goals:**
- Series is one tap away on iPhone, as Movies is.
- Each of Movies and Series keeps where the user was: scroll position, genre and open page.
- Settings and Switch profile are reachable from every iPhone tab that browses, without taking a tab.
- Apple TV and the iPad and Mac sidebar change as little as their platforms ask.

**Non-Goals:**
- A profile button on iPad and Mac. A Mac Settings window.
- Changing what Search finds.

## Decisions

### 1. Settings on iPhone: a sheet from a profile button

Options considered:
- **Keep the Settings tab.** Five tabs plus the search button is one more than the system tab bar holds before it gets cramped, and Settings is opened rarely.
- **A profile button that opens Settings as a sheet (chosen).** Apple's App Store and TV apps put the account behind a circle at the top right and open it as a sheet with Close. The sheet keeps the tab under it, so closing it goes back to where the user was.
- **A profile button that pushes Settings onto the tab's stack.** The tabs have no navigation stack of their own, and a push would mix Settings with Movies pages and their back gestures.

The sheet shows `SettingsView` with a Close button (`settings.close`, `Button(role: .close)`) in the cancellation slot, through a `closeSettings` environment value that is nil where Settings is a tab or a sidebar section. The reminder banner also shows over the sheet, so "a banner over any screen" still holds. Any other place a link or the banner sends the user (Live, the Guide, Search) closes the sheet first; a link to Settings (`ShellNavigator.Destination.settings`, the empty and error states' Open Settings) opens it.

### 2. What the profile button shows and does

- Two or more profiles: the current profile's color and initial in a 32 pt circle. A tap opens a system menu headed by the profile's name with Switch profile (`profile.switch`) and Settings (`profile.settings`). Switch profile stops what plays and goes back to "Who's watching?", as Settings, Profiles does. VoiceOver reads "Profile, Kids".
- One profile: the `person.crop.circle` glyph. A tap opens Settings straight away, since a menu with one item is a wasted tap. VoiceOver reads "Settings".
- Identifier `profile.button` in both cases. The target is 44 pt. No glass: it sits on the ground color on Live and the Guide and over art on Movies, and a plain badge reads on both.

The button lives in `Apps/Shared/Views/Profiles/ProfileMenuButton.swift` (it reads the profiles from SwiftData) and draws through `ProfileCornerLabel` in `Components/Profiles`. It renders nothing without the `showSettings` environment value, which only the iPhone tab bar sets, so the views it sits in can be shared with the wide layout.

### 3. Where the button sits on each tab

- Live and the Guide: at the trailing end of the group button's row. The group button keeps its full height and now runs up to the profile button. This row is always on screen under the picture, and it is where a thumb already goes.
- Live and the Guide with a whole-screen message (no sources, loading, offline, failed, empty): over the top right corner of the message, since there is no group row. Every state keeps a way into Settings, which matters most for "No sources yet".
- Movies and Series: at the trailing end of the bar over the banner, where the search button was, with the section's name ("Movies" or "Series") at the leading end in place of the switch. The bar pins to the top on the ground color once the banner scrolls away, as the switch did.
- Search: none. Its top holds the field and Cancel, and every other tab is one tap away.
- A title or person page over Movies, Series or Search: none. The page keeps its back button alone at the top, as pushed pages do in Apple's apps; the page stays open in its tab while the user opens Settings from another tab.

### 4. Search as the system search tab

iPhone: `Tab(value: .search, role: .search)`. iOS 26 draws it as a separate round button at the trailing end of the tab bar, after Live, Guide, Movies and Series, and gives it its own label and symbol. The tab's screen is unchanged: the field takes focus when Search opens and Cancel goes back to the tab Search was opened from. No `.searchable` is attached to the tab view, so the system does not turn the bar into a field of its own.

Apple TV: the same role on the Search tab, with a magnifying glass and the "Search" title as its label. tvOS keeps it in the order the tabs are listed, so the bar reads Live, Guide, Movies, Series, Search, Settings, with Search shown as the glass. The identifier stays `shell.tab.search`.

### 5. The section search button on iPhone goes

The Movies bar had its own search button that opened Search set to movies or series. With a search button in the tab bar right below it, that is the duplicate the owner asked about. Search's chips narrow to Movies or Series once there are results. The iPad and Mac toolbar field stays: the sidebar layout has no tab bar.

Option considered: keep the section button and scope Search to the tab's kind. Two search buttons on one screen, and the scope would differ depending on which one was tapped.

### 6. Movies and Series as two tabs

`CompactTabs.Tab` gains `.series` and loses `.settings`. Each tab holds its own `ShelfCompactScreen(kind:)`, so each keeps its own scroll position, genre and pinned bar for as long as the window lives. The library is shared: Continue watching keeps both kinds as before, and a title page opened from one tab's rows shows over that tab only (`LibraryPage.section`). Tapping the open tab closes the tab's page and scrolls to the top, per tab (`tabTaps[.series]`).

Each tab shows only when `TitleOffer` says the sources offer it, the rule the sidebar and Apple TV already use. When an offer goes away while its tab is open, Live opens.

Symbols: Movies `film`, as before. Series `play.rectangle.on.rectangle`: Apple's TV app uses `tv` for TV shows, and `tv` is already Live. The iPad and Mac sidebar's Series row moves from `square.grid.2x2`, which multi-view also uses, to the same symbol.

### 7. Opening and restoring

- The tab a session left: Movies and Series each restore when offered (`LiveSection(tab, offer:)`, the sidebar's rule), Search and Settings open Live, as before.
- "Open on launch: Movies" and Browse movies at the end of onboarding open Movies, or Series when only series are offered (`LiveSection.titles`).
- Siri and Shortcuts: a series still opens its page over Search, a movie plays, Search opens Search. They never named the Movies tab.

### 8. iPad and Mac

The wide layout keeps its sidebar: Live, Guide, Movies, Series, Search, then Sources & Settings below a gap. That is the iPadOS and macOS norm for an app whose settings hold content (sources, groups, profiles), and the Go menu keeps its shortcuts. Switch profile stays in Sources & Settings, Profiles.

Options considered for the Mac: a Settings window opened with Command-comma. Sources, groups and reminders are content the user edits while watching, which fits a section beside the picture better than a preferences window. Not done here; it can come with a Mac menu bar pass.

### 9. Apple TV

Settings stays the last tab (owner, 2026-11-19), with the profile button at its top. Movies and Series were already separate tabs and keep their rules (`tvos-shell/the-tabs-in-order`). Only Search's look changes.

### 10. Genres behind one button on iPhone

Added on 2026-11-20 at the owner's request: "on iPhones the switching between groups in Series and Movies might be suitable to be hidden and not displayed on the top." The genre chips over the Movies and Series banners give way to one button, built the way Live's group button and Groups sheet are (#448, #449): `ShelfGenreButton` draws `Browse.GroupButton` with the open list's name ("All movies", "My list" or the genre) and its count, and opens `ShelfGenreSheet`, a half-height sheet of `Browse.GroupChoiceRow`s with a search field and Close. All and My list come first, then the genres with their counts and a checkmark on the open one. Picking closes the sheet and sets the list the chips used to set, so the grid, the count and the banner behave as before.

Options considered:
- **Reuse `LiveGroupSheet` itself.** It reads `LiveModel`, `CatalogueGroup` and the group locks; genres have none of these. The shared parts are the components it draws (`Browse.GroupButton`, `Browse.GroupChoiceRow`), so those are what the genre sheet reuses, and the sheet keeps the same layout, detents and search placement.
- **Reuse `GroupChoices` from Core.** It lists catalogue groups. The genre search is `Shelf.genres(_:matching:)`, which folds names the same way through `ChannelFilter`, so "en action" finds "EN | Action" in both sheets.

iPad and Mac keep the genres in the sidebar under Genres, and Apple TV keeps its chips row: a sidebar is the norm there and the focus engine moves along the chips with one swipe. Only the narrow layout, where the chips scrolled off the edge, changes.

Identifiers: the button `movies.genres` (`series.genres`), the sheet `movies.genres.sheet`, Close `movies.genres.close`, and the rows keep the chips' `movies.genres.all`, `movies.genres.myList` and `movies.genres.<slug>`. Board `iPhone-Movies-Genres`.

### Identifiers

- New: `profile.button`, `profile.switch`, `profile.settings`, `settings.close`, `movies.title`, `series.title`.
- Gone on iPhone: `movies.kind`, `movies.kind.movies`, `movies.kind.series`, `movies.search`, `series.search`. The iPad and Mac toolbar field keeps `movies.search` and `series.search`.
- Kept: the tab titles (UI tests find tabs by "Live", "Guide", "Movies", "Series", "Search"), `shell.tab.search` on Apple TV.

## Risks / Trade-offs

- Settings is one tap further on iPhone (profile button, then Settings with two or more profiles). It is opened rarely, and the empty and error states still offer Open Settings directly.
- A reminder banner over the sheet is a second banner host. Both read the same reminder; Watch closes the sheet and plays the channel, and the first host to handle a watch request clears it.
- The search tab's placement belongs to the system. A later iOS could move it; the UI test that checks it is last will say so.
