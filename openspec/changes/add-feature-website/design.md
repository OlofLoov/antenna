# Design

## Context

See proposal.md for why. What exists on 2026-11-22:

- `Web/` has four hand-written pages: `setup/` (one line and an App Store link, dark only, inline styles), `terms/` and `privacy/` (inline `<style>`, light and dark, `max-width: 40em`), and `review/antuna-review.m3u`. No home page: `/` answers 404 on GitHub Pages today.
- `WebsiteTests` fails on `<script`, `<iframe`, `<img`, `<link`, `<object`, `<embed`, `@import` and `url(` on every page. `SetupPageTests` checks the setup page's text, its one App Store link, and that its head holds only `meta` and `title`. The `antuna-website` spec and CLAUDE.md say "No scripts, images or third-party content".
- `scripts/publish-web.sh` copies `Web/` to a folder, fills the team id into the association file and writes the review guide. `WebsiteTests` and `ReleaseTests` run it in `swift test`, so it must keep working without Node.
- The App Store support address is `/terms` in all nine locales; there is no marketing address.
- The `App screenshots` workflow uploads `store-screenshots` every night: iPhone, iPad, Mac and Apple TV in each ready language, at App Store sizes, made from fixtures (`store-listing/store-screenshots-in-every-ready-language`). The artifact is kept 14 days.
- The store description in `fastlane/metadata/en-US/description.txt` already groups the features as sources, live TV, movies and series, Apple TV, every device, purchase and privacy.
- `add-aws-hosting` moves the site to CloudFront at `antuna.app`, with one fixed Content-Security-Policy header for the site and a stricter one for `/setup*`, and answers unknown addresses with `/404.html` and status 404. It also sets up `infra.yml`, whose site job builds and uploads the site.
- The owner took every recommendation in the first version of this design on 2026-11-22, except the page builder: he wants a single-page app. Decisions 1 to 8 record each choice; decision 2 is the single-page app.

## Boards

Drawn as drafts in this change, under `openspec/specs/design-system/boards/`, in the same hand-written `.dc.html` form as the app boards. They are the first web boards; the prefix is `Web-`.
- `Web-Home`: 1280 wide. Header, the hero with the line "Your TV sources, on every Apple screen.", the platforms, the App Store badge and one screenshot, then sections with alternating sides. Four of nine sections are drawn.
- `Web-Home-Phone`: 390 wide, one column. Hero text before the first screenshot. Five sections drawn.
- `Web-Feature`: one area page, multi-view: title, line, platforms, a large screenshot, features in two columns, links to all features and the next area.
- `Web-Pricing`: Yearly and Lifetime cards, Family Sharing, "What it costs" with no amount.
- `Web-Support`: the contact card with the email address, then the FAQ.

The single-page app changes nothing the boards draw: every page is the same HTML with or without scripts, and moving between pages looks the same as loading them. The boards' notes name the new image folder, `Web/site/static/images/`.

Not drawn yet:
- The light appearance of every page. It swaps ground and text the way the legal pages do.
- Feature pages, pricing and support at phone width.
- The Terms and Privacy pages with the new header and footer.
- The language switch, and any page right to left.
- `404.html`.
- "Coming soon to the App Store" in place of the badge.
- A home page section with two screenshots (iPhone and Apple TV side by side), if the screenshot set calls for it.

The store set has five screens per platform: live, guide, movies, player and adding a source. Multi-view has no picture in it, so its home section and page show text only until the App screenshots workflow takes a multi-view screen. Setup from iPhone and Privacy use the iPhone's add-source screen, whose note says the login stays in the iCloud Keychain; Sync and profiles uses the iPad channel list. The sizes the pages use are in `Web/site/src/lib/screenshots.en.json`, which `scripts/site-screenshots.sh` writes with the pictures.

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
| Privacy (`/features/privacy/`) | `source-management`, `paywall-and-entitlement`, `app-release` (privacy manifest), `antuna-website` (Privacy Policy) | No account, no ads, no analytics, passwords in iCloud Keychain only, data in the user's own iCloud, connects only to their sources, iCloud and the App Store. Links to the Privacy Policy. Updated when `add-title-metadata` ships, since it changes what leaves the device. |

