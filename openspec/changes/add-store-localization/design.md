# Design

## Context

Boards: none. The change adds no screen and changes none; the store set
photographs screens that already have boards (`iPhone`, `iPhone-Guide`,
`iPhone-Movies`, `iPhone-Title-Player-Transport`, `iPhone-Onboard-2`, their
iPad counterparts, `TV-ZapBar`, `TV-Guide`, `TV-Movies`,
`TV-Title-Player-Transport`). No design-system requirement changes; no identifier is added.

What exists today:
- No store text anywhere. `docs/release/` holds the App Review notes, the
  App Privacy answers and the device checklist. The Terms of Use on the
  site describe the app and the two purchases in plain English.
- The app ships `en sv de es fr pt-BR ar` (`Config/languages`), and
  `Config/reviewed-languages` lists `sv de es fr pt-BR`. Arabic is
  translated but held until the right-to-left work lands.
- The `App screenshots` workflow runs the `AntennaJourneys` and
  `AntennaTVJourneys` walk-throughs in English on an iPhone Pro, an iPad
  Pro 13-inch and an Apple TV 4K, and uploads `app-screenshots`.
- Every walk-through launches through `launchInEnglish()`, which adds
  `-AppleLanguages (en) -AppleLocale en_US` unless the arguments already
  name a language. iPhone tab bar buttons have no identifier, so the iPhone
  walks tap them by their English label.

## Goals / Non-Goals

Goals:
- One listing per App Store locale, in files a tool can upload later, and
  a check that keeps them complete and inside Apple's limits.
- Store screenshots per language from the same walk-through machinery.

Non-goals:
- Uploading, App Store Connect setup, prices, age rating.
- Mac screenshots, captions or device frames.
- Locales without an app language (en-GB, pt-PT, de-AT and the rest).

## Decisions

### 1. Where the listing lives

`fastlane/metadata/<store-locale>/<field>.txt`, one file per field:
`name`, `subtitle`, `description`, `keywords`, `promotional_text`,
`release_notes`, `privacy_url`, `support_url`. App-wide fields sit at
`fastlane/metadata/`: `copyright.txt`, `primary_category.txt`,
`secondary_category.txt`.

This is the layout `fastlane deliver` reads by default, so a later upload is
`deliver --skip_binary_upload` with no path options. A script on the App
Store Connect API reads plain text files just as well. The repo does not
take fastlane as a dependency; the folder name is the only tie.

Options considered:
- One Markdown file per language under `docs/release/`. Easy to read, but
  every upload path would need a parser, and the field boundaries would be
  conventions in prose.
- JSON per locale. One file to diff, but no tool reads it as it is, and a
  4000-character description in a JSON string is hard to review.
- `fastlane/metadata` (chosen). One field per file makes length limits and
  review diffs per field.

App Store Connect splits these fields in two: name, subtitle and the
privacy address are app information, shared by the iOS, macOS and tvOS
versions; description, keywords, promotional text, what's new and the
support address belong to each platform's version. The same files serve
all three platforms. A tvOS-only description is not needed: the copy
already names each device where a feature is device-specific.

What's new cannot be set on an app's first version. `release_notes.txt`
holds the first version's line anyway, so the field is never empty; the
upload step leaves it out for 1.0 and the release checklist rewrites it for
each later version.

### 2. Store locales per app language

| App language | Store locales | Screenshot region |
|---|---|---|
| `en` | `en-US` (primary) | `en_US` |
| `sv` | `sv` | `sv_SE` |
| `de` | `de-DE` | `de_DE` |
| `es` | `es-ES`, `es-MX` | `es_MX` |
| `fr` | `fr-FR`, `fr-CA` | `fr_FR` |
| `pt-BR` | `pt-BR` | `pt_BR` |
| `ar` | `ar-SA` | `ar_SA` |

The table lives in `scripts/store_metadata.py` (`STORE_LOCALES`), next to
the check that uses it. A language added to `Config/languages` without a
row fails the check.

