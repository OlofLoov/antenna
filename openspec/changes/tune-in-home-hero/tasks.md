## 1. Proposal and boards

- [x] 1.1 Write the proposal, the delta spec, design.md and tasks.md
- [x] 1.2 Draw the new hero on `Web-Home.dc.html` and `Web-Home-Phone.dc.html`

## 2. Screenshots

- [ ] 2.1 Add the seven lines from design.md decision 5 to `screenshots.txt` and run `scripts/site-screenshots.sh en` against the store set

## 3. Hero

- [ ] 3.1 Add `src/lib/tuneIn.ts` with the channels, the timings from design.md decision 1 and the rule for when the zapping runs
- [ ] 3.2 Add `HeroTuneIn.svelte`: the wordmark with Hello and the rings, the TV with the static, the snap and the channel number, the iPad and iPhone, the glow and the pause button, with the Reduce Motion form
- [ ] 3.3 Zap every four seconds, load each channel before its turn, drift with the pointer and the scroll, and stop off screen, in a hidden tab and with Reduce Motion
- [ ] 3.4 Use it in the home page and move `home.heroAlt` into `home.tuneIn`

## 4. Tests

- [ ] 4.1 Site tests citing `antuna-website/the-home-page-tunes-in`, `antuna-website/the-tv-zaps-through-the-app` and `antuna-website/the-hero-holds-still-with-reduce-motion`
- [ ] 4.2 Look at the built page in a browser at desktop and phone widths, with and without Reduce Motion, at several points in the timeline

## 5. Verify

- [ ] 5.1 The site's lint, check, build and tests, `openspec validate --all --strict`, `check-spec-refs` and `publish-web.sh` pass, and the home page is within its budgets
- [ ] 5.2 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 5.3 `/opsx:verify` passes
