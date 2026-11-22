## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-feature-website --strict`
- [x] 1.2 Draw draft boards `Web-Home`, `Web-Home-Phone`, `Web-Feature`, `Web-Pricing` and `Web-Support`
- [ ] 1.3 Get the owner's answers to the open questions in design.md and fold them into the design and specs
- [ ] 1.4 Draw the boards listed under "Not drawn yet" in design.md: light appearance, phone widths of the other pages, the legal pages with the header and footer, `404.html` and "Coming soon to the App Store"

## 2. Page builder and layout

- [ ] 2.1 Add `scripts/build-site.py` (stdlib only), `Web/layout.html`, `Web/site.css` with logical properties and both appearances, and `Web/strings/en.json`; call it from `scripts/publish-web.sh`, keeping the setup page, the association file and the review files as they are
- [ ] 2.2 Move the Terms of Use and Privacy Policy into the layout with the header and footer, contact through the support page instead of an email address, and update `WebsiteTests`, citing `feature-website/every-page-shares-one-header-and-footer` and `antenna-website/the-legal-pages-are-dated-and-link-to-each-other`
- [ ] 2.3 Amend the image rule in `WebsiteTests` (own images only, sizes, `alt`, `width`, `height`, the 500 KB home budget) and CLAUDE.md's `Web/` line, citing `antenna-website/the-pages-read-on-a-phone-and-in-dark-mode`

## 3. Screenshots

- [ ] 3.1 Add `scripts/site-screenshots.sh` and `Web/images/screenshots.txt`: download the newest `store-screenshots` artifact, pick the listed files, resize with `sips`, write JPEG to `Web/images/en/`, fail on a missing file
- [ ] 3.2 Run it and commit the English set, and Apple's App Store badge as SVG
- [ ] 3.3 Add the provider-name check over every page's text with the listing check's list, citing `feature-website/nothing-on-the-site-points-to-a-provider`

## 4. Home and feature pages

- [ ] 4.1 Add the home page with the hero and nine sections, and `/features/`, citing `feature-website/the-home-page-says-what-antenna-is`
- [ ] 4.2 Add the nine area pages from the inventory in design.md, each saying which platforms have each feature, citing `feature-website/every-feature-area-has-a-section-and-a-page` and `feature-website/the-site-shows-only-what-the-app-does`

## 5. Pricing and support

- [ ] 5.1 Add the pricing page with no amounts, citing `feature-website/pricing-says-how-buying-works`
- [ ] 5.2 Add the support page with the FAQ and the Report a problem section, and a test that no page holds an email address, citing `feature-website/support-answers-questions-and-points-to-the-app`
- [ ] 5.3 Point every `fastlane/metadata/*/support_url.txt` at `/support/`, add `marketing_url.txt` per locale, and check both in `scripts/store_metadata.py`, citing `store-listing/the-listing-links-to-the-site-s-pages`

## 6. Languages

Later, one PR per language, when its store listing is ready.

- [ ] 6.1 Add the language folders, `hreflang` links and the footer language list to the builder, with a test that a language with an unready listing is not published, citing `feature-website/languages-are-added-when-their-listing-is-ready`
- [ ] 6.2 Add Swedish: `Web/strings/sv.json` and the Swedish screenshots
- [ ] 6.3 Add Arabic with `dir="rtl"` when its listing is no longer held, and check the boards' right-to-left versions first

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 7.2 `/opsx:verify` passes
