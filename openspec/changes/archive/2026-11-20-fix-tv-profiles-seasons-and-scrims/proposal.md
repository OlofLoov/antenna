# Proposal

## Why

The owner found three problems testing on a real Apple TV on 2026-11-19:

> "the glass effect on whos watching makes the circle for the user to extend all the way to the edges thus the edge of the circle is cut."

> "when a series has loads of seasons the season tab menu overlaps with the no of episodes per season."

> "there is still an issue with the top image and top serie with a text overlay only covering part of the screen effectively dividing an image in two where one part has a shadow like overlay and one part does not."

Someone choosing a profile should see the whole lifted circle. Someone opening a long-running series should be able to read the episode count and scroll the seasons. Someone browsing Movies and Series should see one picture under the copy, darker where the text is.

What the code does today:

- `refresh-visual-design` made each profile tile a borderless button with the highlight hover effect on its circle. On Apple TV that effect, and the borderless button too, lifts the circle on a rounded square platter the size of the circle and cuts the grown circle to it, so its sides and top are cut off.
- The season chips scroll in a row next to the episode count, with clipping turned off so a focused chip's lift is not cut. Chips past the end of the row therefore draw over the count. With three seasons nothing reaches it; with fifteen the chips run across it.
- The Movies and Series banner, the Apple TV preview and the iPad banner darken the art with a flat block 1100 pt (Apple TV) or 560 pt (iPad) wide, with a hard edge in the middle of the picture. The iPhone banner puts its copy on a flat band with a hard top edge. The boards draw the same blocks. The title pages on Apple TV and iPad use a gradient, but it does not mirror, so in Arabic the copy sits on the light side.

## What Changes

- On Apple TV the focused profile circle, on "Who's watching?" and at the top of Settings, grows by a tenth and casts a shadow, drawn by the circle itself. The button draws no platter, so nothing cuts the circle.
- The season chips are cut to their own row, with room above and below for a focused chip's lift, so they scroll under nothing. The count keeps its place at the trailing edge.
- One hero scrim, a gradient across the whole picture that is darkest under the copy and fades out toward the trailing edge, replaces the flat blocks on the banner, the Apple TV preview and the title pages. On iPhone the copy's band fades in over the 56 pt above the copy. The scrim mirrors in right-to-left languages. The boards and the design-system reference change with it.

Out of scope:
- The Apple TV tab bar and shell, which `adopt-tvos-tab-view` moved to the system tab view. Its profile button, now at the top of Settings, gets the same circle fix.
- The iPhone title page, whose copy sits under the picture and keeps its foot fade.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `design-system`: adds "The scrim blends into the art".
- `profiles`: "Who's watching at launch" says the focused circle shows whole.
- `title-detail-and-episode-picker`: "Pick a season" covers a series with many seasons.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV. The profile circle fix is Apple TV only, since the lift and the cut happen only there.
- Code: `ProfilePicker`, `ProfileSwitchButton`, `EpisodePicker.Seasons`, a `HeroScrim` component used by `ShelfBanner`, `ShelfPreview` and `TitlePage`. A fifteen-season series in the UI testing catalogue.
- Boards: the TV, iPad and iPhone Movies, Series, preview and title boards that drew the flat scrim.
- Depends on `refresh-visual-design`, archived.
