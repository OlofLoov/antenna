## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-feature-website --strict`
- [x] 1.2 Draw draft boards `Web-Home`, `Web-Home-Phone`, `Web-Feature`, `Web-Pricing` and `Web-Support`
- [x] 1.3 Fold in the owner's 2026-11-22 decisions on the open questions, and rework the page builder into a prerendered SvelteKit app
- [ ] 1.4 Draw the boards listed under "Not drawn yet" in design.md: light appearance, phone widths of the other pages, the legal pages with the header and footer, `404.html` and "Coming soon to the App Store"

## 2. The app, CI and the CSP

- [ ] 2.1 Add `Web/site/`: SvelteKit with `adapter-static`, no fallback, `prerender = true`, `trailingSlash = 'always'`, `paths.relative = false`, `inlineStyleThreshold = 0`, prerender errors failing the build, the root layout with the header and footer, `src/lib/strings/en.json`, the stylesheet in logical properties with both appearances, the `/404.html` route, `.nvmrc` with 22, `engines`, and the committed `package-lock.json`; git-ignore `build/` and `node_modules/`; record the measured script size in design.md decision 2, citing `feature-website/every-page-reads-without-scripts` and `feature-website/moving-between-pages-needs-no-reload`
- [ ] 2.2 Add `Web/site/scripts/externalize-start.js` to `npm run build`, and `Web/site/scripts/check-site.js` with the Vitest checks from design.md decision 2: every route built with its text in the HTML, links and anchors resolve, `/setup/` links reload, no inline script, `on*=` or `style=`, nothing from another address, and the budgets from decision 3, citing `antenna-website/the-pages-read-on-a-phone-and-in-dark-mode` and `feature-website/every-page-reads-without-scripts`
- [ ] 2.3 Add the `site` job to `.github/workflows/ci.yml` (Node from `.nvmrc`, `npm ci`, lint, `svelte-check`, build, test), make `scripts/check-spec-refs.sh` read citations in `Web/site/tests/` and `Web/site/scripts/`, and add the site's commands to CLAUDE.md's Commands list
- [ ] 2.4 Make `scripts/publish-web.sh` take the site build as a second argument and fail on a path both hold; if `add-aws-hosting` shipped first with the no-script policy, set the site policy from its design.md decision 3 in `AntennaSite` and its assertion test in the same PR
- [ ] 2.5 Move the Terms of Use and Privacy Policy into `Web/site/src/routes/terms/` and `privacy/` with the header and footer, contact through the support page instead of an email address; point `WebsiteTests` at the route files and move its tag check to the site check, citing `feature-website/every-page-shares-one-header-and-footer` and `antenna-website/the-legal-pages-are-dated-and-link-to-each-other`
- [ ] 2.6 Amend CLAUDE.md's `Web/` line to allow the site's own bundled JavaScript and images, with no third-party scripts, fonts, trackers, analytics or requests to other origins, and name `Web/site/` and the static files that stay outside it

## 3. Screenshots

- [ ] 3.1 Add `scripts/site-screenshots.sh` and `Web/site/static/images/screenshots.txt`: download the newest `store-screenshots` artifact, pick the listed files, resize with `sips`, write JPEG to `Web/site/static/images/en/`, fail on a missing file
- [ ] 3.2 Run it and commit the English set, and Apple's App Store badge as SVG
- [ ] 3.3 Add the provider-name check over every built page's text with the listing check's list, citing `feature-website/nothing-on-the-site-points-to-a-provider`

## 4. Home and feature pages

- [ ] 4.1 Add the home page with the hero line "Your TV sources, on every Apple screen." and nine sections, and `/features/`, citing `feature-website/the-home-page-says-what-antenna-is`
- [ ] 4.2 Add the nine area pages from the inventory in design.md, each saying which platforms have each feature, citing `feature-website/every-feature-area-has-a-section-and-a-page` and `feature-website/the-site-shows-only-what-the-app-does`

## 5. Pricing and support

- [ ] 5.1 Add the pricing page with no amounts, citing `feature-website/pricing-says-how-buying-works`
- [ ] 5.2 Add the support page with the FAQ and the Report a problem section, saying the form is coming if `add-support-requests` has not shipped, and a site check that no page holds an email address, citing `feature-website/support-answers-questions-and-points-to-the-app`
- [ ] 5.3 Point every `fastlane/metadata/*/support_url.txt` at `/support/`, add `marketing_url.txt` per locale, and check both in `scripts/store_metadata.py`, citing `store-listing/the-listing-links-to-the-site-s-pages`

## 6. Languages

One PR per language, when its store listing is ready. Swedish first.

- [ ] 6.1 Add the optional `[[lang=lang]]` route parameter with a matcher of published languages, `entries` per language, `lang` and `dir` from `hooks.server.ts`, `hreflang` links and the footer language list with full-reload links, with a site check that an unpublished language answers 404 and a missing string fails the build, citing `feature-website/languages-are-added-when-their-listing-is-ready`
- [ ] 6.2 Add Swedish: `src/lib/strings/sv.json` and the Swedish screenshots, reviewed by the owner
- [ ] 6.3 Add Arabic with `dir="rtl"` when its listing is no longer held, after the boards' right-to-left versions are drawn

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 7.2 After the first deploy, open a page with JavaScript off, follow links with it on, open a made-up address and check its 404 status, and read the CSP header in the browser's network panel
- [ ] 7.3 `/opsx:verify` passes
