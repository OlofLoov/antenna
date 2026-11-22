# Proposal

## Why

The owner, on 2026-11-22: a static website that shows every feature of the app, hosted on the new domain from `add-aws-hosting`.

> As someone deciding whether to pay for Antenna, I want to see what it does on my Apple TV and iPhone, which of my sources it takes, and what it costs, before I download it.

> As a household setter-upper, I want to read how setting up the Apple TV from my iPhone works, so I know I will not be typing passwords with the remote.

> As a user with a problem, I want a support page that answers the common questions and tells me how to report the rest from the app.

Today the site is a setup page, the Terms of Use, the Privacy Policy and the App Review playlist. Nothing on it says what Antenna does, the App Store support address points at the Terms, and the site's own rules forbid images, so it cannot show a screenshot.

After this change the site has a home page with a hero and a section per feature area, one page for each area, a pricing page, a support page with an FAQ, and the existing setup page, Terms and Privacy Policy, all in English. The screenshots are the App Store set the screenshot workflow already takes, with made-up channels and titles only.

## What Changes

- A home page: what Antenna is in one line, the four platforms, "no channels included", an App Store link, and one section per feature area with a screenshot and a link to its page.
- Nine feature pages, grouped the way a buyer thinks: sources, live TV, guide, movies and series, multi-view, Apple TV, setup from iPhone, sync and profiles, privacy. design.md maps every capability in `openspec/specs/` to one of them.
- A pricing page: free to download, a purchase needed to use it, lifetime or yearly, Family Sharing, the price shown in the App Store for the buyer's region. No prices written on the site.
- A support page: an FAQ and "Report a problem" in the app's Settings. No email address. The App Store support address points here.
- The site may show its own images: screenshots from the store set, committed after review, and Apple's App Store badge. Still no scripts, no third-party fonts, trackers or analytics, and nothing loaded from another address.
- The Terms of Use and Privacy Policy keep their text, link to the support page for contact instead of an email address, and share the new header and footer.
- A small page builder in `scripts/` so the pages share one header, footer and stylesheet.
- English first. Other languages later, each when its store listing is ready, with Arabic right to left.

Out of scope:
- Hosting, the domain and the deploy workflow (`add-aws-hosting`).
- The in-app Report a problem form (`add-support-requests`). The support page only names it.
- A contact form, newsletter, blog, changelog page, press kit or search.
- Analytics of any kind, including server-side counts by page.
- Languages other than English in this change.
- Features from changes not yet archived, such as movie scores from `add-title-metadata`. They are added to the site when they ship.

## Capabilities

### New Capabilities
- `feature-website`: the home page, feature pages, pricing and support pages, what screenshots may show, and how languages are added.

### Modified Capabilities
- `antenna-website`: every page reads on a phone and in dark mode, first-party images are allowed, and nothing loads from another address.
- `store-listing`: the support address opens the support page, and the listing gives a marketing address.

## Impact

- Web: new pages under `Web/` (`index.html`, `features/<area>/`, `pricing/`, `support/`, `404.html` if `add-aws-hosting` has not added it), `Web/site.css`, `Web/images/`. The legal pages gain the header and footer.
- Scripts: `scripts/build-site.py` (stdlib only), called from `scripts/publish-web.sh`; `scripts/site-screenshots.sh` to pick and resize store screenshots.
- Tests: `WebsiteTests` gains the new pages and the image rules; the "no `<img>`" check becomes "no image from another address".
- Store: `fastlane/metadata/*/support_url.txt` move to `/support`; a `marketing_url.txt` per locale; `scripts/store_metadata.py` checks both.
- CLAUDE.md's `Web/` line ("No scripts, images or third-party content") changes to allow first-party images.
- Boards: new drafts `Web-Home`, `Web-Home-Phone`, `Web-Feature`, `Web-Pricing` and `Web-Support`.
- Depends on `add-aws-hosting` for the host and the domain. It can be built and reviewed on GitHub Pages before that, but the store addresses move only when the new domain serves.
- The support page's "Report a problem" answer depends on `add-support-requests` shipping. Until then the page says the form is coming and lists the FAQ only (design.md, open question 4).
- Blocked on: the owner's answers to the open questions in design.md, above all prices on the site (3) and the support page before the in-app form (4).
