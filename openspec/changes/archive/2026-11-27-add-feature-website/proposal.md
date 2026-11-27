# Proposal

Tidied on 2026-11-27 with the site live at antuna.app. Languages (the Swedish and Arabic part below, and the requirement "Languages are added when their listing is ready") moved to `website-languages`. The marketing address and the listing check (the `store-listing` delta), the App Store badge and the boards not yet drawn moved to `website-follow-ups`. The text below is the proposal as first written.

## Why

The owner, on 2026-11-22: a website that shows every feature of the app, hosted on the new domain from `add-aws-hosting`. Later the same day he took every recommendation in design.md and asked for the site to be a single-page app.

> As someone deciding whether to pay for Antuna, I want to see what it does on my Apple TV and iPhone, which of my sources it takes, and what it costs, before I download it.

> As a household setter-upper, I want to read how setting up the Apple TV from my iPhone works, so I know I will not be typing passwords with the remote.

> As a user with a problem, I want a support page that answers the common questions and tells me how to reach the developer about the rest.

Today the site is a setup page, the Terms of Use, the Privacy Policy and the App Review playlist. Nothing on it says what Antuna does, the App Store support address points at the Terms, and the site's own rules forbid images and scripts, so it cannot show a screenshot.

After this change the site has a home page with the line "Your TV sources, on every Apple screen." and a section per feature area, one page for each of the nine areas, a pricing page, a support page with an FAQ, and the Terms and Privacy Policy, all in English, with Swedish next. It is a SvelteKit single-page app with every page prerendered to HTML: the first page arrives complete, readable without scripts, and later pages open without a reload. The setup page stays a plain file. The screenshots are the App Store set the screenshot workflow already takes, with made-up channels and titles only.

## What Changes

- A home page: the hero line "Your TV sources, on every Apple screen.", the four platforms, "no channels included", an App Store link, and one section per feature area with a screenshot and a link to its page.
- Nine feature pages, grouped the way a buyer thinks: sources, live TV, guide, movies and series, multi-view, Apple TV, setup from iPhone, sync and profiles, privacy. design.md maps every capability in `openspec/specs/` to one of them.
- A pricing page: free to download, a purchase needed to use it, lifetime or yearly, Family Sharing, the price shown in the App Store for the buyer's region. No prices written on the site.
- A support page: an FAQ and the support email address, antuna@code-crave.se. The App Store support address points here.
- The site becomes a SvelteKit app in `Web/site/` with `adapter-static`, built with Node 22 from a committed lockfile. Every route is prerendered to its own HTML file, and there is no catch-all page: an unknown address gets "Page not found" with a not-found status.
- The site may run its own bundled JavaScript and show its own images: screenshots from the store set, committed after review, and Apple's App Store badge. Still no third-party scripts, fonts, trackers or analytics, no cookies, and no request to another address. The Content-Security-Policy from `add-aws-hosting` enforces it, and a site check in CI fails on any inline script or outside address in the built pages.
- The setup page, the association file and the App Review files stay plain files outside the app. The setup page keeps its no-script rule, because it is where a setup link lands on an iPhone without Antuna.
- The Terms of Use and Privacy Policy keep their text, move into the app as prerendered pages, link to the support page for contact, and share the new header and footer.
- A `site` job in CI: install, lint, type-check, build, and the link and route check.
- English first, Swedish next, then each other language when its store listing is ready, under `/<lang>/`, with Arabic right to left.

Out of scope:
- Hosting, the domain, the CSP header and the deploy workflow (`add-aws-hosting`).
- A contact form on the site or in the app.
- A contact form, newsletter, blog, changelog page, press kit or search.
- Analytics of any kind, including server-side counts by page.
- A dark mode switch. The site follows the device's appearance.
- Languages other than English in this change's first PRs; Swedish and later languages each come in their own PR.
- Features from changes not yet archived, such as movie scores from `add-title-metadata`. They are added to the site when they ship.

## Capabilities

### New Capabilities
- `feature-website`: the home page, feature pages, pricing and support pages, what screenshots may show, pages that read without scripts and open without a reload, and how languages are added.

### Modified Capabilities
- `antuna-website`: every page reads on a phone and in dark mode, the site's own scripts and images are allowed, and nothing loads from another address.
- `store-listing`: the support address opens the support page, and the listing gives a marketing address.

## Impact

- Web: new `Web/site/` (SvelteKit app: `package.json`, `package-lock.json`, `.nvmrc`, `src/routes/`, `src/lib/`, `static/images/`, `scripts/`, `tests/`). `Web/terms/` and `Web/privacy/` move into its routes. `Web/setup/`, `Web/.well-known/` and `Web/review/` stay. `Web/404.html` from `add-aws-hosting` is replaced by the built one.
- Scripts: `scripts/publish-web.sh` takes the site build as a second argument; `scripts/site-screenshots.sh` picks and resizes store screenshots; `scripts/check-spec-refs.sh` also reads the site's tests.
- CI: a `site` job in `.github/workflows/ci.yml`. `add-aws-hosting`'s `infra.yml` builds the app before upload.
- Tests: `WebsiteTests` reads the legal pages from their routes and drops the tag check, which moves to the site check on the built pages. `SetupPageTests` is unchanged. `ReleaseTests` is unchanged by this change.
- Store: `fastlane/metadata/*/support_url.txt` move to `/support`; a `marketing_url.txt` per locale; `scripts/store_metadata.py` checks both.
- CLAUDE.md's `Web/` line ("No scripts, images or third-party content") changes to allow the site's own scripts and images, and the Commands list gains the site's build and check.
- Boards: new drafts `Web-Home`, `Web-Home-Phone`, `Web-Feature`, `Web-Pricing` and `Web-Support`. The single-page app changes nothing they draw.
- Depends on `add-aws-hosting` for the host, the domain and the CSP header, and through it on the owner registering `antuna.app` (its task 1.1). The app can be built and checked in CI before that, but it is not published and the store addresses do not move until the new domain serves.
