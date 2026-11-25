# Tasks

## 1. Proposal

- [x] 1.1 Proposal, delta spec, design and tasks

## 2. The demo server

- [x] 2.1 `scripts/make-store-art.py` draws the review art into `Web/review/art/`; commit the JPEGs
- [x] 2.2 `scripts/make-review-xtream.py` writes the catalogue files; `scripts/publish-web.sh` runs it into `review/xtream` with `$REVIEW_BASE_URL` or `https://antuna.app/review`
- [x] 2.3 `Infra/modules/site/review.js`, the `antuna-review-server` function and the `/review/*` behavior
- [x] 2.4 `Infra/modules/site/tests/review.test.mjs` on `node --test`; the Infra workflow runs it and watches `Web/review/**` and the generator
- [x] 2.5 `ReviewServerTests` in AntennaCore; `site.tftest.hcl` runs for the behavior and the function
- [x] 2.6 `docs/release/app-review-notes.md`: the server address, the login, the steps on iPhone and Apple TV, the playlist as fallback, the curl checks
- [x] 2.7 The container diagram's CDN box names the review server; CLAUDE.md lists the Node test
- [x] 2.8 Serve the published folder through `review.js` locally, run the app's `XtreamClient` against it, and play a channel, a movie and an episode from the addresses it builds on AVPlayer
- [ ] 2.9 After the owner applies and the site publishes, add the demo server on an iPhone and an Apple TV and run the curl checks in the review notes

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 3.2 `/opsx:verify` passes
