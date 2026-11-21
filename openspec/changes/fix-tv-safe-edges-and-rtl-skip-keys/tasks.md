## 1. Apple TV safe edges

- [x] 1.1 Search results and recents (no side padding inside the stack's own safe area), the Movies and Series hero copy and dots, the preview copy, the shelf rows and grids and the person page use the 80 pt safe sides
- [x] 1.2 The paywall pads with `Metrics.televisionSafeArea` instead of 64, 44 and 56
- [x] 1.3 The number box and the hero scrim, search and guide previews read `Metrics.televisionSafeArea`
- [x] 1.4 Apple TV boards draw 80 pt sides; the number box, swap badge and paywall wordmark sit at y 60; `reference.md` says which pages pad themselves
- [x] 1.5 Frame tests on Movies, Search and the paywall

## 2. Right-to-left skip keys

- [x] 2.1 `KeyCommand.combination(rightToLeft:)` swaps the skip arrows, with a core test
- [x] 2.2 The movie player's and Live's hidden skip keys and the Playback menu follow the reading direction
- [x] 2.3 `reference.md` and design.md record the HIG finding
- [x] 2.4 Arabic iPhone test: the bar runs from the right and Left Arrow skips forward

## 3. Verify

- [x] 3.1 Each requirement this change modifies has a test citing `design-system/apple-tv-content-stays-in-the-safe-area` or `design-system/progress-runs-in-the-reading-direction`
- [x] 3.2 The touched UI test classes pass on the Apple TV and iPhone simulators
- [x] 3.3 /opsx:verify passes
