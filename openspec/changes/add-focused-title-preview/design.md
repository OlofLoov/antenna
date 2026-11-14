# Design

## Context

`ShelfTVScreen` draws Movies and Series on Apple TV as one `ScrollView` with a `LazyVStack`: the banner full bleed behind the tab bar, the notices, `ShelfRowsContent`, then the Genres chips. Focus scrolls a row to just under the 120 pt tab bar, and once the content has scrolled 300 pt a band of `Palette.ground` hides what passes under the bar.

`ShelfBannerHost` asks `ShelfModel.loadDetails` for the shown banner title and the next one. `ShelfModel` keeps the answers in `details` (a `ShelfDetails` per title id), with `asked` stopping a second request and `answered` recording a reply or a failure. `BannerArt.choose` picks the backdrop, the poster after an answer or after `BannerArt.patience` (1.5 s), or nil to keep the current picture. `ShelfBanner.Picture` shows a poster whole at the right over a blurred copy when the frame is wider than 1.2 times its height.

A title page builds its own `TitleModel`, which calls `ShelfModel.info(_:)` each time the page opens. So a banner title that the viewer opens is asked about twice.

## Decisions

### Where the preview sits and how the rows move

When the highlight enters a row, the screen splits. The top 600 pt is the preview: the title's picture full width, the banner's 0.72 left scrim (1100 pt wide) and a fade to `Palette.ground` over its last 160 pt. The tab bar stays over it, as it sits over the banner. The focused row's header starts at y 616 and its posters run from 660 to 978, so the top of the next row's header shows at the bottom of the screen. Rows above the focused one scroll up under the preview and are masked out over a 40 pt fade at y 600, so no poster shows through the picture.

Options considered:
- Keep the banner pinned and show the focused title in it (rejected). The banner's Play, More info and My list would act on a title the highlight is not on, and moving up from the first row would land on buttons for a different title than the banner showed a moment ago.
- A strip of details under the focused row (rejected). It pushes the next row off screen and moves every time the highlight changes row.
- A preview region at the top with the focused row under it (chosen). It matches the TV app, it reuses the banner's picture and copy rules, and the rows keep one fixed place for the highlight.

The row position is a scroll anchor. While a row has focus, the scroll view keeps that row's top at y 616 (`scrollPosition(id:anchor:)` on the row ids, with `ShelfTVScreen` tracking the focused row from `ShelfRowsContent`). The ground band under the tab bar is not drawn while the preview shows, because the preview fills that space.

Moving up from the first row puts the highlight back on Play. The preview fades out over 0.6 s while the scroll returns to the top, and the banner shows the title it showed before, since its index lives in `ShelfBannerHost` and does not change while it is off screen.

### When the preview changes

`PreviewSchedule` in AntennaCore takes focus events (`focused(titleID, at:)`, `left(at:)`) and answers two questions: which title the preview shows, and which title to ask the provider about next. It holds no clock; the host passes `Date` values, so tests drive it with fixed times.

- A title becomes the preview's title once it has been focused for `PreviewSchedule.rest` (0.8 s) with no other focus event in between.
- Until then the preview keeps its current title. On entering the rows from the banner, the current title is the banner's, so the screen fades from the banner title to the rested poster rather than from an empty band.
- Leaving the rows (up to the banner, Menu, a page opening) clears the pending title.

0.8 s is the figure from the owner's request. Shorter and swiping along a row flashes through titles; longer and resting feels unanswered. It is one constant, so a device test can tune it.

The host runs one task keyed on the focused title id. The task sleeps for `rest`, then tells the schedule and the model. A focus change cancels it, so a poster passed on the way never reaches the model.

The change of title uses `ShelfBanner.crossfade` (0.6 s ease in and out), the copy by `.animation(_:value:)` and the picture by `.id(art)` with an opacity transition, as on the banner.

### What the preview shows

