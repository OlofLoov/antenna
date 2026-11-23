# Design

## Context

See proposal.md for why. On 2026-11-23 the product name appears as "Antenna"
in about 3,000 places outside the archive: Swift strings, the three String
Catalogs, specs, boards, docs, the site, the store listing and Terraform.
Most of those are code names inside identifiers (`AntennaCore`,
`AntennaTV`, `se.codecrave.antenna`), which this change keeps. The app has
not been uploaded to App Store Connect or TestFlight, and only the owner's
devices run a development build.

No screens change layout. The boards' visible text says Antuna; no board is
added. Design-system requirements followed: none change, the text is
shorter by one letter everywhere it appears.

## Decisions

### 1. What is renamed and what is kept

Renamed, because a user, reviewer or visitor reads it:

| Where | What |
|-------|------|
| `project.yml` | `CFBundleDisplayName` of the app, the Apple TV app and the Top Shelf extension; the local network usage text; `AntennaTermsURL` and `AntennaPrivacyURL` values (the keys stay); `productName: Antuna` on the `Antenna` target |
| `Apps/Shared/InfoPlist.xcstrings` | `CFBundleName` and `CFBundleDisplayName`, Antuna in every language |
| `Apps/Shared/Localizable.xcstrings`, AntennaCore's `Localizable.xcstrings` | every key and translation that names the app |
| Swift | user-facing strings, the app icon choice "Antuna", the sidebar wordmark, the launch splash label, Siri replies, the "Antuna player" stream line, comments |
| `JellyfinWire` | `Client="Antuna"`, which the Jellyfin dashboard shows |
| `SetupLink.host`, `Config/Antenna.entitlements`, `Config/AntennaMac.entitlements` | antuna.app |
| `Config/Antenna.storekit` | the group name and product descriptions in Xcode's StoreKit testing |
| `Web/` | the site's strings and pages, the setup page, the review playlist file name and guide address |
| `fastlane/metadata/*` | name, description, release notes, support and privacy addresses in all nine locales |
| docs, README, CLAUDE.md, specs, active changes, boards, C4 diagrams | the product name |
| `Infra/` | the `antuna` root, bucket, role, CloudFront, budget and tag names, `ANTUNA_DOMAIN` |
| `release-please-config.json` | `package-name` |

Kept, because an installed build or the toolchain reads it, or it is a code
name:

| What | Why |
|------|-----|
| Bundle ids `se.codecrave.antenna`, `.tv`, `.tv.topshelf`, and the products `se.codecrave.antenna.lifetime` and `.yearly` | A new bundle id is a new app: the owner's devices would lose every UserDefaults value, the Keychain items under the old access group, and the purchase |
| The Apple team, `iCloud.se.codecrave.antenna`, `group.se.codecrave.antenna`, the Keychain access group `se.codecrave.antenna.shared` and service `se.codecrave.antenna.sources` | The synced SwiftData store and every saved login live there |
| The Handoff activity type `se.codecrave.antenna.setup` | An older build on another device sends it |
| UserDefaults keys, file names in the app's folders, the `antenna-file:` source address, the `{antenna.…}` login placeholders in saved playlists, the `antenna://` Top Shelf scheme | Stored on the device or in synced records; tvOS keeps Top Shelf links it was given |
| The Logger subsystem and thread names (`se.codecrave.antenna…`) | Match the bundle id; Console filters use them |
| Packages and modules `AntennaCore`, `AntennaDemux`, the app module `Antenna`, targets, schemes, `Antenna.xcodeproj`, type names such as `AntennaMark` and `AntennaApp`, `ANTENNA_*` build settings and environment variables, `-antenna.*` launch arguments | Code names. Renaming them touches every import and CI path for no visible change |
| The repository slug `OlofLoov/antenna` in the FFmpeg package URL and the FFmpeg notice's release link | Both point at existing releases. GitHub redirects them once the owner renames the repository |
| Archived changes and CHANGELOG | History |
| The Channels DVR group "Antenna" in fixtures | That is Channels DVR's own name for over-the-air channels |

Options considered: rename everything including identifiers (a clean slate,
but the owner's devices lose their data and the module rename touches every
file), rename only the display name (the listing, site and specs would
disagree with the app), or rename what people see and keep identifiers
(chosen).

### 2. The Mac app's name

On iPhone, iPad and Apple TV the Home Screen shows `CFBundleDisplayName`. On
the Mac, Finder shows the `.app` file name and the menu bar shows
`CFBundleName`, both from `PRODUCT_NAME`, which defaults to the target name
`Antenna`. The `Antenna` target gets `productName: Antuna` in `project.yml`,
so XcodeGen points the test hosts at `Antuna.app/Antuna`, and the setting
`PRODUCT_NAME: Antuna` builds the app under that name. The setting
`PRODUCT_MODULE_NAME: Antenna` keeps the module, so
`@testable import Antenna` and anything archived under the module name still
resolve. The Apple TV app keeps `AntennaTV.app`; tvOS never shows the file
name.

Options considered: leave `PRODUCT_NAME` and set only `CFBundleName` (the
menu bar would say Antuna, Finder would still say Antenna), or rename the
target (also renames the module and every test import).

### 3. Domain

Every address on antenna.code-crave.se moves to antuna.app in this change,
ahead of `add-aws-hosting` tasks 1.1 and 3.5. The old address never served
anything (Pages was never enabled), so nothing breaks that works today, and
the new one serves once the owner registers it and the first deploy runs.
`add-aws-hosting` group 5 is ticked here. A setup link from a build older
than this one names the old host and is refused by a newer iPhone as "not a
setup link"; only the owner's devices can hold such a build.

### 4. The website capability

`openspec/specs/antenna-website` becomes `antuna-website`, with the delta
folders in the four active changes that touch it. Tests and the site's
Vitest cite `antuna-website/…`. Requirement names that held "Antenna"
(`programme-reminders/a-banner-while-antenna-is-open`, `app-intents/nothing-works-until-antenna-is-unlocked-and-set-up`,
`top-shelf/a-tile-that-no-longer-matches-opens-antenna-as-it-was`,
`iphone-as-setup-device/an-iphone-without-antenna-gets-a-plain-page`,
`hosting/the-site-is-served-over-https-on-antenna-s-domain`,
`app-release/the-app-store-addresses-are-on-antenna-s-domain` and the rest)
are renamed in place, and their citations with them.

The spec wording changes in place rather than as MODIFIED deltas: the
meaning of each requirement stays, and a delta per requirement would copy
most of the specs into this change for one word.

### 5. Infrastructure

Nothing is applied in AWS, so the names change freely: `Infra/antuna`
(state key `antuna.tfstate`), `antuna-terraform-state-<account>`,
`antuna-site-<account>`, the roles `antuna-diff`, `antuna-deploy` and
`antuna-site`, and the `project = "antuna"` tag. The trust subjects come from
`github.repository`, so renaming the repository later needs one re-apply of
`Infra/ci` and nothing in the repo.

## Risks / Trade-offs

- The name Antuna may be taken on the App Store. → The owner checks when
  creating the App Store Connect record; the name is one line per locale in
  `fastlane/metadata/*/name.txt` plus the display names.
- The site's screenshots in `Web/site/static/images/` and the store set show
  "Antenna" until they are taken again. → The nightly App screenshots
  workflow makes a new store set from main; `scripts/site-screenshots.sh`
  copies it into the site in a follow-up.
- The owner's Mac ends up with both `Antenna.app` and `Antuna.app` with the
  same bundle id. → The owner deletes the old one; data lives in the shared
  container and stays.
