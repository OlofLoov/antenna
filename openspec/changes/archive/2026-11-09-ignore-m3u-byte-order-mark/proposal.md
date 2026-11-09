## Why

Some playlists start with a byte-order mark, an invisible character that Windows
editors and some provider panels write at the top of a text file. The parser
does not see past it, so the first line is never read as the header or as a
channel. A playlist with a header loses its guide links and the user gets
channels with an empty guide and no error; a playlist without a header loses
its first channel. This is for the new user who wants "to add my IPTV
subscription (a playlist link or provider login) in a few steps, so I am
watching within minutes of installing", and today gets a guide that never fills.

## What Changes

- A byte-order mark at the very start of a playlist is ignored, so the header
  and the first channel parse as if it were not there.

Out of scope:
- A byte-order mark anywhere other than the start of the file.
- Encodings other than UTF-8, such as UTF-16 playlists.
- The same check for XMLTV guide files.

## Capabilities

### New Capabilities

### Modified Capabilities
- `m3u-playlists`: adds a requirement that a leading byte-order mark is ignored.

## Impact

- AntennaCore: the M3U parser and its tests. No app or UI change.
- Depends on nothing and blocked on nothing.
