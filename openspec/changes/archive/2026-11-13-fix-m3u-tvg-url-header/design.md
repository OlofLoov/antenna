# Design

## Context

`M3UParser` reads header guide links from a fixed list of attribute names. Providers use three spellings: `url-tvg`, `x-tvg-url` and `tvg-url`. The third was missing.

## Decisions

### Order of the three attributes

Per header line the order is `url-tvg`, `x-tvg-url`, then `tvg-url`. Options considered:
- Put `tvg-url` first. This changes which link wins for playlists that name two spellings, and the first link is the one a source falls back to (`GuideURLResolver`).
- Put it last (chosen). Playlists that work today keep the same first guide link.

No screen changes, so no board applies.
