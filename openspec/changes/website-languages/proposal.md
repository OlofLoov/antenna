# Proposal

## Why

Split from `add-feature-website` on 2026-11-27, when that change was archived with the English site live at antuna.app. The owner chose on 2026-11-22 to publish English first, then Swedish, then each other language when its store listing is ready.

> As a Swedish buyer, I want to read what Antuna does in Swedish before I download it.

> As an Arabic reader, I want the site to read right to left, like the app does.

Today every page is English only, with `<html lang="en">` and no language switch. After this change a published language has every page under `/<lang>/`, its own screenshots, and a switch in the footer, and an address for a language that is not published yet answers "Page not found".

## What Changes

- An optional language segment in the site's routes that accepts only published languages, with each published language prerendered.
- `lang` and `dir` written into each page at build time, `hreflang` links to the other versions, and a footer language list of plain links that reload the page.
- A missing string fails the build, and an unpublished language answers 404, both checked by the site check.
- Swedish: the strings and the Swedish screenshots, reviewed by the owner, once the Swedish listing is ready.
- Arabic, right to left, once its store listing is no longer held and the right-to-left boards are drawn.
- Boards for the language switch and for a page right to left.

Out of scope:
- Translated Terms of Use and Privacy Policy. They stay English, at the root, until a lawyer-checked translation exists.
- A redirect by browser language.
- German, Spanish, French and Brazilian Portuguese until each listing is ready. Each comes in its own PR under this change or a later one.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `feature-website`: languages are added when their listing is ready.

## Impact

- Web: `Web/site/src/routes/` gains the language segment and a matcher, `src/lib/strings/sv.json` (later `ar.json`), `hooks.server.ts`, `Web/site/static/images/sv/`, and the site check.
- Boards: the language switch, and right-to-left versions of the web boards, in `openspec/specs/design-system/boards/`.
- Depends on the archived `add-feature-website` (decision 8 in its design.md), and on `store-listing/a-language-s-listing-waits-for-its-review` for when each language is ready.
- Blocked on the owner: his review of the Swedish text, and the Arabic store listing being released from hold.