On no feature page: `antuna-website`, `app-release`, `store-listing`, `design-system`, `localization` (the footer lists the app's languages instead), and `paywall-and-entitlement`, which is the pricing page.

Not on the site until their changes are archived (`feature-website/the-site-shows-only-what-the-app-does`): scores, trending and TMDB people from `add-title-metadata`.

## Goals / Non-Goals

**Goals:**
- A buyer can tell in one page whether Antuna fits their sources and devices, and in two clicks what it costs.
- Every shipped feature is on the site, and nothing that is not.
- Every address is real HTML a reader without scripts, a search engine, a link preview and App Review can read. Moving between pages after the first one happens in the page, without a reload.
- The site runs only its own code: no third-party script, font, tracker, analytics, cookie or request to another address.

**Non-Goals:**
- Search engine work beyond titles, descriptions and headings.
- A design that differs from the app's: the site uses the app's ground, text and accent colors.
- Anything that needs a server: forms, search, accounts.

## Decisions

### 1. One page per feature area (decided)

The owner chose one page per feature area, nine pages, on 2026-11-22.

Options considered:
- **One page per platform** (iPhone, iPad, Mac, Apple TV). Matches how Apple sells, but most features are on all four, so each page repeats the same list, and multi-view or setup from iPhone would be split across pages.
- **One page per feature area (chosen).** Nine pages in the order above, each saying which platforms have each feature. Apple TV is an area of its own because its remote-driven screens have no iPhone equivalent.
- **One long page.** Fewest files, but nine areas of screenshots make a heavy page on a phone, and nothing to link a store description or a support answer to.

Addresses: `/`, `/features/<area>/` for the nine areas, `/pricing/`, `/support/`, `/terms/`, `/privacy/`, and the static `/setup/` and `/review/`. `/features/` itself lists the nine areas.

### 2. A single-page app, prerendered: SvelteKit (decided)

The owner asked on 2026-11-22 for the site to be a single-page app, in place of the recommended Python page builder. Every route still has to be real HTML on first load, so links, search engines, App Review and readers without scripts get the content, and navigation after the first page stays in the browser.

Options considered:
- **SvelteKit with `adapter-static` and `prerender = true` on every route (chosen).** Svelte compiles components to plain DOM code, so the browser downloads no framework runtime beyond SvelteKit's router. A content page like these ships about 20 to 30 KB of compressed JavaScript in total. `adapter-static` writes one `index.html` per route at build time, and the client router takes over links after the first load. Optional route parameters and per-route `entries` cover `/sv/...` without a plugin.
- **React with Vite and React Router in prerender mode** (`ssr: false`, `prerender` listing every path). Prerenders well, and React is the most familiar stack. React and React DOM alone are about 45 KB compressed, the router adds about 20 KB, so about two and a half times the script for the same pages.
- **Vue with Vite** (with `vite-ssg` for prerendering, since Vite alone writes one empty `index.html`). Vue's runtime and Vue Router are about 45 to 50 KB compressed. `vite-ssg` writes no inline script when a page has no state, which suits the CSP, but it is a smaller project than either framework above, and the bundle is still about twice SvelteKit's.
- **The Python page builder from the first version of this design.** Smallest of all, with no script, but not a single-page app. Kept here as the option the owner declined.

The sizes are typical figures from each project's documentation and published comparisons as last read, not measured here; task 2.1 measures the real bundle and the site check holds it under the budget in decision 3.

Measured on 2026-11-23, SvelteKit 3.1.1 and Svelte 5.57.3, gzip level 6 over every script a page loads before it is interactive (its start file and each `modulepreload`): 35.7 KB on the home page and `/404.html`, 36.8 KB on the Terms of Use, 37.1 KB on the Privacy Policy. Two chunks, Svelte's runtime and SvelteKit's router, are 29.6 KB of that on every page; the rest is the layout and the page. With all sixteen pages and the English text of the feature, pricing and support pages, every page loads 43.5 to 45.0 KB: 44.7 KB on the home page, 44.6 KB on a feature page, 45.0 KB on the Privacy Policy. The text sits in one shared chunk, so later pages load almost nothing new. `node Web/site/scripts/check-site.js` prints the figure per page, and the site check fails a page over 60 KB.

What the build settles in SvelteKit 3:
- The configuration is passed to the `sveltekit()` plugin in `vite.config.ts`; SvelteKit 3 no longer reads `svelte.config.js`.
- `$lib` is gone. Components import from `#lib/...` through the `imports` field of `package.json`, with the `.ts` extension on TypeScript modules.
- `version.pollInterval` is 0, so the app never asks for `/_app/version.json` on a timer. A visitor on an old version gets a full page load when a moved script fails, as before.
- SvelteKit's router keeps scroll positions in `sessionStorage`, so the back button returns to the same place. The site's own code stores nothing; the site check fails on `localStorage`, `sessionStorage`, `indexedDB` or `document.cookie` in `src/`.
- The router's announcer, the hidden element that reads the new title to a screen reader after a navigation, carries its hiding in a `style` attribute that SvelteKit writes into its template. A plain `style-src 'self'` blocks that attribute, and the browser logs a violation on the first navigation. The site's CSP allows that one attribute value by its hash, in `style-src-attr 'unsafe-hashes' 'sha256-...'` (`add-aws-hosting` decision 3), and nothing else inline. `checkStyleHashes` in the site check hashes every `style="..."` in the built scripts and fails when one has no hash in the policy in `Infra/modules/site/main.tf`, or when the policy holds a hash no script writes, so a SvelteKit update that changes the announcer's style fails CI. Options considered: a `#svelte-announcer` rule in `site.css` that hides the element while the attribute stays blocked (it reads the same, but every visitor's console logs the violation); `kit.csp`, which hashes inline `<script>` and `<style>` elements but not attributes, and writes a meta policy the header would still have to loosen; rewriting the attribute out of the built chunk, which edits a hashed file after the fact and breaks on any change to the template.
- Plain links to other addresses, such as Apple's license agreement in the Terms of Use, are allowed for the hosts in `LINK_HOSTS` in the site check. Nothing on a page loads from them.

