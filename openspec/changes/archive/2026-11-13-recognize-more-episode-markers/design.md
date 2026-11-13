# Design

## Context

`PlaylistEntryKind` sorts an entry as an episode when its name holds an episode marker, and `EpisodeName` reads the show, season, number and title around it. Both matched only `S01E02` and `s1 e12`, each with its own copy of the pattern.

## Decisions

### One list of markers

`EpisodeName.markers` holds the patterns, compiled once, and `PlaylistEntryKind.namesAnEpisode` asks `EpisodeName`. The two can no longer disagree about what an episode is. The patterns are tried in order and the first kind that matches wins: `S01E02`, then `1x02`, then `Season 1 Episode 2`.

### The crossed number

Options considered:
- Any `NxM` (rejected): "4x4 Off-Road", "24x7 News" and "1920x1080" would all become episodes.
- A list of known false hits (rejected): it never ends.
- A one- or two-digit season, a two- or three-digit episode, and no letter or digit on either side (chosen): `(\d{1,2})[x×](\d{2,3})`. It takes "1x02", "01x02", "10x101" and "2×05", and refuses "4x4", "24x7", "1920x1080", "1x2" and "1x02b". A one-digit episode is refused because that is the shape most sizes and counts share, and playlists that write episodes this way pad the number.

A name like "64x64" still reads as season 64, episode 64. No playlist we have seen names a channel that way, and the entry then shows in Series where the user can find it.

### Spelled-out seasons

"Season 1 Episode 2", with "Ep" or "Ep." allowed for "Episode", and spaces, commas, dots, colons, bars or dashes between the two parts. The word Season makes it unambiguous.

### "Ep 2" alone

Not a marker. Options considered:
- Read it as season 1 (rejected): daily shows, event replays and music releases ("EP 2") use the same words, and a wrong guess moves a movie or a live channel into Series.
- Leave it out (chosen). The entry keeps the rule it had before.

No screen changes, so no board applies.
