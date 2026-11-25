# Tasks

## 1. Proposal

- [x] 1.1 Proposal, delta spec, design and tasks

## 2. Hero

- [x] 2.1 `tuneIn.ts`: the timings from design.md decision 6 and `mayAnimate`
- [x] 2.2 `TuneInWordmark.svelte`: overlay shapes, the draw-on, one Tuning loop and Got it, held by the `held` flag
- [x] 2.3 `TuneInStage.svelte`: static until 4.0 s, the picture under a cover, tuned when its animations finish, `held` bound to the page, the hero section observed
- [x] 2.4 Site tests citing `antuna-website/the-home-page-tunes-in` and `antuna-website/the-tv-zaps-through-the-app`
- [x] 2.5 Frames from WebKit and Firefox at the draw-on, both leans, the blink, Got it and the rest, at desktop and phone widths

## 3. Verify

- [x] 3.1 The site's lint, check, build and tests, `openspec validate --all --strict`, `check-spec-refs` and `publish-web.sh` pass, and the home page is within its budgets
- [x] 3.2 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.3 `/opsx:verify` passes
