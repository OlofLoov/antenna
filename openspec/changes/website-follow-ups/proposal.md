# Proposal

## Why

Split from `add-feature-website` on 2026-11-27, when that change was archived with the site live at antuna.app. These are the open tasks that were not about languages. Each is small, and most wait on something outside the repo.

> As someone who found Antuna in the App Store, I want the listing's website link to open the home page.

> As a visitor on the home page, I want a button that takes me to Antuna on the App Store once it is there.

## What Changes

- A marketing address in every store listing, `https://antuna.app/`, and the listing check making sure every support address ends in `/support/`, every privacy address in `/privacy`, and every marketing address is the home page.
- Apple's "Download on the App Store" badge, committed as SVG, in place of "Coming soon to the App Store" once Antuna's App Store page exists.
- Boards for what the site shows today but no board draws: the light appearance, feature pages, pricing and support at phone width, the legal pages with the header and footer, `404.html` and "Coming soon to the App Store".
- A check in a browser that following links with JavaScript on opens pages without a reload.

Out of scope:
- Languages (`website-languages`).
- New pages or features on the site.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `store-listing`: the listing links to the site's pages.

## Impact

- Store: `fastlane/metadata/*/marketing_url.txt`, and `scripts/store_metadata.py` with its tests in `StoreListingTests`.
- Web: the badge in `Web/site/static/images/` and the home page and footer that show it.
- Boards: drafts in `openspec/specs/design-system/boards/`.
- Blocked on: Antuna's App Store page for the badge. The rest can be done any time.
- Depends on the archived `add-feature-website`.
