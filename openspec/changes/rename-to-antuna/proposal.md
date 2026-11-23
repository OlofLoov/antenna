## Why

The owner renamed the product Antuna (antenna and tune) on 2026-11-23 and
picked the domain antuna.app, with the API at api.antuna.app. The app is not
published yet, so nothing in a store, a user's link or an installed build
outside the owner's own devices holds the old name. Renaming now costs a pull
request; renaming after launch would cost a new listing.

Afterwards everyone who sees the product reads Antuna: the name under the icon
on iPhone, iPad, Mac and Apple TV, every screen and Siri reply in every app
language, the paywall, the App Store listing in every language, the App Review
notes and the website. The setup and sign-in links, the Terms and Privacy
links and the review playlist live on antuna.app. The owner's test devices
update in place and keep their sources, logins, favorites and settings.

## What Changes

- The display name, the Mac app's file and menu name, and the Top Shelf
  extension's name are Antuna. The brand stays "Antuna" in every language.
- Every user-facing string that names the app, in Swift and in the String
  Catalogs for each language in `Config/languages`, the Info.plist usage
  text, the paywall, accessibility labels, Siri and Shortcuts replies, the
  StoreKit configuration and the Jellyfin client name shown on the server's
  dashboard say Antuna.
- Every address on antenna.code-crave.se moves to antuna.app: the setup link
  host, the associated domains entitlement, the Terms and Privacy links, the
  store support and privacy addresses, the review playlist's guide and the
  release docs. This is `add-aws-hosting` task group 5, done now at the
  owner's word.
- The review playlist is `Web/review/antuna-review.m3u`.
- The website, the store listing in all nine store locales, the App Review
  notes, the privacy answers, the device checklist, README, CLAUDE.md, the
  specs, the active changes, the boards' visible text and the C4 diagrams say
  Antuna. The `antenna-website` capability becomes `antuna-website`.
- `<antenna-domain>` in `add-aws-hosting`, `add-support-requests`,
  `add-feature-website` and `add-title-metadata` becomes antuna.app; the
  support repository is `OlofLoov/antuna-support` and its GitHub App "Antuna
  Support".
- Terraform: the `Infra/antenna` root becomes `Infra/antuna`, and the state
  bucket, site bucket, IAM roles, CloudFront names, budget, tags and the
  domain variable (`ANTUNA_DOMAIN`) use the new name. Nothing is applied in
  AWS yet.

Out of scope:
- Identifiers an installed build reads: bundle ids, the Apple team, the iCloud
  container, the App Group, the Keychain service and access group, the
  Handoff activity type, UserDefaults keys, file names and the URL schemes.
  Renaming them would drop the owner's test data and logins.
- Code names: the Swift packages and modules (`AntennaCore`, `AntennaDemux`,
  the `Antenna` app module), targets, schemes, `Antenna.xcodeproj` and type
  names.
- Archived changes and CHANGELOG history.
- Renaming the GitHub repository. Workflows already read
  `github.repository`; the owner renames it later.
- Registering antuna.app and the App Store Connect app record.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-release`: adds one requirement, the app is called Antuna wherever a
  person sees it, and an update keeps what the device had.
- Every capability whose text names the app says Antuna. The wording changes
  in place, with the meaning kept; requirement names that held the old name
  change their test citations with them.
- `antenna-website` is renamed `antuna-website`.

## Impact

- Apps: `project.yml` (display names, `productName: Antuna` for the
  iPhone, iPad and Mac target with its module kept as `Antenna`, Terms and
  Privacy addresses), the entitlements' associated domain, both Info.plist
  files, the String Catalogs, Swift strings, previews, tests and UI tests.
- AntennaCore: user-facing text, `SetupLink.host`, the Jellyfin client name,
  tests and fixtures that compare text.
- Web, fastlane, docs, scripts, workflows, Infra, openspec.
- Depends on nothing. `add-aws-hosting` task 1.1 keeps the registration for
  the owner; its group 5 is done here.
- Owner steps after merge: register antuna.app, create the App Store Connect
  record under the name Antuna, set `ANTUNA_DOMAIN`, and delete the old
  `Antenna.app` on the Mac after installing `Antuna.app`.
