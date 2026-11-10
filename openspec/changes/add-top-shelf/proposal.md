# Proposal

## Why

> As a user, I want to start watching from Siri, Shortcuts or the Apple TV home screen, without opening the app and navigating.

> As a viewer, I want my favorite channels together in one list, across all my subscriptions and devices.

> As a watcher, I want to resume a movie or episode where I left off, on any of my devices, and keep a list of things to watch later.

An Apple TV user who highlights Antenna on the Home screen sees nothing, while other TV apps show what to watch next. Antenna knows the user's favorites, what is on now and what they are part way through, and one press could tune or resume. There is no Top Shelf extension yet, and the extension cannot read the app's data directly.

Not reviewed yet.

## What Changes

- A Top Shelf extension for the Apple TV app with two rows, Favorites and Continue watching.
- Favorite channel tiles titled with the channel name and the programme on now, with a bar showing how far into the programme it is.
- Continue watching tiles for movies and episodes in progress, with how far the user got.
- A single "Add favorites in Antenna to see them here" tile when there is nothing to show.
- The app writes a small summary for the extension each time favorites, sources, the guide or progress change.
- Selecting a tile plays the channel or resumes the title, whether Antenna was running or not.
- A separate shelf per Apple TV user.
- The shelf shows only what the user has in Antenna, never suggested or bundled content, and it updates when Antenna runs, not on its own.

Out of scope:
- The large carousel shelf with video previews.
- A fixed picture on the shelf when the user has no data.
- Adding or removing favorites from the shelf.
- Programme artwork on channel tiles.
- Opening Antenna at a channel from Siri, Spotlight or web links.
- Widgets on iPhone, iPad and Mac.
- Settings to hide a row or change how many tiles show.
- How the app's navigation handles a tune or resume request, which the tvOS shell owns.

## Capabilities

### New Capabilities
- `top-shelf`: favorites and Continue watching on the Apple TV Home screen, with a tile press that tunes or resumes.

### Modified Capabilities
- `tvos-shell`: plays a channel or resumes a title from a shelf link, holding a request made at launch until the shell is ready.

## Impact

- Platforms: tvOS.
- Depends on: `favorites`, `channel-catalogue`, `guide-data`, `tvos-shell`, and the changes `add-first-run-onboarding`, `add-tv-channel-overlay`, `add-movies-and-series-browsing`, `add-watch-progress-sync`, `add-profiles`, `add-paywall-and-entitlement`.
- Needs from `tvos-shell`: play or resume from a shelf link, holding the request at launch.
- Needs from `add-tv-channel-overlay`: a channel logo lookup that never fetches.
- Needs from `add-movies-and-series-browsing` or `add-watch-progress-sync`: the Continue watching list the app can read.
- Blocked on: a decision on a storage area shared by the Apple TV app and its Top Shelf extension (an App Group) and the snapshot file the app writes there, because the extension cannot open the app's database or guide cache.
- Blocked on: the decision `add-watch-progress-sync` is blocked on, for watch progress.
- A new app extension target, an App Group on both targets, and an `antenna` URL scheme on the Apple TV app.
