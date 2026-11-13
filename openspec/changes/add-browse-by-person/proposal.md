# Proposal

## Why

From the owner's list: "Movies by actor; Series by actor".

> As a movie and series watcher, I liked her in this; what else does my subscription have with her?

> As a movie watcher, I remember the director, not the title.

Today a title page shows the provider's cast and director as one line of text, and only for providers that send them in the per-title info call. Nothing leads from a name to other titles. Building it from provider data would mean a details call per title across catalogues of tens of thousands, which providers rate-limit and ban.

After this change a matched title's cast and director are names the user can select. Each opens a page with that person's movies, series and directing work that the user's sources have, and Search finds people by name.

## What Changes

- A person's page on every platform: photo or initials, name, department, "<n> in your sources", and Movies, Series and Directed rows of titles the user can play.
- The filmography comes from TMDB in one request per person through the lookup service, and is matched on the device against loaded titles. The provider gets no request.
- Cast and crew on a matched title's page become selectable names, at most 15. Unmatched titles keep the plain text.
- A People section in Search, last, with up to three people who have titles in the user's sources, filled after three letters and a pause in typing, only online with lookups on.
- Filmographies kept on the device for seven days.
- The Privacy Policy and the lookups footer in Settings name person pages and names typed in Search.

Out of scope:
- A biography, birthday or known-for list from TMDB on the person page.
- People's photos in the cast list on the title page.
- A People chip in Search's kind filter.
- Following a person or alerts when a new title with them arrives.
- Writers, composers and other crew beyond directors.
- Browsing by person with lookups off. Provider cast strings are names without ids, and matching them across a catalogue needs a details call per title.

## Capabilities

### New Capabilities
- `browse-by-person`: the person's page, which titles it lists, picking a name in the cast, and finding a person in Search.

### Modified Capabilities
- `search`: People joins the result sections, last.
- `antenna-website`: the Privacy Policy names person pages and names typed in Search among what the movie info service receives.

## Impact

- AntennaCore: matching a filmography against the catalogue (the trending matcher from `add-discover-rows` takes any list of database entries), the person page model, the people search rules.
- Apps: a person screen on each platform, cast chips on the title page, a People section in Search.
- The lookup service gains `/v1/person/{id}` and `/v1/people?query=`.
- Boards: new `iPhone-Person`, `iPad-Person`, `TV-Person`, `iPhone-Title-Cast`, `TV-Title-Cast`, `iPhone-Search-People`.
- Depends on `add-title-metadata` for everything: the lookup service, the TMDB agreement, matched titles with credits, the lookups switch. Reuses the list matcher from `add-discover-rows` task group 4; if that lands later, this change builds it.
- Nothing here ships without external data.
- Edits `add-title-metadata`'s Settings footer line and its boards so the line covers person lookups, since neither change is archived.
