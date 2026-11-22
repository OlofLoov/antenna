# Design

## Context

See proposal.md for why. What exists on 2026-11-22:

- `Web/` has four hand-written pages: `setup/` (one line and an App Store link, dark only, inline styles), `terms/` and `privacy/` (inline `<style>`, light and dark, `max-width: 40em`), and `review/antenna-review.m3u`. No home page: `/` answers 404 on GitHub Pages today.
- `WebsiteTests` fails on `<script`, `<iframe`, `<img`, `<link`, `<object`, `<embed`, `@import` and `url(` on every page. The `antenna-website` spec and CLAUDE.md say "No scripts, images or third-party content".
- The App Store support address is `/terms` in all nine locales; there is no marketing address.
- The `App screenshots` workflow uploads `store-screenshots` every night: iPhone, iPad, Mac and Apple TV in each ready language, at App Store sizes, made from fixtures (`store-listing/store-screenshots-in-every-ready-language`). The artifact is kept 14 days.
- The store description in `fastlane/metadata/en-US/description.txt` already groups the features as sources, live TV, movies and series, Apple TV, every device, purchase and privacy.
- `add-aws-hosting` moves the site to CloudFront at `<antenna-domain>` with a Content-Security-Policy of `default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self'`, which this change relies on.
- `add-support-requests` adds Report a problem in Settings and on the player's error screen. Not built.

## Boards

Drawn as drafts in this change, under `openspec/specs/design-system/boards/`, in the same hand-written `.dc.html` form as the app boards. They are the first web boards; the prefix is `Web-`.
- `Web-Home`: 1280 wide. Header, the hero with the line, the platforms, the App Store badge and one screenshot, then sections with alternating sides. Four of nine sections are drawn.
- `Web-Home-Phone`: 390 wide, one column. Hero text before the first screenshot. Five sections drawn.
- `Web-Feature`: one area page, multi-view: title, line, platforms, a large screenshot, features in two columns, links to all features and the next area.
- `Web-Pricing`: Yearly and Lifetime cards, Family Sharing, "What it costs" with no amount.
- `Web-Support`: the Report a problem section, then the FAQ.

Not drawn yet:
- The light appearance of every page. It swaps ground and text the way the legal pages do.
- Feature pages, pricing and support at phone width.
- The Terms and Privacy pages with the new header and footer.
- The language switch, and any page right to left.
- `404.html`.
- "Coming soon to the App Store" in place of the badge.
- A home page section with two screenshots (iPhone and Apple TV side by side), if the screenshot set calls for it.

