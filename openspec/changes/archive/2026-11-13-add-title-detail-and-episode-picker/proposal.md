# Proposal

## Why

> As a movie and series watcher, I want to browse my provider's movies and series with posters and details, like a streaming app.

> As a series watcher, I want to pick a season and episode and see what each one is about.

> As a watcher, I want to resume a movie or episode where I left off, on any of my devices, and keep a list of things to watch later.

The movies and series change gives Movies and Series a More info button that does nothing, and plays a series from its poster without ever showing its episodes. The user cannot read what a movie is about, choose an episode, or see which episodes they have watched. TiviMate users name this gap: episodes show "only the episode number with no description".

Not reviewed yet.

## What Changes

- Movie page: artwork, kind and category, name, year, length, genre, rating and badges, description with More, cast and director, Play or Resume with progress, My list, and Trailer where the provider gives a link.
- Series page: the same top part with the number of seasons, Play or Resume naming the episode, a season picker, and the episode list with picture, number, title, length, description, progress, Watched and an UP NEXT mark.
- Ways in: More info on the Movies and Series banner, More info in a movie poster's menu, and selecting a series poster outside Continue watching or a series in search results.
- Sensible gaps when the provider leaves fields out, artwork included.
- Loading and error states with Retry and the offline message.
- Playing a movie or an episode from the page, resuming, and coming back to the page afterwards.
- Going back to the section with the starting poster in place.
- Apple TV remote navigation, and Escape, arrow keys and Return on Mac and iPad keyboards.
- The Xtream client reads cast, director, rating, trailer link, and each episode's description and picture.

Out of scope:
- Playing the next episode automatically, and any player controls.
- "More like this" and related titles.
- Ratings or artwork from outside databases.
- Playing a trailer inside the app.
- Movies from M3U playlists, downloads, parental controls and hidden categories.
- Keeping title details between launches.
- Marking an episode watched or unwatched by hand.
- Reading an episode's full description on Apple TV. Rows show one line.
- What happens when the purchase lapses while the page is open. The page is only reachable from sections that are already paid for.

## Capabilities

### New Capabilities
- `title-detail-and-episode-picker`: a detail page for a movie or series, with Play or Resume, My list, and for a series a season picker and episode list.

### Modified Capabilities
- `xtream-vod-client`: movie and series info gain cast, director, rating and a trailer link, and episodes gain a description and a picture.
- `tvos-shell`: the tab bar stays hidden while a title page is open.

## Impact

- Platforms: iOS, iPadOS, macOS, tvOS.
- Depends on: `tvos-shell`, `xtream-vod-client`, and the changes `add-live-tv-on-iphone-ipad-mac`, `add-movies-and-series-browsing`, `add-search`, `add-playback-engine` (leaving playback; tests use a stand-in player until it ships) and `add-watch-progress-sync` (storing and syncing watch progress and My list).
- Needs from other changes: in `add-movies-and-series-browsing`, a series poster outside Continue watching and More info open this page instead of playing, and Play's next-episode rule, Continue watching's included, becomes "Play starts the right episode" here. If this change is accepted first, that change's series play and Continue watching follow this rule. `add-search` opens this page for a series result. `add-playback-engine` returns to this page when playback that started here ends.
- Blocked on: the decision `add-watch-progress-sync` names for storing watch progress and My list.
