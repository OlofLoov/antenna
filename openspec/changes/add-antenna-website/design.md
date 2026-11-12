# Design

## Context

`Web/setup/index.html` exists from change `add-iphone-as-setup-device`, with `SetupPageTests` holding it to one line of text and one App Store link. Nothing publishes it. `SetupLink.host`, `Config/Antenna.entitlements` (`applinks:`), `project.yml` and both Info.plists (`AntennaTermsURL`, `AntennaPrivacyURL`) all point at `antenna.code-crave.se`. The association file's format is settled in `add-iphone-as-setup-device/design.md`, "Universal link files".

The legal pages describe the app as built. What the code shows:

- SwiftData records synced through the private CloudKit database `iCloud.se.codecrave.antenna`: sources, imported playlist text, favorites, profiles, preferences, reminders, groups, hidden groups, the group passcode's salted check value, watch progress, My List entries and recent searches.
- Logins in the synchronizable Keychain under `se.codecrave.antenna.sources`. The one exception is the sealed login drop from change `add-apple-tv-login-from-iphone`: HPKE-sealed to a key held only in the Apple TV's memory, kept in the `LoginDrops` zone of the private database in `encryptedValues` for at most ten minutes.
- Per-device state in `UserDefaults`, posters cached on disk up to 500 MB, reminders as local notifications.
- No third-party SDK in the app targets. The only remote package is SnapshotPreviews, linked only into the unit-test bundle. A grep for analytics, crash reporting and ad SDKs finds nothing. `Logger` calls write to the device's own log.
- Network requests go to the user's sources, to addresses those sources list (channel logos, posters, guide files), and to Apple (iCloud, App Store, notifications). A trailer opens a YouTube address the source lists, in the browser, when the user taps Trailer. The FFmpeg notice links to GitHub and gnu.org.
- Products `se.codecrave.antenna.yearly` (auto-renewing, one year) and `se.codecrave.antenna.lifetime` (non-consumable), both family shareable.

## Goals / Non-Goals

**Goals:**
- Every address the app uses answers, published from the repo with no server of our own.
- The legal text is checked by tests for the sections App Review looks for, so an edit cannot drop one unnoticed.

**Non-Goals:**
- A page builder, templates or a shared stylesheet. Three pages do not need one.
- Custom response headers. GitHub Pages cannot set them.

## Decisions

### Hosting: GitHub Pages from `Web/`

`.github/workflows/pages.yml` runs on pushes to main that touch `Web/**`, `scripts/publish-web.sh` or the workflow itself, and on manual dispatch. It runs the publish script into a temporary folder, uploads that with `actions/upload-pages-artifact` and deploys with `actions/deploy-pages`. `Web/CNAME` holds `antenna.code-crave.se`. `Web/.nojekyll` stops Jekyll, which would drop `.well-known` for starting with a dot.

Considered: Cloudflare Pages or Netlify, which can set `Content-Type` through a `_headers` file. Both add an account and a dependency outside GitHub. GitHub Pages is free with the repo and enough unless Apple refuses the association file (see Risks).

### Team id: filled at publish time

The committed `Web/.well-known/apple-app-site-association` holds `TEAMID_PLACEHOLDER.se.codecrave.antenna`. `scripts/publish-web.sh <out>` copies `Web/` to `<out>` and, while the file holds the placeholder, replaces it with `$APPLE_TEAM_ID`. It exits non-zero when the variable is empty or not `^[A-Z0-9]{10}$`, and checks the result parses as JSON. The workflow passes the repository variable `vars.APPLE_TEAM_ID`. Once the owner commits the real id, the script copies the file unchanged and the variable is not needed.

Considered: a test that fails while the placeholder is committed. It would fail every PR until the owner acts, and the setup page and legal pages need to ship before then. Failing the publish keeps CI green and still stops the placeholder from reaching the site.

`WebsiteTests` runs the script through `Process` with no team id, a malformed one and a valid one.

### Pages: one HTML file per address, CSS in the page

`Web/terms/index.html` and `Web/privacy/index.html`, next to `Web/setup/index.html`. Each has its CSS in one `<style>` element in `<head>`, so a page is one request and loads nothing else. Colors follow the setup page: background `#0B0F14`, text `#F5F7FA`, links `#5BB8FF`, system font at 17 px. A `prefers-color-scheme: light` block swaps to a white background with dark text and a darker blue link. Text runs in a column of at most 40 em with 24 px side padding.

No board in `openspec/specs/design-system/boards/` covers these pages. They are web pages outside the app, so the design-system requirements for app screens do not apply; they borrow the setup page's colors instead.

The setup page keeps its inline styles and dark look. Its tests forbid anything but `<meta>` and `<title>` in its `<head>`, and this change leaves it alone.

GitHub Pages answers `/terms` with a redirect to `/terms/`. The paywall link still lands on the page. The association file is a plain file and is served with no redirect.

### Wording

Publisher: Code Crave. Contact: `support@code-crave.se`, a placeholder the owner confirms. Last updated: November 12, 2026. The terms say they add to Apple's Licensed Application End User License Agreement and link to it. Neither page names a governing law or a company registration number, since neither is known.

### Tests

`Packages/AntennaCore/Tests/AntennaCoreTests/WebsiteTests.swift`, next to `SetupPageTests`, reads `Web/` from the repository root the same way. It checks the files exist, `CNAME` matches the host in `Apps/Mobile/Info.plist`'s legal links, the association file's JSON shape, each legal page's `<h2>` headings and phrases, the "Last updated" line, the cross links, the viewport tag, the light-scheme block and the absence of `<script`, `<img`, `<iframe`, `<link` and `@import`. Each test cites `antenna-website/<requirement-slug>`.

"The site publishes from main" is checked by reading the workflow's trigger in the same test file.

## Risks / Trade-offs

- [GitHub Pages serves a file with no extension as `application/octet-stream`, not `application/json`] → Apple's documentation asks for JSON, and whether its CDN accepts this file as served is not verified. After the first deploy the owner runs `curl -sI https://antenna.code-crave.se/.well-known/apple-app-site-association` and checks the app opens a setup link. If Apple refuses the file, move hosting to Cloudflare Pages with a `_headers` file; `Web/` and the script carry over unchanged.
- [The legal text is not reviewed by a lawyer] → the owner has it reviewed before submission.
- [The terms describe the app as built today] → a change that adds a server, an SDK or a new kind of synced data updates the Privacy Policy in the same PR.

## Migration Plan

1. Merge. The first publish fails until the owner sets `APPLE_TEAM_ID` and enables Pages with GitHub Actions as the source.
2. Owner adds a DNS `CNAME` record `antenna` → `<owner>.github.io` and turns on Enforce HTTPS once the certificate is issued.
3. Re-run the workflow from the Actions tab.

Rollback: disable Pages in the repository settings.