Design-system requirements that apply: "Text meets contrast minimums", "One accent color per profile" (the site uses the default accent, `#5BB8FF`), "One spacing and radius scale", "Nothing fake and nothing bundled" (the screenshots show fixture content only, and copy names platforms, never the visitor's device), "Copy fits in every language", "Layouts mirror in right-to-left languages" (for when Arabic is added). The app-only rules (focus, tab bar, safe area, Liquid Glass, accessibility identifiers) do not apply to the site; its "identifiers" are the HTML ids in decision 7.

## Feature inventory

Every capability in `openspec/specs/` on 2026-11-22, by area. A capability can feed two areas.

| Area (page) | Capabilities | What the page says |
|-------------|--------------|--------------------|
| Sources (`/features/sources/`) | `m3u-playlists`, `local-m3u-file-import`, `xtream-live-source`, `xtream-vod-client`, `stalker-portal-source`, `jellyfin-live-tv-source`, `channels-dvr-source`, `xmltv-guide-parsing`, `sources-and-settings`, `first-run-onboarding` | M3U by link or file (file import on iPhone, iPad and Mac, then every device), Xtream Codes, Stalker and Ministra with the MAC address, Jellyfin Live TV, Channels DVR by address, XMLTV guides. Large playlists load without stalling. Fix a link or login, reorder, refresh. From install to a playing channel in a few steps. |
| Live TV (`/features/live-tv/`) | `live-tv-on-iphone-ipad-mac`, `channel-catalogue`, `favorites`, `group-management`, `adult-content`, `new-channels`, `session-restore-and-recently-watched`, `timeshift-catch-up-and-start-over`, `player-controls-and-playback-errors`, `playback-engine`, `search`, `programme-reminders`, `app-intents`, `keyboard-commands` | Now and next in the list, play in place while browsing, favorites, hide, rename, reorder and build groups, a passcode for adult groups, a New group, Recents, pause and rewind an hour, start over and catch-up, audio language, errors in plain words, HDR10, Dolby Vision and Atmos on Apple TV, one search, reminders, Siri and Shortcuts, keyboard shortcuts on Mac and iPad. |
| Guide (`/features/guide/`) | `guide-data`, `guide-on-iphone-ipad-and-mac`, `tv-guide-grid`, `guide-sources-and-channel-mapping`, `programme-reminders` | The coming days in a grid or per channel, the playing channel kept in a corner on Apple TV, choosing guides per playlist and matching a channel by hand, a reminder before a programme. |
| Movies and series (`/features/movies-and-series/`) | `movies-and-series-browsing`, `title-detail-and-episode-picker`, `up-next`, `browse-by-person`, `watch-progress-sync` | Rows of posters, a banner of new titles, genres, My list, a title page with seasons and episodes and what you watched, the next episode with a countdown, everything with an actor or director, resume on any device. |
| Multi-view (`/features/multi-view/`) | `multi-view` | Up to four channels, sound from the highlighted one, change, enlarge, retry or remove a tile. Apple TV, iPad and Mac. |
| Apple TV (`/features/apple-tv/`) | `tvos-shell`, `tv-channel-overlay`, `tv-zap-bar-and-number-entry`, `control-hints`, `top-shelf`, `tv-guide-grid` | Opens on the last channel full screen, the channel list over the picture, up and down to change channel, numbers from a keyboard, hints for what the remote does, favorites and titles in progress on the Top Shelf. |
| Setup from iPhone (`/features/setup-from-iphone/`) | `iphone-as-setup-device`, `apple-tv-login-from-iphone` | Scan the TV's code or accept Handoff, fill in the source on the phone, sign a TV in without typing the password with the remote; the login travels sealed and only that TV can read it. |
| Sync and profiles (`/features/sync-and-profiles/`) | `source-management`, `watch-progress-sync`, `favorites`, `profiles`, `group-management` | Add a source once and it reaches every device on the Apple Account through iCloud, progress and My list follow you, a profile per person with their own favorites and history. |
| Privacy (`/features/privacy/`) | `source-management`, `paywall-and-entitlement`, `app-release` (privacy manifest), `antenna-website` (Privacy Policy) | No account, no ads, no analytics, passwords in iCloud Keychain only, data in the user's own iCloud, connects only to their sources, iCloud and the App Store. Links to the Privacy Policy. Updated when `add-support-requests` and `add-title-metadata` ship, since both change what leaves the device. |

On no feature page: `antenna-website`, `app-release`, `store-listing`, `design-system`, `localization` (the footer lists the app's languages instead), and `paywall-and-entitlement`, which is the pricing page.

Not on the site until their changes are archived (`feature-website/the-site-shows-only-what-the-app-does`): scores, trending and TMDB people from `add-title-metadata`, Report a problem from `add-support-requests`.

## Goals / Non-Goals

**Goals:**
- A buyer can tell in one page whether Antenna fits their sources and devices, and in two clicks what it costs.
- Every shipped feature is on the site, and nothing that is not.
- The site stays static: no script, no third-party request, no cookie.

**Non-Goals:**
- Search engine work beyond titles, descriptions and headings.
- A design that differs from the app's: the site uses the app's ground, text and accent colors.

## Decisions

### 1. One page per feature area

Options considered:
- **One page per platform** (iPhone, iPad, Mac, Apple TV). Matches how Apple sells, but most features are on all four, so each page repeats the same list, and multi-view or setup from iPhone would be split across pages.
- **One page per feature area (chosen).** Nine pages in the order above, each saying which platforms have each feature. Apple TV is an area of its own because its remote-driven screens have no iPhone equivalent.
- **One long page.** Fewest files, but nine areas of screenshots make a heavy page on a phone, and nothing to link a store description or a support answer to.

Addresses: `/`, `/features/<area>/` for the nine areas, `/pricing/`, `/support/`, and the existing `/setup/`, `/terms/`, `/privacy/`, `/review/`. `/features/` itself lists the nine areas.

### 2. A small page builder

Options considered:
- **Hand-written HTML, as today.** No tooling, but the header, footer and stylesheet copied into fifteen pages, and once languages arrive, seven times over.
- **A static site generator (Hugo, Eleventy, Astro).** Templates and i18n built in, but a new toolchain and dependency tree for fifteen pages.
- **`scripts/build-site.py`, Python stdlib only (chosen).** `scripts/publish-web.sh` already runs Python 3. Pages are HTML bodies under `Web/pages/<path>.html` with a small front matter (title, description); the builder wraps each in `Web/layout.html` and writes `<out>/<path>/index.html`. Text comes from `Web/strings/en.json` so a later language is another JSON file. `Web/setup/index.html`, `Web/.well-known/` and `Web/review/` are copied as they are.

One stylesheet, `Web/site.css`, linked from every page but the setup page. It uses CSS logical properties (`margin-inline-start`, `padding-inline`) throughout so Arabic needs `dir="rtl"` and no second stylesheet. System font stack only.

### 3. Images: committed store screenshots

The site needs screenshots, and the `antenna-website` rule forbids images. The rule is amended to allow images the site publishes itself, and to keep forbidding scripts, fonts, trackers and anything from another address (`antenna-website/the-pages-read-on-a-phone-and-in-dark-mode`). `add-aws-hosting`'s CSP enforces `img-src 'self'`.

How screenshots get in. Options considered:
- **Download the latest `store-screenshots` artifact at publish time.** Always current, but the published images are never reviewed, a publish fails when no artifact is younger than 14 days, and two publishes of the same commit can show different pictures.
- **A separate website screenshot set in the UI test run.** Pictures framed for the site, but a second set of walk-throughs to keep working.
- **A script that picks from the store set, and a PR that commits them (chosen).** `scripts/site-screenshots.sh` downloads the newest `store-screenshots` artifact with `gh run download`, takes the files listed in `Web/images/screenshots.txt` (one line per picture: platform, store file name, site name), resizes them with `sips` to 1200 pixels wide and to 600 for phones, writes JPEG at quality 80 to `Web/images/<lang>/`, and fails when a listed file is missing. The owner or an agent runs it and opens a PR; the reviewer sees each picture in the diff.

Budget, checked by `WebsiteTests`: each image at most 250 KB, every `<img>` has `width`, `height`, `alt` and `loading="lazy"` (except the hero's first), and the home page's HTML, stylesheet and first image under 500 KB together.

Apple's "Download on the App Store" badge is the one image not from the store set. It is Apple's artwork, used as Apple's marketing guidelines allow, downloaded once and committed as SVG; the site never loads it from Apple. Until the App Store page exists, the badge is replaced by the text "Coming soon to the App Store".

### 4. What screenshots may show (App Review 5.2.3)

The store set is already made from fixtures: made-up channel names, programmes, posters and backdrops, no real title, person, logo or brand (`store-listing/store-screenshots-in-every-ready-language`). The site uses only that set, so it inherits the rule. `WebsiteTests` runs the listing check's provider list (`NAMES` in `scripts/store_metadata.py`) over every page's text, and fails on a hit (`feature-website/nothing-on-the-site-points-to-a-provider`). Alt text describes the screen ("The guide grid on Apple TV with six made-up channels"), never a channel.

### 5. Pricing without amounts

The paywall shows the App Store's price for the user's region exactly as given (`paywall-and-entitlement/prices-come-from-the-app-store`). The site cannot ask the App Store.

Options considered:
- **No amounts (recommended).** The page names the two purchases and says the App Store shows the regional price. Always correct.
- **US prices with "prices vary by region".** A buyer gets a number, but it goes stale at every price change and is wrong for most visitors.
- **A table of prices per region.** Correct only on the day it is written.

The App Store badge on the pricing page leads to the product page, which shows the price.

### 6. Support with no email

The owner wants no email (2026-11-22). The support page has:
- "Report a problem from the app": Settings, Report a problem; on a failed stream, Report this problem; what is sent is shown first; a reference code comes back. Shipped with `add-support-requests`.
- An FAQ, each question an `<h2>` with an id so a store reply or a form can link to it: does Antenna include channels, which sources work, a channel will not play (what each error message means, from `player-controls-and-playback-errors`), the guide is empty or wrong, a source will not load, setting up an Apple TV from an iPhone, unlocking on a new device and Restore Purchases, Family Sharing, canceling the yearly subscription, refunds (from Apple), deleting your data.

The Terms of Use and Privacy Policy say "how to reach the publisher" by linking to the support page, replacing `support@code-crave.se`. App Store Connect's support URL becomes `/support/` (`store-listing/the-listing-links-to-the-site-s-pages`); App Review's guideline 1.5 asks that it gives "an easy way to contact you", which the Report a problem section does once that form ships (open question 4).

### 7. Page structure and ids

Every page: `<html lang="en">`, a `<title>` of "<Page> · Antenna", a `<meta name="description">`, `<meta name="referrer" content="no-referrer">`, the viewport meta the tests check, `<header id="site-header">` and `<footer id="site-footer">`, and one `<h1>`. Home sections are `<section id="<area>">`; FAQ questions are `<h2 id="<question-slug>">`. No cookie, no form, no `<iframe>`. Light and dark through `prefers-color-scheme`, as the legal pages do.

The setup page stays as it is, with no header, footer or stylesheet (`iphone-as-setup-device/an-iphone-without-antenna-gets-a-plain-page`).

### 8. Languages

Options considered:
- **All seven languages at once.** Matches the app, but seven times the text to review before anything ships, and Arabic is still held in the store listing.
- **English first, each other language when its store listing is ready (recommended).** A language's site uses that language's store screenshots and follows the same review the store listing gets (`store-listing/a-language-s-listing-waits-for-its-review`).

When a language is added: pages under `/<lang>/` (`/sv/`, `/de/`, `/es/`, `/fr/`, `/pt-br/`, `/ar/`), `<html lang>`, `<link rel="alternate" hreflang>` between versions, and a plain link list in the footer as the language switch, since there is no script. English stays at the root. No redirect by browser language: CloudFront would need the `Accept-Language` header in the cache key, and a visitor landing on a language they did not pick is worse than one click. Arabic gets `dir="rtl"` and the logical-property stylesheet from decision 2; screenshots come from the Arabic store set, which is already right to left. The Terms and Privacy Policy stay English only until a lawyer-checked translation exists.

## Risks / Trade-offs

- A screenshot can go stale when a screen changes. The App screenshots workflow runs nightly; the site's pictures change only when someone runs the script. The PR that changes a screen's board names the site picture if one shows it.
- Guideline 1.5 and no email: until `add-support-requests` ships, the support page offers no way to contact Code Crave. Apple may reject a submission on that. See open question 4.
- Apple's badge guidelines change from time to time; the committed SVG must be the current one at each submission.
- Describing features in English while the app ships seven languages leaves non-English buyers with the store listing only, until their language's site is added.
- A feature page can drift from the app as specs change. The inventory table above is the check: archiving a change that touches a listed capability updates its page (`feature-website/the-site-shows-only-what-the-app-does`).

## Migration Plan

Additive. The existing addresses keep their paths. The store support addresses move from `/terms` to `/support/` in the same PR that publishes the support page.

## Open Questions

Open questions for the owner, each with a recommendation:

1. **Pages per feature area or per platform?** Recommend per feature area, nine pages (decision 1).
2. **Screenshots committed or pulled at publish?** Recommend committed through `scripts/site-screenshots.sh` and a reviewed PR (decision 3).
3. **Prices on the site?** Recommend none; the pricing page says the App Store shows the regional price (decision 5).
4. **The support page before Report a problem ships.** Recommend shipping `add-support-requests` before the first App Store submission, so guideline 1.5 is met by the form. If the site goes live first, the support page carries the FAQ and says the in-app form is coming; no email address either way.
5. **Languages.** Recommend English first, Swedish next (the owner can review it), then each language as its store listing passes review, Arabic right to left when its listing is no longer held (decision 8).
6. **A page builder?** Recommend `scripts/build-site.py` with the stdlib only, over a site generator (decision 2).
7. **The hero line.** The boards use "Your TV sources, on every Apple screen." Recommend the owner picks or rewrites it; the rest of the copy follows the store description.