SvelteKit's prerendered pages start the app with an inline `<script>` that differs per page. The site's CSP (`add-aws-hosting` decision 3) is one fixed header with `script-src 'self'`, which blocks inline scripts. Options considered:
- **Allow `'unsafe-inline'` for scripts.** Throws away most of what the CSP is for. Ruled out.
- **SvelteKit's `kit.csp` in hash mode, which writes a `<meta>` policy with each page's hashes.** The header still has to allow inline scripts for the meta policy to matter, and a meta policy cannot set `frame-ancestors`.
- **Per-page hashes in the header, from a CloudFront KeyValueStore and a viewer-response function.** Strict, but every site upload then writes to infrastructure state too.
- **Move each page's start script into a file after the build (chosen).** `Web/site/scripts/externalize-start.js`, run by `npm run build` after `vite build`, cuts the inline start script out of each built HTML file, writes it unchanged to `/_app/start/<route>.<hash>.js`, and puts a plain `<script src>` in its place. The start script reads `document.currentScript`, which works the same for a classic external script, and with `kit.paths.relative = false` its imports are absolute, so they resolve the same from the file as from the page. The site check fails the build if any page keeps an inline script, so a SvelteKit update that changes the start script fails CI, not the live site.

Settings: `adapter-static` with `fallback` unset, so there is no catch-all `index.html`; `export const prerender = true` and `trailingSlash = 'always'` in the root layout, so `/pricing/` becomes `pricing/index.html`; `kit.prerender.handleHttpError = 'fail'` and `handleMissingId = 'fail'`, so a broken internal link or `#anchor` fails the build; `kit.paths.relative = false`; `kit.inlineStyleThreshold = 0`, so every style is a file. The `404` route sets `trailingSlash = 'never'` and is written as `/404.html`, which CloudFront answers for unknown addresses with status 404 (`add-aws-hosting` decision 3). A link to an unknown address inside the app shows the same page through `+error.svelte`.

What stays outside the app, as plain files in `Web/` that `scripts/publish-web.sh` copies next to the build:
- **`/setup/`.** It is the universal link landing page: an iPhone with Antuna opens the app for `/setup` addresses, and one without it shows this page (`iphone-as-setup-device/an-iphone-without-antuna-gets-a-plain-page`). That requirement says no scripts, images or third-party content, and `SetupPageTests` checks the file at `Web/setup/index.html`. It stays exactly as it is, with its own stricter CSP on `/setup*`. Links from the app to it carry `data-sveltekit-reload`, so the browser loads it as a page and the router never tries to draw it.
- **`/.well-known/apple-app-site-association`.** A JSON file Apple's CDN fetches; it is no page.
- **`/review/`.** The App Review playlist and the guide `publish-web.sh` writes. Data files, which the app never names.
- **Not the Terms of Use and the Privacy Policy.** They become routes in the app, prerendered like every other page, so the paywall's links, the App Store's privacy link and a reader without scripts get the full text in the first HTML. Keeping them outside would mean a second copy of the header, footer and stylesheet. Their text is English HTML in their `+page.svelte` files, with no strings file, since they stay English only (decision 8).

