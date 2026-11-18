# Proposal

## Why

The owner reported four problems on Apple TV on 2026-11-18, all while browsing Movies and Series:

> "the content hero images for all series and movies is not displayed properly seems like it is scaled and not so it is actually fitting the area, seems stretched."

> "the modal for like series etc does not seem to display all content of a text?"

> "sometimes when just browsing the existing movies etc it seems like we get a really long call somewhere the ui is locked at least."

> "trending is only displayed once?"

As a movie and series watcher on Apple TV, I want the banner and title page pictures to look like the pictures they are, every word of a description and its cast within reach of the remote, a library of tens of thousands of titles that never freezes the screen, and a banner that moves on to the next new title by itself.

What the code does today:

- Many Xtream providers put the poster in the field meant for the backdrop. The banner and the title page trust the field and scale the picture to cover a 3:1 or 16:9 frame, so a 2:3 poster is blown up about three times and cut to a strip of its middle.
- The title page cuts the description to four lines on a movie and two on a series, with More opening a sheet that the remote cannot scroll. Cast and director stop at two lines with nothing to open, and each episode shows one line of its description with no way to read the rest.
- Every load of a source sorts the whole catalogue three times on the main thread, and the rows, Continue watching and Recently watched rebuild an index of every title each time the screen redraws. With 50 000 movies that is several hundred milliseconds per redraw, and opening All movies sorts all 50 000 again on every redraw.
- Focus lands on the banner's Play button when Movies opens, and focus on the banner holds it. On Apple TV the banner therefore never moves by itself: the first new title is the only one the viewer sees.

## What Changes

- The banner and the title page pick the layout from the picture's real shape. A picture that would lose more than half of itself to fill a wide frame shows whole at the right over a blurred copy of itself, the layout posters already use. A wide picture fills the frame, keeping its proportions. Nothing is ever stretched.
- More on Apple TV opens the whole description with the cast and director on a full-screen page that the remote scrolls and Menu closes. On iPhone, iPad and Mac, More already shows the description in place; it now shows the cast and director in full too. An episode with a description offers Description in its menu, long press on Apple TV, which opens the same page for the episode.
- On Apple TV, focus on the banner's buttons no longer stops the banner. Each move between its buttons, or paging by hand, starts the eight seconds again. iPhone, iPad and Mac keep holding the banner while a finger, the pointer or focus is on it.
- The section's rows, banner and newest-first order are built once per load, off the main thread. Continue watching, Recently watched, My list and the grids read that index instead of walking every title. Poster decoding leaves the poster cache's queue so posters decode in parallel. Signposts mark loading, indexing and decoding, and AntennaCore tests time a catalogue of 50 000 movies and 10 000 series.
- A playlist series that is missing from the kept load asks the playlist again at most once every five minutes per source.

Out of scope:
- A Trending row. It needs `add-discover-rows` and the lookup server.
- Downsampling posters to tile size. The cache keeps decoded originals, as before.
- A new banner layout on Apple TV.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `movies-and-series-browsing`: "New titles up front" gains the Apple TV rotation rule and the shape rule for pictures; a new requirement "Browsing stays responsive" sets what the screen does with a large library.
- `title-detail-and-episode-picker`: "What the title is about" gains the full text page and the shape rule; "What each episode shows" gains Description.

## Impact

- Platforms: the shape rule, the full description and the speed work apply on iPhone, iPad, Mac and Apple TV. The rotation change is Apple TV only, since only there does focus rest on the banner by default.
- Depends on `movies-and-series-browsing` and `title-detail-and-episode-picker` as archived, and on the poster-only banner from PR #365.
- Builds on `add-focused-title-preview` (PR #386). Its preview draws pictures through the banner's picture view, so it gets the shape rule too, and the index work reads its shared info answers unchanged. This change edits only the banner buttons' focus tracking on the Apple TV Movies screen.
