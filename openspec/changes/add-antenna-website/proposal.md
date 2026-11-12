# Proposal

## Why

The app already links to antenna.code-crave.se, and nothing answers there. The paywall's Terms of Use and Privacy Policy links lead nowhere, which App Review rejects for an app that sells a yearly subscription and a lifetime unlock. Setup links open Safari instead of Antenna, because the association file that tells iOS the domain belongs to the app was never published.

Who it is for:
- Someone deciding whether to buy: "What am I paying for, how do I cancel, and what happens to my data?"
- The household setter-upper who scans the Apple TV's code with an iPhone: "The link should open Antenna, not a web page."
- App Review: "The subscription screen links to working terms and a privacy policy."

Afterwards the four addresses the app uses work: `/setup`, `/terms`, `/privacy` and the association file, all published from the repo by a GitHub Pages workflow on each push to main that changes them.

## What Changes

- A Terms of Use page at `/terms` and a Privacy Policy page at `/privacy`, in plain English, written from what the app does: data stays in the user's own iCloud and Keychain, network requests go only to the sources the user adds and to Apple, no analytics or tracking, purchases through the App Store. Each has a "Last updated" date and links to the other.
- The association file at `/.well-known/apple-app-site-association`, listing Antenna's app id for `/setup`. The Apple team id is not known yet, so the committed file holds a placeholder that the publish step replaces, and publishing fails while no team id is set.
- A GitHub Pages workflow that publishes `Web/` with the custom domain, including the `.well-known` folder.
- The existing setup page at `/setup` stays as it is.

Out of scope:
- A home page at `/`, a support page, or a marketing page.
- Translations of the legal pages.
- Serving the association file from a host that can set response headers (see the design's risks).
- Turning on GitHub Pages in the repository settings and adding the DNS record. Only the owner can do those.

## Capabilities

### New Capabilities
- `antenna-website`: the static site at the app's domain: which addresses it serves, the association file, the legal pages and what they must say, and how it is published.

### Modified Capabilities
None.

## Impact

- `Web/`: new legal pages, the association file, `CNAME` and `.nojekyll`.
- `scripts/publish-web.sh` fills the team id; `.github/workflows/pages.yml` runs it and deploys.
- AntennaCore tests read the files under `Web/` and run the publish script.
- CLAUDE.md's Layout describes the whole site.
- Depends on change `add-iphone-as-setup-device` (the setup page and the association file's format) and change `add-paywall-and-entitlement` (the products the terms describe). Blocked on the owner for the Apple team id, the Pages setting, the DNS record, the contact address and a legal review.