The app has one Spanish and one French. The store gets two of each because
storefronts index different locales: the United States and Mexico read
`es-MX`, Spain reads `es-ES`; Canada reads `fr-CA`, France `fr-FR`. Without
`es-MX` and `fr-CA` those storefronts show English. The two files of a pair
carry the same description, promotional text and what's new, and differ in
keywords where the markets search differently (decision 4). The screenshots
are taken once per app language and filed under both.

Options considered: one store locale per app language (rejected, Mexico,
the United States' Spanish speakers and Quebec would see English), and
every storefront locale (rejected, en-GB, en-AU and pt-PT would be copies
to keep in sync with no app language behind them).

### 3. The English listing

Written from the specs and the Terms of Use, not from a feature wish list.
Each claim maps to a requirement in `openspec/specs/`:

- Sources: `m3u-playlists`, `local-m3u-file-import`, `xtream-live-source`,
  `stalker-portal-source`, `jellyfin-live-tv-source`, `channels-dvr-source`,
  `guide-sources-and-channel-mapping`.
- Live TV: `live-tv-on-iphone-ipad-mac`, `tv-guide-grid`,
  `timeshift-catch-up-and-start-over` ("rewind up to an hour"; start over
  and catch-up are worded as depending on the provider),
  `group-management`, `favorites`, `programme-reminders`, `multi-view`
  (Apple TV, iPad and Mac), `search`.
- Movies and series: `movies-and-series-browsing`, `watch-progress-sync`,
  `up-next`.
- Apple TV: `tv-zap-bar-and-number-entry`, `top-shelf`,
  `apple-tv-login-from-iphone`.
- Every device: `watch-progress-sync`, `profiles`, `app-intents` (iPhone,
  iPad and Mac only), `keyboard-commands`.
- Purchase and privacy: `paywall-and-entitlement`, the Terms of Use and
  `docs/release/app-privacy.md`.

Left out on purpose: HDR, Dolby Vision, Atmos and frame-rate matching. The
playback path is built to keep them, but no requirement proves them on a
device yet. "Thousands of channels", "works with any provider" and similar
claims depend on the user's source and are never made.

The English listing uses American spelling ("program"), while the app's
English strings say "programme". The store copy follows the repo's prose
rule; aligning the app is outside this change.

Subtitle: "IPTV player with a TV guide". The App Store searches the name
and subtitle words, so they are the most valuable 37 characters; "IPTV",
"player", "TV" and "guide" are the words people search for this kind of
app.

### 4. Keywords

Rules every language follows, enforced by the check where a script can:
- Commas with no spaces, no repeats, no word already in the name or the
  subtitle (the App Store already searches those).
- Format and feature words only: `m3u`, `m3u8`, `epg`, `xmltv`, live,
  channel, playlist, catch-up, timeshift, multi-view, and the local words
  for them.
- No third-party trademarks, including the server software the description
  names (Xtream Codes, Stalker, Jellyfin, Channels DVR). Guideline 2.3.7
  rejects trademarks in keywords; naming compatible formats in the
  description is fine. The owner can revisit "xtream" as a keyword; it is
  the most searched of them and the most likely to draw a rejection.
- No genre words that read as a content promise ("sports", "movies free",
  "football"), and no competitor app names.

Per market: the Spanish pair differs where Spain and Latin America search
differently (decision recorded with the translations), the French pair
where Quebec does. Each language's choices are in the review notes below.

### 5. Terms per language

The store copy uses the app's own words from the String Catalogs, so a
screenshot and the text under it agree:

| English | sv | de | es | fr | pt-BR | ar |
|---|---|---|---|---|---|---|
| Live | Live | Live | En vivo | En direct | Ao vivo | مباشر |
| Guide | Tablå | Programm, Programmführer | Guía | Guide | Guia | الدليل |
| Catch-up | Se i efterhand | Mediathek | A la carta | Replay | Reprise | إعادة المشاهدة |
| Multi-view | Multivy | Multi-View | Multivista | Multivue | Multivisão | العرض المتعدد |
| Favorites | Favoriter | Favoriten | Favoritos | Favoris | Favoritos | المفضلة |
| Settings | Inställningar | Einstellungen | Ajustes | Réglages | Ajustes | الإعدادات |
| Family Sharing | Familjedelning | Familienfreigabe | En familia | Partage familial | Compartilhamento Familiar | المشاركة العائلية |
| Lifetime | Livstid | Dauerhaft | Para siempre | À vie | Vitalício | مدى الحياة |
| Profiles | Profiler | Profile | Perfiles | Profils | Perfis | الملفات الشخصية |

Address: Swedish "du", German "du", Spanish "tú", French "vous",
Portuguese "você", as in the app. French uses a no-break space before
`:` `;` `?` `!`, as the app does since its review. Product names stay in
Latin letters in Arabic (Apple TV, iPhone, iCloud, M3U, Xtream Codes,
Jellyfin, Channels DVR, XMLTV).

### 6. The check

`scripts/store_metadata.py check`, wrapped by
`scripts/check-store-metadata.sh`, run by `scripts/fast-checks.sh` and the
Lint workflow's Repo rules job. Python, like `scripts/translations.py`, so
it runs without Xcode in a second.

It fails when:
- a code in `Config/languages` has no row in `STORE_LOCALES`, or one of its
  store locales has no folder, or a folder has no app language;
- a field file is missing, empty, or has leading or trailing spaces;
- a field is over its limit, counted in characters: name and subtitle 30,
  keywords 100, promotional text 170, description and what's new 4000;
- keywords have a space around a comma, an empty entry, a repeat, or a word
  from the name or subtitle;
- the privacy or support address is not on `https://antenna.code-crave.se/`;
- a text field carries any other web address, names one of a list of
  providers, broadcasters, leagues, streaming services and players, puts a
  word for "free" within two words of a word for channels, TV or movies, or
  puts a number of two or more digits before one of those words;
- the description lacks the per-language phrase for "no channels" or for
  "purchase" (`MUST_SAY`).

The name list and the phrase patterns are a net, not a proof. The review
of each language reads the copy for 5.2.3 as well.

`StoreListingTests` in AntennaCore runs the script on the repo and on
broken copies in a temporary folder (a language without a listing, a long
subtitle, spaced keywords, a broadcaster, a held language), and cites the
requirements. It follows `ReleaseTests`, which runs repo scripts the same
way.

Options considered: the check as Swift tests only (rejected, a future
upload step wants the same check without building AntennaCore), and
fastlane `precheck` (rejected, it needs fastlane, Ruby and an App Store
Connect login).

### 7. Held languages

A language is ready when it is English or listed in
`Config/reviewed-languages`, the same file the Release build reads to strip
unreviewed `.lproj` folders. Nothing else marks a listing as held.
`store_metadata.py locales` prints the ready languages with their region
and store locales; `held` prints the rest. The upload step (later) and the
screenshot run read the same output, so Arabic's listing is checked today
and goes out the day `ar` is added to `Config/reviewed-languages`.

### 8. Store screenshots

A new walk per platform, `testStore` in `AppJourneys` and `TVJourneys`, that
takes the screens a store page shows:

| Step | iPhone and iPad | Apple TV |
|---|---|---|
| 1 | `live`: the Live list, `-ui-testing-live favorites` | `live`: the zap bar over the picture, `-ui-screenshots full` |
| 2 | `guide`: the guide | `guide`: the guide grid |
| 3 | `movies`: Movies, `-ui-testing-shelf watching` | `movies`: Movies with the banner |
| 4 | `player`: a movie with its controls | `player`: a movie with the bar up |
| 5 | `add-source`: the add-source form, `-ui-screenshots empty` | `add-source`: the source kinds, `empty` |

The last step shows that the user brings the source.

The iPhone and iPad walk starts on the scripted Live launch rather than the
screenshot seed: the seed's Xtream source has no login, so its Live list
shows a failed-source banner and its guide stays loading. The scripted
launches draw small test probes (engine state, a layout switch) in a
corner; a new Debug-only `-ui-testing-no-probe` argument hides them, and
the store walk passes it. The pictures are still test fixtures: a black
player picture, made-up names in English. They prove the pipeline and show
the translated screens for review; a seed made for the store is a later
change.

The walk reads `STORE_LANGUAGE` and `STORE_REGION` from its environment.
`xcodebuild` passes `TEST_RUNNER_STORE_LANGUAGE` to the test runner as
`STORE_LANGUAGE`, so the workflow builds once (`build-for-testing`) and
runs `test-without-building -only-testing:.../testStore` once per ready
language. `Journey.launch` adds `-AppleLanguages (<language>) -AppleLocale
<region>` when they are set; `launchInEnglish()` then leaves them alone.
Without them the walk runs in English, so it runs locally like the others.

The iPhone walks tapped tabs by label, which breaks in any other
language. The first plan gave the compact tabs `tab.<id>` identifiers
through `TabContent.accessibilityIdentifier`; on the iOS 27.2 simulator the
tab bar buttons still report no identifier, only the translated label. The
iPhone walks now open a tab by its place in the tab bar instead: Live 0,
Guide 1, Movies 2 when a source offers titles, Search and Settings the
last two. No app code changes. The iPad already uses
`browse.section.<id>`. Apple TV steps already use identifiers only.
Arabic, once it ships, needs a look: whether the tab bar lists its buttons
in reading order or screen order decides if the places hold.

Devices and sizes:
- iPhone: the workflow now picks the first "iPhone N Pro Max", whose 6.9-inch
  screenshots (1320 x 2868) are the size App Store Connect requires. The
  English walk-throughs move to the same phone, so one iPhone boots.
- iPad Pro 13-inch: 2064 x 2752, the required iPad size.
- Apple TV 4K: 3840 x 2160, accepted for tvOS.
The status bar override (9:41, full bars) applies to the store set too.

Artifact `store-screenshots`, kept 14 days, laid out the way `deliver`
reads screenshots:

```
store-screenshots/<store-locale>/<nn>-<device>-<step>.png
store-screenshots/<store-locale>/appleTV/<nn>-<step>.png
```

`scripts/export-screenshots.sh` gets a `--store <locale,...>` mode that
writes this layout and copies each picture to every store locale of the
language. The English walk-throughs and their `app-screenshots` artifact
stay as they are.

Which languages: by default `store_metadata.py locales`, so English and the
reviewed languages. A run started by hand takes a `languages` input (for
example `ar`) to photograph a held language for review.

Run time: the store walk is five steps, about two minutes per language and
platform after the build. Six languages add about 25 minutes, so the job's
timeout goes from 60 to 120 minutes. Considered: a matrix job per language
(rejected, six more macOS runners queue behind CI for a build each), and the
store walk only on demand (rejected, the nightly run is what catches a
walk broken by a screen change).

Fixtures: the channel names, programme titles and posters come from the
existing seeds (`News One`, `Sport One`, "Northern Lights"), all made up.
The seed's "Tennis TV" shares its name with a real service, so it becomes
"Tennis Live".

Provider data in the pictures (channel and programme names) stays English
in every language, as it would arrive from a source.

### 9. Platforms

The listing covers iPhone, iPad, Mac and Apple TV: one app record with
universal purchase, three platform versions. Screenshots cover iPhone,
iPad and Apple TV. The Mac version needs Mac screenshots before it can be
submitted; the workflow does not run the Mac app, and taking them is a
later change (owner to-do).

## Risks / Trade-offs

- [The name "Antenna" may be taken on the App Store] → the owner checks
  when creating the record; `name.txt` changes in every locale at once, and
  the check counts the new length.
- [A keyword or phrase rule misses a 5.2.3 problem] → the per-language
  review reads each listing for claims and names, and App Review reads it
  again.
- [Apple counts keyword length differently for Arabic] → App Store Connect
  rejects an over-long field at upload, which names it; the check counts
  characters, as Apple's help describes.
- [A store walk breaks on a translated screen] → the walk anchors on
  identifiers only; a failing language fails its step and the other
  languages still export.

## Migration Plan

None. New files and a longer CI job. Rolling back is reverting the PRs.

## Open Questions

- Support address: the site has no support page; `support_url.txt` points
  at the Terms of Use, which end with the support email. A support page is
  an owner to-do.
- Categories: Entertainment, then Photo & Video, for the owner to confirm.