`ShelfPreview.Television` in `Apps/Shared/Components/Shelf/` takes a `PreviewContext` (text and art, the same shapes as the banner's `BannerText` and `BannerArt`) through `@Entry var shelfPreview`. It has no buttons and takes no focus.

- Eyebrow: the title's category, 20 pt semibold, accent, uppercase, as the banner's eyebrow. The banner's "Recently added" prefix is left out because the row header already says which row it is.
- Name: 56 pt heavy, two lines at most. Smaller than the banner's 76 pt so three lines of plot fit above the row.
- Facts: the banner's `ShelfBanner.Facts` at 24 pt: year, length or seasons, then the 4K and age badges.
- Plot: 26 pt, three lines, 880 pt wide.
- Picture: `BannerArt.choose` with the same patience, through `ShelfBanner.Picture`, so a poster-only title gets the poster at the right over its blurred copy at 70% of the 600 pt height.

The copy is anchored at the top (x 64, y 168), so a plot that arrives late fades in below the facts and moves nothing above it. The row below has a fixed place, so nothing moves there either.

While the info call is out: the name and category come from the row's `ShelfTitle` and show at once. The picture follows `BannerArt` (nil keeps the old one for up to 1.5 s). Facts and plot fade in when the answer comes. If the answer has no picture and the title has no poster, the picture fades to `Palette.ground`; the previous title's picture never stays under a different name once the 1.5 s have passed.

A failed or offline call shows the name, the category and the poster arrangement, with no error text. The title page is where Retry lives. M3U titles go through `ShelfLoader.details`, which answers from the playlist without a network call.

Continue watching cards for an episode preview the series: the card's `ShelfTitle` is the series, so this needs nothing extra.

### Asking the provider once

`ShelfModel` keeps the parsed info answer per title, `infos: [String: TitleInfo]`, beside `details`. `loadDetails` fills both from one call. `info(_:)`, which the title page calls, returns the kept answer when there is one and calls the provider otherwise. `TitleModel.retry` calls a new `ShelfModel.refreshInfo(_:)` that always asks.

Preview requests go through `ShelfModel.preview(_:)`, which allows one request in flight. A title that rests while a request is out becomes the waiting title, replacing any earlier waiting title. When the request finishes, the waiting title is asked next. Banner requests keep their own path, as today.

The kept answers are capped at 100 titles, oldest dropped first. A series answer carries its episodes, a few hundred kilobytes at most for long shows, so 100 entries stay within a few tens of megabytes on Apple TV in the worst case. They live for the launch and are never written to disk.

Options considered:
- Ask on every focus, cancel on the next (rejected). Cancelling a URLSession task does not stop the panel doing the work, so a fast swipe would still hit the panel once per poster.
- Prefetch the info for every visible poster (rejected). Twenty to forty requests per screen, which is the whole-catalogue load `add-title-metadata` decided against, and the panel load the owner asked to avoid.
- Ask after a rest, one at a time, keep the answer (chosen). A viewer who rests on a poster every second makes one request a second at most, and never two at once. A healthy Xtream panel answers `get_vod_info` in well under a second. No panel's flood limit has been measured; see Risks.

### The banner while the preview shows

`ShelfBannerHost` gets `paused` from the screen. While paused it does not page by itself and does not ask for the next title's details. Its index stays, so the banner comes back on the same title. The hints legend (`add-control-hints`) keeps `.titleRows(kind)`, bottom right, under the rows.

### Menu and Back

Menu from a row keeps the `tvos-shell` rule "Menu from the top of a tab reaches the tab bar": the highlight moves to the tab bar. The scroll returns to the top at the same time, so the banner shows above the bar. Going down from the bar lands on Play.

Back from a title page opened from a poster restores focus on that poster (`title-detail-and-episode-picker/back-to-where-you-were`). The schedule treats a restored focus as rested, so the preview shows that title at once; its details are already kept.

### VoiceOver and motion

On Apple TV VoiceOver follows focus, and the preview never has focus. The focused poster keeps its label (name, year, minutes left) and gets the plot as its `accessibilityHint` once the details are kept, which VoiceOver reads after a short pause, as it reads hints anywhere else. The preview stays in the accessibility tree with identifiers for UI tests.

With Reduce Motion on, the scroll to a row's anchor and back to the banner happen without animation. The fade between titles stays, as on the banner, because a fade is what Reduce Motion asks motion to become.

### iPad and Mac

No hover equivalent in this change.

- The iPad and Mac banner is a card in the scroll content. Once the viewer scrolls to the rows it is off screen, so changing it on hover changes something nobody can see. Pinning it would take a third of a window that is often small on Mac.
- A pointer crosses many posters on its way somewhere. Focus resting on Apple TV means the viewer stopped there; a pointer resting means the hand stopped. Previews would change under a pointer parked between two clicks.
- iPad is mostly touch, which has no hover.
- Both platforms already have a cheap path to the plot: the poster's context menu has More info, and the title page opens beside the rows without losing the scroll position.

A hover card on Mac, a popover over the poster after a rest like Netflix in a browser, would answer the same wish. It is listed as an open question rather than built here.

## Boards

New, under `openspec/specs/design-system/boards/`:
- `TV-Movies-Preview`: the highlight resting on a poster in the Thriller row, the preview with a backdrop.
- `TV-Movies-Preview-Loading`: the moment after a rest, with the name and category of the new title over the previous picture and no facts or plot yet.
- `TV-Movies-Preview-Poster-Only`: the preview for a title without a backdrop.

Follows: `TV-Movies`, `TV-Movies-Rows`, `TV-Movies-Poster-Only`, `TV-Hints-Movies`. Series uses the same boards with Series in the tab bar, seasons in place of the length and no 4K badge.

Not drawn: the preview over Continue watching (same layout, the row's landscape cards under it), a failed call (the Poster-Only board without facts or plot, text styles as drawn), and the fade between titles, which is motion and is described above.

Design-system requirements followed: "Movies and series open content first" (the banner still opens the screen), "Focus is the lifted white card" (the preview takes no focus and nothing in it is white-filled), "One accent color", "Text stays above the platform caption floor" (the smallest text is the 20 pt eyebrow), "Text meets contrast minimums" (the copy keeps the 0.72 scrim), "Apple TV content stays in the safe area", "Accessibility identifiers follow the board".

## Identifiers

- `movies.preview`, `series.preview`: the preview.
- `movies.preview.title`, `.facts`, `.plot`: its parts, under the screen prefix.
- `shelf.debug.infoLoads`: Debug-only, the number of info calls the UI-testing shelf has answered, so a UI test can check that a fast swipe asks nothing.

## Risks

- A panel with strict flood protection could still object to one request a second from a viewer resting on every poster. That is faster than the banner's two requests every eight seconds, though each request is one the viewer would otherwise make by opening the page. If a real panel objects, `PreviewSchedule.rest` and a minimum gap between requests are the knobs.
- Scroll anchoring in a lazy stack on tvOS can fight the focus engine's own scrolling. The UI test checks the focused row's frame after each move; the fallback is a custom `ScrollTargetBehavior` that snaps the focused row's top to 616.

## Open questions

1. **A hover card on Mac?** Recommend not now. Revisit if Mac use grows; the preview component can be reused in a popover.
2. **Preview in the poster grid?** Recommend no. The grid fills the screen with posters; a preview would push it down to two rows.
3. **Keep the "Recently added" eyebrow?** Recommend the category only, since the row header already names the row.
