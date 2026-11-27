# Design

## Context

The site at antuna.app is a prerendered SvelteKit app in `Web/site/`, English only, built and published by `add-feature-website`. Its text comes from `src/lib/strings/en.json`. `Web/site/scripts/check-site.js` fails any page without `<html lang="en">`. The stylesheet uses CSS logical properties, so a right-to-left page needs no second stylesheet.

`add-feature-website` decision 8 settled how languages work, and this change carries it out. The decisions are repeated here so this change reads on its own.

## Boards

Not drawn yet, and drawn first in this change:
- The footer language list on `Web-Home` and `Web-Home-Phone`.
- Right-to-left versions of `Web-Home`, `Web-Home-Phone`, `Web-Feature`, `Web-Pricing` and `Web-Support`, before Arabic ships.

Design-system requirements that apply: "Copy fits in every language" and "Layouts mirror in right-to-left languages".

## Decisions

### 1. Routing and build

English stays at the root. Each other language lives under `/<lang>/` (`/sv/`, then `/de/`, `/es/`, `/fr/`, `/pt-br/`, `/ar/`) through an optional route parameter, `src/routes/[[lang=lang]]/`, whose matcher accepts only published languages, so `/de/` answers 404 until German ships. The root layout's `entries` lists every published language for each route, so each is prerendered. Text comes from `src/lib/strings/<lang>.json`, and a missing key fails the build. The Terms of Use and Privacy Policy stay English only, at the root, and each language's footer links to them there.

`<html lang>` and `dir` are written into each page at prerender time by `hooks.server.ts` (`transformPageChunk` replacing `%lang%` and `%dir%` in `app.html`). Each page carries `<link rel="alternate" hreflang>` to its other versions. The language switch is a plain list of links in the footer, so it works without scripts. Those links carry `data-sveltekit-reload`, so a language change is a full page load and the new `lang` and `dir` come from the prerendered HTML.

### 2. No redirect by browser language

CloudFront would need the `Accept-Language` header in the cache key, and a visitor landing on a language they did not pick is worse off than one who clicks once.

### 3. Arabic

`dir="rtl"` from the hook, the logical-property stylesheet as it is, the boards' right-to-left versions drawn first, and screenshots from the Arabic store set, which is already right to left.

## Risks / Trade-offs

- Until a language's site ships, its buyers have the store listing only.
- `check-site.js` hard-codes `lang="en"` today. Task 1.2 teaches it the published languages, or every translated page fails it.

## Open Questions

None. The owner decided the order on 2026-11-22.
