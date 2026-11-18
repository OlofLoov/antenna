# Design

## Boards

- `TV-Title-About` (new): the full-screen page More opens on Apple TV, and the one Description opens for an episode. Name, details line, the description, then Cast and Director, in one column on the cover backdrop. `title.about` on the scrolling page on Apple TV and on the sheet elsewhere, `title.about.text` on the sheet's column, `title.about.done` on Done.
- `iPhone-Title-About` (new): the same content in a sheet with Done, for an episode's Description on iPhone. iPad and Mac show the same sheet at form size.
- `TV-Title`, `TV-Series`: the `title.plot` note says More opens `title.about`. The `title.backdrop` note gives the shape rule. Nothing else is redrawn.
- `TV-Movies`, `TV-Movies-Poster-Only`, `iPad-Movies-Poster-Only`: the art notes give the shape rule. The poster-only layout is drawn already.
- Design-system rules: `design-system/pages-cover-what-is-behind-them` (the About page uses `CoverBackdrop`), `design-system/focus-is-the-lifted-white-card` (More keeps it), the TV safe area.

## Decisions

### Which picture layout to use

Options: trust the field the picture came in (backdrop or poster), check the picture's file for its size, or pick by the decoded picture's shape.

Chosen: the decoded picture's shape. The picture is decoded anyway before it shows, so its width and height cost nothing. `ArtFit.choose` in AntennaCore takes the picture's size and the frame's size. It answers `.whole` when the frame is wide (more than 1.2 times as wide as tall) and filling it would hide more than half of the picture; otherwise `.fill`. In the 3:1 Apple TV banner a 16:9 backdrop still fills (41% hidden), a 2:3 poster or a square picture shows whole. In the 16:9 movie page only a picture taller than about 9:8 shows whole. On the series page (1920 by 520) a 16:9 backdrop shows whole, since filling would cut it to its middle half.

`.whole` is the poster-only layout from PR #365: the picture at its own proportions in a box at most 70% of the frame's height and half its width, at the bottom right, over a blurred copy that fills the frame. It is now one component, `FittedArt`, that the banner and the title page both use. The banner keeps the label (`BannerArt.backdrop` or `.poster`) only to choose which address to load. iPhone frames are taller than wide, so they always fill, as the spec says.

Fill uses `FilledArt` as before: `resizable`, `scaledToFill`, clipped. The tests render a picture with a square in it and measure the square, so a change that stretched it would fail.

### The full text on Apple TV

Options: a `.sheet` with a focusable `ScrollView` (today), focusable paragraphs, or one focusable scroll view that moves by a step on each swipe.

Chosen: a `fullScreenCover` holding `TitleAbout`, whose text column takes focus and handles up and down itself. A sheet on tvOS 26 is a centered card the remote cannot scroll when nothing inside takes focus; a description is one paragraph, so focusable paragraphs would jump past most of a long one. A focusable `ScrollView` does not take focus on tvOS 26, so the column inside it does, with its effect off. Up and down move the scroll position by 360 points within its range, through `ScrollPosition`. Menu closes the cover. The screen keeps what opened it (`TitlePageContext.AboutOpener`: More, or an episode by id) in the page and episode state while it shows; when it goes, More or that row takes focus back, since the page's default focus would otherwise send it to Play. The cover's background is `CoverBackdrop`, so the page behind is blurred and dimmed.

`TitleAboutText` in AntennaCore holds what the page shows: a heading, an optional details line and paragraphs with an optional label. It is made from a title's metadata or from an episode, so both pages share one view and one test.

On iPhone, iPad and Mac More keeps expanding in place, and the expanded state also lifts the two-line limit on Cast and Director. Description for an episode opens a sheet there with Done, which Escape also closes.

### Episode descriptions

Options: two or three lines in the row, a focusable More in each row, or a menu item.

Chosen: Description in the row's context menu, long press on Apple TV. The row is a button that plays the episode, so a second focus target inside it would break the one-press-plays rule, and longer rows push the list down on every series. The item exists only when the episode has a description. `EpisodesContext.Actions.describe` carries it.

### The banner on Apple TV

Options: hold while focus is on the banner (today), never hold, or restart the wait on each move.

Chosen: restart the wait on each move between the banner's buttons, and never hold. Focus lands on Play when Movies opens, so holding while focused means the banner never moves on Apple TV. Apple's TV app keeps its top banner moving while focus rests on it. `BannerPager.rotates(count:interacting:reduceMotion:hold:)` takes `.restartsOnInput` on Apple TV and `.whileInteracting` elsewhere. `ShelfBannerHost` counts inputs into the rotation task's id. While the Apple TV preview shows (`add-focused-title-preview`) the banner stays paused as before, so each one starts a new eight-second wait. `ShelfTVBannerButtons` reports every focus change, not only entering and leaving. The UI tests run with Reduce Motion, so they never see the banner move by itself.

### Building the section off the main thread

Options: keep building on the main actor but faster, build a whole index off the main actor and swap it in, or build each source's part as it loads and merge on the main actor.

Chosen: a whole `ShelfIndex` built by a `@concurrent` function and swapped in. It holds the titles, the newest-first order, the rows, the banner and a lookup by `ActivityKey`. A source's new state (`.loaded`) waits for the index that includes it, so the status, rows and banner change in one step and focus has a Play button to land on. Each build has a generation number; only the newest one is applied. `ShelfModel.settled()` waits for the build too, so the tests keep their shape. Merging per source would save little: one sort of 50 000 dates takes a few milliseconds once the sort compares dates instead of whole titles.

`ShelfTitle.newestFirst` now sorts pairs of a date and an index instead of whole titles. `ContinueWatching.items` and `RecentlyWatched.list` gain forms that take a lookup closure, so the rows no longer build a dictionary of every title on each redraw. `ShelfModel` keeps each grid's sorted list until the index changes. `ShelfActivity` keeps saved positions by title key, so a poster's label is a dictionary read.

`PosterCache` decodes in a `@concurrent` function, so posters decode in parallel instead of one at a time on the cache's actor. The cache's memory and disk limits are unchanged.

Signposts in the `browse` category: `shelf load` around a source's list call and decode, `shelf index` around a build, `poster` around a download and decode. They show up in Instruments' Points of Interest.

### Playlist series asked again

`ShelfLoader.playlistSeriesInfo` loads the whole playlist again when the kept load lacks a series (PR #361). Each banner title and page could do that. `PlaylistRetryGate`, one per `ShelfLoader` and shared by its copies, wraps `RetryWindow` from AntennaCore and lets one such reload through per source every five minutes; inside that window a missing series fails at once with `unknownTitle`, as it did before PR #361.

## Performance budgets

`ShelfBrowsingPerformanceTests` in AntennaCore, on 50 000 movies in 300 categories and 10 000 series, in a debug build: building the index under 400 ms; Continue watching and Recently watched from 200 saved positions through the lookup under 10 ms each (about 70 ms when they built a dictionary of every title); the newest-first order of all 50 000 under 300 ms (the old sort took about 660 ms on the same machine). The numbers leave room for a loaded CI runner and still fail a return to sorting whole titles or to walking the catalogue on each redraw.

## Platforms

All four platforms get the shape rule, the full text and the speed work. The rotation change is Apple TV only. The About page is a full-screen cover on Apple TV and a sheet elsewhere.

## Not drawn

The Instruments view of the signposts.
