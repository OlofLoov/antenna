# Tasks

## 1. Proposal

- [x] 1.1 Proposal, delta spec, design and tasks

## 2. The demo server

- [ ] 2.1 `scripts/make-store-art.py` draws the review art into `Web/review/art/`; commit the JPEGs
- [ ] 2.2 `scripts/make-review-xtream.py` writes the catalogue files; `scripts/publish-web.sh` runs it into `review/xtream` with `$REVIEW_BASE_URL` or `https://antuna.app/review`
- [ ] 2.3 `Infra/modules/site/review.js`, the `antuna-review-server` function and the `/review/*` behavior
- [ ] 2.4 `Infra/modules/site/tests/review.test.mjs` on `node --test`; the Infra workflow runs it and watches `Web/review/**` and the generator
- [ ] 2.5 `ReviewServerTests` in AntennaCore; `site.tftest.hcl` runs for the behavior and the function
- [ ] 2.6 `docs/release/app-review-notes.md`: the server address, the login, the steps on iPhone and Apple TV, the playlist as fallback, the curl checks
- [ ] 2.7 The container diagram's CDN box names the review server; CLAUDE.md lists the Node test
- [ ] 2.8 Serve the published folder through `review.js` locally, add it as an Xtream source in the iOS simulator, and play a channel, a movie and an episode

## 3. Verify

- [ ] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
