# Proposal

## Why

> As a movie and series watcher, I want the button that keeps a title for later to say what it does, so I don't have to guess what a plus sign means.
>
> As a living-room viewer on Apple TV, I want the buttons in the channel list to look like the buttons everywhere else in the app.

The owner reported two things from a device on 2026-11-20:

1. "It's not obvious what the plus sign is in series. It's for adding to my list." My list on the banner and on a title page was a plus, or a check once added, alone in a square. Apple's Human Interface Guidelines prefer a text label when a symbol's meaning is not clear to everyone.
2. "Buttons in the channel group browser / channel browser are not the same ones as the rest of the app. Seems to use an outer line." On Apple TV every group row, channel row, next-programme row and the Watch and favorite buttons in the channel overlay had a thin light rim at rest. The highlight hover effect draws it on any view that carries it, focused or not. Watch and the star were also drawn by the app instead of using the system button styles that Watch in the Guide uses.

## What Changes

- My list on the Movies and Series banner and on a title page reads "Add to My list", and "Remove from My list" once added, on iPhone, iPad, Mac and Apple TV. No glyph.
- On iPhone the banner's buttons take two rows: Play and Info, then Trailer and My list. Trailer shows its word next to its glyph, as on iPad and Mac. On the iPhone title page Play spans the width, with My list and Trailer under it.
- On iPad and Mac the banner's buttons may run past the width of the copy above them.
- On Apple TV the highlight hover effect applies only to the focused element, in the shape of its card. Rows and buttons at rest have no rim. This covers the channel overlay, episode rows, cast chips and the multi-view picker, which share the focus card.
- The channel overlay's Watch, favorite and Add to multi-view buttons use the system styles: Watch the primary one, the other two the secondary one.
- The LIVE button that returns to live from behind, on iPhone, iPad and Mac, drops its outline and takes the badge's surface fill.
- `scripts/check-rules.sh` fails on a stroke or border in a button's label.

Out of scope:
- The outlined quality and rating badges (HD, 4K, 15) on the banner, the zap bar and the overlay panel. They are labels, not buttons.
- The ring around the picked profile color. It marks the choice; the check-rules scan names those two files as exceptions.
- The dashed Add profile circle on Apple TV, a tile in the profile picker modeled on the system's own.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `title-detail-and-episode-picker`: "My list from the page" names the words on the button.
- `movies-and-series-browsing`: "Keep a list for later" names the words on the banner button; "Rating and trailer on the banner" changes its iPhone scenario to two rows.
- `design-system`: "Focus is the lifted white card" gains a scenario for elements at rest; "Controls use system styles" gains one for outlined buttons.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV.
- Builds on `add-title-detail`, `add-movies-and-series` and `add-tv-channel-overlay`, all archived, and on `redesign-group-picker` for the Groups sheet, which needed no change: its rows and close button already use plain and system styles.
- The strings "Add to My list" and "Remove from My list" exist in every catalog language. The title page's lowercase "my list" strings go.