Repository layout:
- `Web/site/`: `package.json`, `package-lock.json` (committed; CI installs with `npm ci`), `.nvmrc` with `22`, `"engines": { "node": ">=22 <23" }`, `svelte.config.js`, `vite.config.ts`, `tsconfig.json`, `eslint.config.js`, `.prettierrc`. `src/routes/` holds the pages, `src/lib/` the components and `strings/en.json`, `static/images/` the screenshots and Apple's badge, `scripts/` the start-script step and the site check, `tests/` the Vitest checks. Node 22 matches `Infra/` in `add-aws-hosting`.
- `Web/site/build/` and `Web/site/node_modules/` are git-ignored.
- `Web/setup/`, `Web/.well-known/` and `Web/review/` stay where they are. `Web/terms/` and `Web/privacy/` move into `Web/site/src/routes/`. `Web/404.html` from `add-aws-hosting` is removed once the build writes `/404.html`.
- `scripts/publish-web.sh <out> [<site build>]` copies the static files, fills the team id and writes the review guide as today, then copies the site build in when given one, and fails when a static file and a built route have the same path. `swift test` calls it without the build, so the Swift jobs need no Node.

CI: a `site` job in `.github/workflows/ci.yml` on every pull request and push to main, on ubuntu-latest with `actions/setup-node` reading `Web/site/.nvmrc` and the npm cache keyed on the lockfile. It runs `npm ci`, `npm run lint` (ESLint with `eslint-plugin-svelte` and Prettier's check), `npm run check` (`svelte-check` for types), `npm run build`, and `npm test`. `npm test` runs Vitest over `Web/site/build/` and `scripts/check-site.js`, the link and route check:
- every route in `src/routes/` has an HTML file in the build, and every HTML file holds its page's `<h1>` and text in the markup, not only after a script runs;
- every internal `href` and `src` resolves to a built file or a static file, links to `/setup/` carry `data-sveltekit-reload`, and every `#anchor` exists;
- no HTML file has an inline `<script>`, an `on*=` attribute or a `style=` attribute, every `<script src>`, `<link href>` and `<img src>` is a path on the site, and no file names `http://` or `https://` except the App Store link and `hreflang` links on the site's own domain;
- the budgets from decision 3, and the provider names and email checks from decisions 4 and 6.

The design decisions that keep the build inside the CSP: no `style=` attributes and no `style:` directives (they write style attributes into the HTML), no Svelte transitions or animations (they add `<style>` elements at run time; CSS transitions on classes instead), no `{@html}` with anything but the site's own strings, and no `fetch` to anything but the site.

Test changes in AntennaCore:
- `SetupPageTests`: unchanged. The setup page does not move and still has no script.
- `WebsiteTests`: keeps the association file, team id and publish checks, and the legal text checks, reading `Web/site/src/routes/terms/+page.svelte` and `privacy/+page.svelte` in place of the old `index.html` files. `everyAddress` checks for the route files and the static files. The tag check in `the-pages-read-on-a-phone-and-in-dark-mode` moves to the site check, which reads the built HTML; the Swift test keeps only the viewport and both-appearances checks, on the layout and stylesheet sources.
- `ReleaseTests`: unchanged by this change. `add-aws-hosting` already moves its `pages.yml` checks to `infra.yml`, and its review files do not move.
- `scripts/check-spec-refs.sh` also reads citations in `Web/site/tests/` and `Web/site/scripts/`, so a site test that cites a missing requirement fails as a Swift one does.

### 3. Images: committed store screenshots (decided)

The owner chose committed screenshots, picked by a script and reviewed in a PR, on 2026-11-22.

The site needs screenshots, and the `antuna-website` rule forbids images and scripts. The rule is amended to allow images and scripts the site publishes itself, and to keep forbidding third-party scripts, fonts, trackers, analytics and anything from another address (`antuna-website/the-pages-read-on-a-phone-and-in-dark-mode`). `add-aws-hosting`'s CSP enforces `script-src 'self'` and `img-src 'self'`.

How screenshots get in. Options considered:
- **Download the latest `store-screenshots` artifact at publish time.** Always current, but the published images are never reviewed, a publish fails when no artifact is younger than 14 days, and two publishes of the same commit can show different pictures.
- **A separate website screenshot set in the UI test run.** Pictures framed for the site, but a second set of walk-throughs to keep working.
- **A script that picks from the store set, and a PR that commits them (chosen).** `scripts/site-screenshots.sh` downloads the newest `store-screenshots` artifact with `gh run download`, takes the files listed in `Web/site/static/images/screenshots.txt` (one line per picture: platform, store file name, site name), resizes them with `sips` to 1200 pixels wide and to 600 for phones, writes JPEG at quality 80 to `Web/site/static/images/<lang>/`, and fails when a listed file is missing. The owner or an agent runs it and opens a PR; the reviewer sees each picture in the diff.

Budget, checked by the site check on the build: each image at most 250 KB, every `<img>` has `width`, `height`, `alt` and `loading="lazy"` (except the hero's first), the JavaScript a page loads before it is interactive at most 60 KB compressed, and the home page's HTML, stylesheet, scripts and first image under 500 KB together.

Apple's "Download on the App Store" badge is the one image not from the store set. It is Apple's artwork, used as Apple's marketing guidelines allow, downloaded once and committed as SVG; the site never loads it from Apple. Until the App Store page exists, the badge is replaced by the text "Coming soon to the App Store".

### 4. What screenshots may show (App Review 5.2.3)

The store set is already made from fixtures: made-up channel names, programmes, posters and backdrops, no real title, person, logo or brand (`store-listing/store-screenshots-in-every-ready-language`). The site uses only that set, so it inherits the rule. The site check runs the listing check's provider list (`NAMES` in `scripts/store_metadata.py`, read as a file) over every built page's text, and fails on a hit (`feature-website/nothing-on-the-site-points-to-a-provider`). Alt text describes the screen ("The guide grid on Apple TV with six made-up channels"), never a channel.

### 5. Pricing without amounts (decided)

The owner chose no amounts on the site on 2026-11-22.

The paywall shows the App Store's price for the user's region exactly as given (`paywall-and-entitlement/prices-come-from-the-app-store`). The site cannot ask the App Store.

Options considered:
- **No amounts (chosen).** The page names the two purchases and says the App Store shows the regional price. Always correct.
- **US prices with "prices vary by region".** A buyer gets a number, but it goes stale at every price change and is wrong for most visitors.
- **A table of prices per region.** Correct only on the day it is written.

The App Store badge on the pricing page leads to the product page, which shows the price.

### 6. Support by email (decided)

Dropped 2026-11-23: the in-app report form (`add-support-requests`) and the no-email rule that came with it. Support is email to antuna@code-crave.se.

Options considered: the in-app form, which needed a server, a GitHub App and device attestation for little gain; a web form on the site, which needs a server and a spam filter; plain email (chosen).

The support page has:
- A contact card: antuna@code-crave.se as a mailto link, a line on what to include (device, Antuna version, what happened), and a warning never to send a password, MAC address or playlist link. It is the only page with an email address; the site check fails on any other.
- An FAQ, each question an `<h2>` with an id so a store reply or a form can link to it: does Antuna include channels, which sources work, a channel will not play (what each error message means, from `player-controls-and-playback-errors`), the guide is empty or wrong, a source will not load, setting up an Apple TV from an iPhone, unlocking on a new device and Restore Purchases, Family Sharing, canceling the yearly subscription, refunds (from Apple), deleting your data.

The Terms of Use and Privacy Policy say "how to reach the publisher" by linking to the support page, replacing `support@code-crave.se`. The Privacy Policy adds that emails sent to Code Crave are kept in the mailbox to answer the sender. App Store Connect's support URL becomes `/support/` (`store-listing/the-listing-links-to-the-site-s-pages`); App Review's guideline 1.5 asks that it gives "an easy way to contact you", which the email address does.

### 7. Page structure and ids

Every page: `<html lang="en">`, a `<title>` of "<Page> · Antuna", a `<meta name="description">`, `<meta name="referrer" content="no-referrer">`, the viewport meta, `<header id="site-header">` and `<footer id="site-footer">`, and one `<h1>`. The header and footer live in the root `+layout.svelte`, so they stay on screen while the page below changes. After a client-side navigation the router moves focus to the new page's `<h1>` and updates the title, so a screen reader announces the new page (SvelteKit does both by default; the site check confirms each page has one `<h1>`). Home sections are `<section id="<area>">`; FAQ questions are `<h2 id="<question-slug>">`. No cookie, no form, no `<iframe>`, no `localStorage`.

Dark mode follows `prefers-color-scheme` in the stylesheet only, as the legal pages do today. There is no toggle, so no script decides the colors and a page never flashes the wrong appearance before a script runs.

The home page's hero line is "Your TV sources, on every Apple screen.", which the owner chose on 2026-11-22 from the boards. The rest of the copy follows the store description.

The setup page stays as it is, with no header, footer or stylesheet (`iphone-as-setup-device/an-iphone-without-antuna-gets-a-plain-page`).

### 8. Languages (decided)

The owner chose English first, then Swedish, on 2026-11-22.

Options considered:
- **All seven languages at once.** Matches the app, but seven times the text to review before anything ships, and Arabic is still held in the store listing.
- **English first, Swedish next, then each other language when its store listing is ready (chosen).** The owner can review Swedish himself. A language's site uses that language's store screenshots and follows the same review the store listing gets (`store-listing/a-language-s-listing-waits-for-its-review`). Arabic comes when its listing is no longer held.

Routing: English stays at the root. Each other language lives under `/<lang>/` (`/sv/`, then `/de/`, `/es/`, `/fr/`, `/pt-br/`, `/ar/`) through an optional route parameter, `src/routes/[[lang=lang]]/`, whose matcher accepts only published languages, so `/de/` answers 404 until German ships. The root layout's `entries` lists every published language for each route, so each is prerendered. Text comes from `src/lib/strings/<lang>.json`; a missing key fails the build. The Terms of Use and Privacy Policy stay English only, at the root, until a lawyer-checked translation exists, and each language's footer links to them there.

`<html lang>` and `dir` are written into each page at prerender time by `hooks.server.ts` (`transformPageChunk` replacing `%lang%` and `%dir%` in `app.html`). Each page carries `<link rel="alternate" hreflang>` to its other versions. The language switch is a plain list of links in the footer, so it works without scripts; those links carry `data-sveltekit-reload`, so a language change is a full page load and the new `lang` and `dir` come from the prerendered HTML rather than a script rewriting the root element.

No redirect by browser language: CloudFront would need the `Accept-Language` header in the cache key, and a visitor landing on a language they did not pick is worse than one click.

Arabic, later: `dir="rtl"` from the hook, a stylesheet in CSS logical properties throughout (`margin-inline-start`, `padding-inline`, `inset-inline-end`) so no second stylesheet is needed, the boards' right-to-left versions drawn first, and screenshots from the Arabic store set, which is already right to left.

## Risks / Trade-offs

- The start-script step depends on how SvelteKit writes its start script. An update that changes it fails the site check in CI, and the fix is in one small file; the lockfile keeps SvelteKit from changing under a build without a PR.
- A Node toolchain and a dependency tree join a repo that had only Swift and Python. The lockfile, `npm ci` and the site job keep it pinned and checked, dependency updates come in their own PRs, and the Swift jobs never need it.
- A visitor with the previous version open who moves to another page loads a script that may no longer exist. `add-aws-hosting` keeps old hashed files in the bucket, and SvelteKit falls back to a full page load when a route's script fails to load.
- A screenshot can go stale when a screen changes. The App screenshots workflow runs nightly; the site's pictures change only when someone runs the script. The PR that changes a screen's board names the site picture if one shows it.
- An email address on a public page draws spam. The mailbox's own filter handles it; the address is on one page only.
- Apple's badge guidelines change from time to time; the committed SVG must be the current one at each submission.
- Describing features in English and Swedish while the app ships seven languages leaves other buyers with the store listing only, until their language's site is added.
- A feature page can drift from the app as specs change. The inventory table above is the check: archiving a change that touches a listed capability updates its page (`feature-website/the-site-shows-only-what-the-app-does`).

## Migration Plan

Additive for visitors. The existing addresses keep their paths: `/setup/`, `/.well-known/`, `/review/` as files, `/terms/` and `/privacy/` as prerendered routes with the same text. The store support addresses move from `/terms` to `/support/` in the same PR that publishes the support page. The CSP moves from the no-script policy to the site policy in the PR that first publishes the app (task 2.4).

## Open Questions

None in this change. The owner decided every question on 2026-11-22: pages per feature area, committed screenshots, no prices, English then Swedish, a single-page app, and the hero line. The owner picked `antuna.app` on 2026-11-23; registering it is `add-aws-hosting` task 1.1.
