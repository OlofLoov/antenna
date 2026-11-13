# Proposal

## Why

> As a movie and series watcher with an Xtream subscription, when I open a series I want its episodes listed, and when I pick one I want it to play.

The owner reports "loads of could not load episodes" and episodes that will not stream, while movies mostly work. A movie whose details fail to load still plays, but a series has nothing to play until its episode list decodes, so the same panel faults show up only on series. Reading the decoder against the shapes real panels send gives these causes.

- Panels built on PHP often print a notice before the JSON, leave text after it, store plots in Latin-1 or Windows-1252, or put raw tabs and line breaks inside strings. The decoder refuses the whole body, so the page shows "Could not load episodes".
- A series whose seasons are numbered from 0 comes back as an array of season arrays. Every season failed as one broken episode and the list was empty.
- A season whose episodes are keyed by episode number comes back as an object, which gave no episodes.
- An episode the panel lists as `mp4` (or with no extension) whose file is really Matroska or MPEG-TS went to Apple's player, which cannot read it.
- A dropped connection to the panel showed "Could not load episodes" instead of the offline message, and nothing recorded why a load failed.

## What Changes

- Panel bodies that are almost JSON are cleaned before decoding: a byte-order mark, a PHP notice before the JSON and text after it are dropped, bytes that are not UTF-8 read as Windows-1252, and control characters inside strings are escaped. A web page still fails.
- `episodes` as an array of season arrays gives each season's episodes, the season taken from the position. A season keyed by episode number, or holding one episode object, gives its episodes.
- Apple's player hands an address whose first bytes are MPEG-TS, Matroska or AVI to the FFmpeg path, with no error between.
- A panel that cannot be reached because the device is offline shows the offline message on the title page.
- A failed title, episode list or episode address is logged with a reason that holds no address, login or body.
- A playlist series the kept load does not know asks the playlist once more before it fails.

Out of scope:
- Audio that does not play on some streams, and seeking in episodes. Other changes cover them.
- New screens or strings. The page keeps "Could not load episodes" with Retry.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `xtream-vod-client`: "Episodes flatten" covers season arrays and seasons keyed by episode number; new "Panel bodies that are almost JSON".
- `playback-engine`: "Every common stream type plays" hands a file address whose bytes need the FFmpeg path to it.
- `title-detail-and-episode-picker`: "When details or episodes do not load" shows the offline message for a panel that cannot be reached offline and keeps a private reason.
- `m3u-playlists`: "Playlist series show in Series" asks the playlist again for a series its kept load does not have.

## Impact

- Platforms: iPhone, iPad, Mac and Apple TV. All of it is shared code.
- Depends on: `xtream-vod-client`, `playback-engine` and the FFmpeg path, `title-detail-and-episode-picker`.
- Not verified against the owner's provider, which this work cannot reach. The fixtures copy the shapes named above.
