# App Store listing

The listing for every App Store locale is in `fastlane/metadata/`, one
file per field, in the layout fastlane `deliver` reads. Nothing in the repo
uploads it.

| App language | Store locales |
|---|---|
| English | `en-US` (primary) |
| Swedish | `sv` |
| German | `de-DE` |
| Spanish | `es-ES`, `es-MX` |
| French | `fr-FR`, `fr-CA` |
| Portuguese (Brazil) | `pt-BR` |
| Arabic | `ar-SA` |

Each locale folder has `name`, `subtitle`, `description`, `keywords`,
`promotional_text`, `release_notes` (What's New), `privacy_url` and
`support_url`. The app-wide `copyright`, `primary_category` and
`secondary_category` sit in `fastlane/metadata/` itself.

`scripts/check-store-metadata.sh` checks every locale, held ones included:
each field present and inside Apple's limit, keywords without spaces or
repeats, Antuna's own addresses only, and no provider, broadcaster, league
or competing player named. It runs before each push and in the Lint
workflow.

## Which languages go out

A language goes out when it is English or listed in
`Config/reviewed-languages`, the list the Release build uses to keep a
language in the app. `python3 scripts/store_metadata.py locales` prints the
ready ones; `held` prints the rest. Arabic is held until its right-to-left
layout ships.

## Screenshots

The `App screenshots` workflow uploads a `store-screenshots` artifact with
one folder per ready store locale: `<nn>-<device>-<step>.png` for the
iPhone 6.9-inch and iPad 13-inch, `appleTV/<nn>-<step>.png` for Apple TV,
and `mac/<nn>-<step>.png` for the Mac app's window at 1440 by 900 points
(2880 by 1800 pixels on a Retina screen). To photograph a held language,
run it by hand with that language:

```sh
gh workflow run screenshots.yml --ref main -f languages=ar
```

## Before the first upload

Set these in App Store Connect by hand; the files do not cover them:

- The app record, with iOS, macOS and tvOS and universal purchase, and the
  primary language English (U.S.).
- Age rating, price and availability, the two in-app purchases and their
  display names per language.
- Leave What's New out on version 1.0. App Store Connect does not take it
  on an app's first version.
- The App Review notes from `docs/release/app-review-notes.md` and the
  privacy answers from `docs/release/app-privacy.md`.
