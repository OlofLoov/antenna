Moved from `add-feature-website` on 2026-11-27: its tasks 6.1 to 6.3 and the language boards from 1.4. One PR per language, when its store listing is ready.

## 1. Language routes

- [ ] 1.1 Draw the footer language list on `Web-Home` and `Web-Home-Phone`
- [ ] 1.2 Add the optional `[[lang=lang]]` route parameter with a matcher of published languages, `entries` per language, `lang` and `dir` from `hooks.server.ts`, `hreflang` links and the footer language list with full-reload links, with a site check that an unpublished language answers 404 and a missing string fails the build, citing `feature-website/languages-are-added-when-their-listing-is-ready`

## 2. Swedish

- [ ] 2.1 Add `src/lib/strings/sv.json` and the Swedish screenshots, reviewed by the owner

## 3. Arabic

- [ ] 3.1 Draw right-to-left versions of `Web-Home`, `Web-Home-Phone`, `Web-Feature`, `Web-Pricing` and `Web-Support`
- [ ] 3.2 Add Arabic with `dir="rtl"` when its listing is no longer held

## 4. Verify

- [ ] 4.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 4.2 `/opsx:verify` passes
