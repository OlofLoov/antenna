# Proposal

## Why

> As someone in Stockholm, Munich, Madrid, Lyon, São Paulo or Riyadh browsing the App Store, I want Antenna's page in my language, with pictures of the app in my language, so I can tell what it does and that it needs my own IPTV source before I download it.

The app speaks seven languages since `add-localization`, but there is no
App Store listing yet: no subtitle, no description, no keywords and no
screenshots in any language. The `App screenshots` workflow takes English
pictures for review, not pictures in the sizes and languages the App Store
asks for. After this change the repo holds the listing for every language
the app ships, CI fails when one is missing or too long for App Store
Connect, and the screenshot workflow produces a store set per language.

## What Changes

- An English listing written from what the app does today: name, subtitle,
  description, keywords, promotional text, what's new, and the privacy and
  support addresses. The description says a purchase is required and that
  the app comes with no channels.
- The same listing in Swedish, German, Spanish (Spain and Mexico), French
  (France and Canada), Portuguese (Brazil) and Arabic, using the terms the
  app's own screens use in each language. Machine first pass, then a review
  per language.
- The files live in `fastlane/metadata/<locale>/<field>.txt`, the layout
  fastlane `deliver` reads and a script on the App Store Connect API can
  read as well. Nothing is uploaded.
- A check, run in CI and before each push, that fails when a language the
  app ships has no listing, when a field is empty or over Apple's limit,
  when keywords repeat or waste characters, or when the copy names a
  provider, a broadcaster, a competing app, or a web address other than
  Antenna's own.
- A language whose app text is still held back by `Config/reviewed-languages`
  (Arabic today) keeps its listing in the repo, checked like the others, but
  is reported as held and left out of the store screenshots.
- The `App screenshots` workflow also takes a store set: a short walk on
  the App Store's iPhone, iPad and Apple TV sizes, run once per ready
  language with that language and region, uploaded as a `store-screenshots`
  artifact laid out per App Store locale.

Out of scope:

- Uploading anything to App Store Connect, creating the app record, or
  setting prices, age rating and categories there.
- Mac screenshots. The workflow does not run the Mac app.
- In-app purchase display names and descriptions per language.
- Text over the screenshots (captions, device frames). The set is the app
  as it runs.
- Translating the website.
- Portuguese (Portugal), English (UK) and other App Store locales without an
  app language of their own. Those storefronts show the English listing.

## Capabilities

### New Capabilities
- `store-listing`: what the App Store listing says in each language, which
  languages have one, the limits it stays within, what it never claims or
  names, and the screenshots taken for it.

### Modified Capabilities

None.

## Impact

- New: `fastlane/metadata/`, `scripts/store_metadata.py`,
  `scripts/check-store-metadata.sh`, a `StoreListingTests` suite in
  AntennaCore that runs the check.
- Changed: `.github/workflows/screenshots.yml`, `.github/workflows/lint.yml`,
  `scripts/fast-checks.sh`, `Apps/Journeys` and `Apps/TVJourneys` (a store
  walk that takes its language from the test runner), `docs/conventions.md`, `docs/release/`.
- Depends on: `add-localization` (the app languages, their terms and
  `Config/reviewed-languages`) and `add-app-screenshots-ci` (the walk-throughs
  and the workflow).
- Blocked on: nothing in the repo. The App Store Connect record, whether the
  name "Antenna" is free on the store, and a support page are owner to-dos.
