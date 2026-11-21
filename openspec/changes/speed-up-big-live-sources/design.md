# Design

## Context

A review of Live TV with very large sources (scratchpad review, origin/main
f9392ec6) ranked eleven findings. This change takes findings 2 to 10. The
first, keeping channels and guides on disk across launches, changes what
is stored and needs an owner decision; the Keychain part of the eleventh
belongs to another change.

No board changes. The screens keep their boards (`iPhone-Guide`,
`iPad-Guide`, `TV-Channel-Overlay`, `iPhone-Live`) and the design-system
requirements they cite; only when and how much they redraw changes.

Figures below are thread CPU time on an M-class Mac, release build, median
of five, from a scratch benchmark that is not committed. Apple TV HD is
roughly four to six times slower.

## Decisions

### The seen-channel record leaves the tune path

`SeenChannelsStore.tagging` read the source's seen file, merged it,
encoded it and wrote it back before the load counted as finished, and only
then did the last channel tune.

Options:
1. Keep the record in `tagging` and make the file faster.
2. Tag only, tune, then record in a task of its own and fold the result
   into the New group when it lands.

Chosen: 2. Only the New group reads the memory. The catalogue built at
the end of the load uses whatever memory the run already holds (none at
launch, so New starts empty for a moment), and once the record lands the
New group is worked out again off the main actor with
`NewChannels.group`. A catalogue build in flight when the record lands
applies the newer memory before it shows.

### Large guides

The guide failed as `.tooLarge` past 96 MB of XML on Apple TV and 256 MB
elsewhere. Memory was never the reason a big file is a problem: the parse
streams into `SourceGuide`. What grows is what is kept.

Options:
1. Raise the byte limits only.
2. Keep only programmes for the source's channel ids.
3. Drop programmes outside a window, cap the kept slots and text, and
   fill the second half of the cap only with ids the channels name.

Chosen: 3. Option 2 alone breaks name matching and the guide entry
search, which list ids no channel names. With 3, a guide that fits keeps
everything in the window as before, and a guide for every country keeps
the source's own channels first. The byte limits stay as a safety limit
for disk and time: 128 MB gzip and 512 MB XML on Apple TV, 256 MB and
1000 MB elsewhere.

Caps: Apple TV 1,000,000 slots (56 MB) and 64 MB of text; elsewhere
3,000,000 slots (168 MB) and 192 MB of text. Window: from 7 days before
the download (the longest catch-up providers commonly offer) to 14 days
after.

The named ids are the epg ids of the source's channels and the entries
the user picked by hand, read when the fetch starts. A guide that loads
before the source's channels counts every id as unnamed, so it fills half
the caps; the next refresh fills the rest.

### Name matching

`GuideEngine.rebuild(id)` ran on every download progress event, every
250 ms, and with it the name matches. The matches are now worked out
only where their inputs change: a guide loaded, the channels changed, or
the hand-picked entries changed. `rebuild` reads the stored matches.

### Clock ticks

The iPhone and iPad Guide wrapped the whole screen in a five-second
`TimelineView`, so each tick built `GuideData` and walked every row id.
The tick moves into each row, the day chips and the now line, as the Live
list does. On Apple TV the overlay's one-minute `TimelineView` around the
`LazyVStack` moves into each row for the same reason.

### Logos

`LogoCache` gets what `PosterCache` got in fix-browse-hangs: each caller
waits on its own continuation, a cancelled caller returns nil at once,
and the last caller to leave cancels the download. A cancelled download
does not mark the logo as failed, so the next row asks again.

### Recents and the open list

A channel counting as watched replaced the catalogue, which changed
`LiveModel.rows`, so the open group's `List` compared all its ids again.
`Catalogue` gains a content revision that only a new index or new rules
change. The Live model keeps the open group's rows as stored state and
replaces them only when the group's rows can have changed. The Apple TV
overlay compares the same way.

### HLS zaps

`AVPlayerEngine.open` probed every address before handing it to
AVPlayer. For an `.m3u8` address the probe is skipped. When AVPlayer then
fails, the probe runs to map the failure the same way as before (a web
page or raw video at an HLS address reads as unreadable).

## Figures

Before, at 50 000 / 100 000 channels:

| Work | Where | 50k | 100k |
|------|-------|-----|------|
| Seen file read, merge, write | before the tune | 226 ms | 499 ms |
| `flatMap` of the sources | main | 4.9 ms | 14.1 ms |
| `[Channel] ==` on an unchanged refresh | main | 10.6 ms | 22.2 ms |
| Restored channel scan | main | 2.4 ms | 8.8 ms |
| Name matching against 5 000 guide names | guide actor, every 250 ms while a guide downloads | 198 ms | |
| A 620 MB guide, 4 000 channels, 14 days | | fails as too large after 1.9 s | |

After:

- The seen file no longer sits before the tune; it runs in its own task
  once the channels show. The New group is worked out off the main actor
  when it lands, and the catalogue is replaced only when New changed.
- The unchanged check runs during tagging, off the main actor. An
  unchanged refresh stores nothing, so neither the flat list nor the
  catalogue is rebuilt and the guide is not told about the same channels
  again. The restored channel is looked for in its own source only.
- The 620 MB guide (2 688 000 programmes, 4 000 channels, 3 days back to
  11 ahead) now loads with the Mac and iPhone caps: 1 889 604 programmes
  kept for 2 812 channels in 84 s on a heavily loaded Mac, peak 476 MB above
  the baseline. The 192 MB text cap is what stopped it, so the later
  channels in the file have no programmes. Apple TV's caps keep about a
  third of that.
- Name matching no longer reruns at the start of a load or for a channel
  list equal to the last one; it runs when the channels, a loaded guide,
  the guides turned on or the hand-picked channels change. Progress events
  update the status rows only. The review's claim that matching ran on
  every progress event was only half right: progress rebuilt the index
  entry and its 50 000-entry match table every 250 ms, while the matcher
  itself ran at the start and end of each load.

