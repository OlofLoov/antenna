# Design

## Context

The site at antuna.app is live, built from `Web/site/` by `add-feature-website`. Every `support_url.txt` under `fastlane/metadata/` is `https://antuna.app/support/` and every `privacy_url.txt` is `https://antuna.app/privacy`. `scripts/store_metadata.py` checks only that both start with `https://antuna.app/`. No listing has a `marketing_url.txt`. The home page and footer say "Coming soon to the App Store" in place of a badge.

## Boards

Not drawn yet, and drawn in this change as drafts beside the existing `Web-` boards:
- The light appearance of every page.
- Feature pages, pricing and support at phone width.
- The Terms and Privacy pages with the header and footer.
- `404.html`.
- "Coming soon to the App Store" in place of the badge.

## Decisions

### 1. The listing check

`URL_FIELDS` in `scripts/store_metadata.py` gains `marketing_url`. The check fails, naming the locale and the field, when a support address does not end in `/support/`, a privacy address does not end in `/privacy`, or a marketing address is not `https://antuna.app/`.

### 2. The badge

As `add-feature-website` decision 3 says: Apple's artwork, used as Apple's marketing guidelines allow, downloaded once and committed as SVG, never loaded from Apple. It links to Antuna's App Store page, which the site check already allows as the one outside link.

## Risks / Trade-offs

- Apple's badge guidelines change from time to time, so the committed SVG must be the current one at each submission.

## Open Questions

None.
