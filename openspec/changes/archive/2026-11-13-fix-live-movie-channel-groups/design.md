# Design

## Context

`PlaylistEntryKind` sorts a playlist entry with ordered rules. The group rule sat above the live signs and matched the first word VOD, Movie(s) or Film(s). Live movie channels in a "Movies" group matched it.

## Decisions

### What a Movie or Film group needs

Options considered:
- Keep the group rule and let live signs win over it. A live movie channel without a guide id, catch-up or a -1 duration would still leave Live, and plain VOD playlists that write `#EXTINF:-1` would lose their movies.
- Drop Movie and Film from the group rule. Extensionless VOD files in a "Movies" group would then stay in Live.
- Require a video file link for Movie and Film groups, keep VOD unconditional (chosen). Xtream panels serve movies from a `movie` folder, which an earlier rule already catches, and plain hosts serve files with an extension. Live streams end in `.ts`, `.m3u8` or nothing.

A Movie or Film group with a video file still beats live signs, so a VOD playlist whose entries all say `#EXTINF:-1` keeps its movies in Movies.

No screen changes, so no board applies.
