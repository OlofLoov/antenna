# Tasks

## 1. Fix

- [x] 1.1 Profile tiles: a button style that draws the label alone, and on Apple TV a lift and shadow drawn by the circle itself
- [x] 1.2 Season chips: clip the row to itself with room above and below for the focused chip, count at the trailing edge
- [x] 1.3 `HeroScrim` and `HeroFootScrim`: one gradient across the picture, darkest under the copy, mirrored in right-to-left languages
- [x] 1.4 The Apple TV, iPad and iPhone banners, the Apple TV preview and the Apple TV and iPad title pages use them
- [x] 1.5 Boards and the design-system reference draw the hero scrim; `scripts/check-rules.sh` fails on a flat block over art
- [x] 1.6 `-ui-testing-many-seasons` and previews of the season row with fifteen seasons

## 2. Tests

- [x] 2.1 Unit test: the hero scrim and the banners have no step across their width, and the dark side follows the reading direction
- [x] 2.2 UI test on Apple TV: the focused profile circle is round and has only the ground color around it
- [x] 2.3 UI tests on iPhone and Apple TV: with fifteen seasons no chip draws over the episode count

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
