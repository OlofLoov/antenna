Moved from `add-feature-website` on 2026-11-27: task 5.3, the badge from 3.2, the boards from 1.4 that are not about languages, and the browser part of 7.2.

## 1. Store addresses

- [ ] 1.1 Add `marketing_url.txt` per locale and check it, `support_url.txt` and `privacy_url.txt` in `scripts/store_metadata.py`, with a `StoreListingTests` case for a support address left on the Terms, citing `store-listing/the-listing-links-to-the-site-s-pages` [5.3]

## 2. Boards

- [ ] 2.1 Draw the light appearance, feature pages, pricing and support at phone width, the legal pages with the header and footer, `404.html` and "Coming soon to the App Store" [1.4]

## 3. App Store badge

- [ ] 3.1 Once Antuna's App Store page exists, commit Apple's App Store badge as SVG and show it with the page's link in place of "Coming soon to the App Store" [3.2]

## 4. Verify

- [ ] 4.1 In a browser, follow the header and footer links with JavaScript on and confirm each page opens without a full reload and Back returns to the page before [7.2]
- [ ] 4.2 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 4.3 `/opsx:verify` passes
