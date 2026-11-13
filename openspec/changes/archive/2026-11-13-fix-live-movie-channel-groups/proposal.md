# Proposal

## Why

> As a viewer with an M3U subscription, I want my live movie channels to stay in Live.

Many playlists group live movie channels as "Movies" or "UK Movies | HD" with `.ts`, `.m3u8` or extensionless links. The playlist sorter treats any group whose first word is Movie or Film as on-demand, so those channels leave Live and show up as movies that never end. The screenshot seed caught it: its four live "Movies" channels vanished from Live.

## What Changes

- A group starting with "VOD" still makes an entry a movie.
- A group starting with "Movie", "Movies", "Film" or "Films" makes an entry a movie only when its link ends in a video file extension. Otherwise the entry goes through the remaining rules and a live stream stays live.

Out of scope:
- Groups that name movies further in, such as "UK Movies". They never counted as movie groups.
- Asking the user to sort entries by hand.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `m3u-playlists`: the movie group rule needs a video file link for Movie and Film groups.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS. AntennaCore only.
- Depends on: `m3u-playlists` as changed by `add-m3u-vod-fallback` and `tighten-playlist-entry-kinds`.
- A playlist that loaded before this change sorts again on its next refresh.
