# Design

## Context

`PlaylistEntryKind(_:)` in AntennaCore sorts a parsed entry by folder names, an SxxEyy marker, the link's file extension and a VOD or Movies group, in that order. A live channel streamed from an `.mp4` link hits the extension rule and moves to Movies. `M3UParser` reads the `#EXTINF` duration but drops it; `Channel` has no field for it.

## Goals / Non-Goals

**Goals:**
- An entry that shows any live sign stays live unless a sign stronger than the file extension says otherwise.
- The precedence is one ordered list, tested in AntennaCore.

**Non-Goals:**
- Matching a guide id against the loaded guide.
- Changing what a folder, marker or group rule decides.

## Decisions

### Precedence

1. `series` folder: episode.
2. `movie` or `movies` folder: movie.
3. SxxEyy marker in the name: episode.
4. Group whose first word is VOD, Movie(s) or Film(s): movie.
5. Any live sign: live.
6. Video file extension: movie.
7. Otherwise live.

Folders, markers and groups are the provider naming the entry; panels and VOD playlists set them on purpose, so they beat live signs. A file extension says only how the bytes are packed, and providers serve 24/7 and news channels as `.mp4`, so it is the weakest rule and runs last. The movie group moved from last to fourth so that a movie in "VOD | Action" with a guide id stays a movie.

Options considered:
1. **Live signs first, then everything else.** A panel movie with catch-up flags copied onto every entry would land in Live, and panel playlists put `#EXTINF:-1` on movies too, so nothing from a panel would sort as a movie without a folder.
2. **Live signs only override the extension** (chosen). The rules that were right stay right; only the extension rule, the one that misfired, gets a gate.
3. **Score every sign and sum.** Hard to explain in a spec and to predict for a user reading their playlist.

### Live signs

- `hasCatchup` (from `catchup` or `tvg-rec`).
- A non-empty `tvg-id` (`Channel.epgID`). A guide id that matches the loaded guide would be a stronger sign, but the guide loads after the playlist and in parallel with it. Waiting for it would hold Live back, and sorting again after it arrives would move entries between tabs on screen. A guide id on a playlist entry is the provider saying it has a programme schedule, which a movie does not.
- A group with a word `live`, `news`, `sport` or `sports`, compared word by word after lowercasing, or containing `24/7`. Word by word so "Newsroom Films" does not count and "UK | News" does.
- An `#EXTINF` duration of -1 or 0. Panels write -1 for every entry, movies included, which is why it sits below the folder and group rules.

### Duration

`Channel` gains `duration: Double?`, the `#EXTINF` number, set by `M3UParser` and nil for other sources. It is not in `Channel.CodingKeys`, like the catch-up template: it only matters while sorting a fresh parse.

## Risks / Trade-offs

- [A plain VOD playlist with `#EXTINF:-1`, `.mp4` links and no VOD group] → its movies now stay in Live. They still play there; the user can rename the group. Movie playlists that set a length or a VOD group are unaffected.
- [A movie entry carrying a `tvg-id`] → stays in Live unless its group or link names it as a movie.
