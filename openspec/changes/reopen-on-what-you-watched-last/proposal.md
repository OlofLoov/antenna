# Proposal

## Why

The owner's decision of 2026-11-23: at launch, reopen on what the user
watched last, without playing a movie or an episode on its own.

The movie and series watcher stops an episode at night and opens Antenna
the next evening. Today the Apple TV starts the last live channel full
screen, and an iPhone, iPad or Mac opens on the last tab with no page open.
Either way they find the series again before they can press Resume.

Afterwards, when the last thing a profile watched on a device was a movie or
an episode, Antenna opens on that title's page with Resume ready at the saved
position, and nothing plays until they press it. A viewer whose last watch
was a live channel sees no change.

## What Changes

- Each device keeps, per profile, what was watched last: a live channel once
  it counts as watched after ten seconds, or a movie or episode once it
  starts playing. Only the source, title and episode ids are kept, in
  `UserDefaults`, never a link, never synced. Deleting the source forgets it.
- iPhone, iPad and Mac: when the last watch was a movie or an episode, the
  app opens Movies or Series, as it already does for that tab, and opens the
  title's page once its section lists it. A series page shows the season of
  the episode watched last. Play reads Resume as it does on that page today.
- Apple TV: after "Who's watching?", the same profile's last watch decides.
  A movie or episode opens Movies or Series with the title's page and Resume
  focused. The last channel loads behind the page, paused, as it does behind
  Movies today. A live channel plays full screen as today.
- The page opens over its section, so Back goes to the section's rows.
- Fallback: when the title is gone, its source fails, or it is not listed
  within the existing 10-second launch deadline, the launch goes on as today:
  the tab on iPhone, iPad and Mac, the last or first channel on Apple TV.
- A launch screen other than Live in Preferences, onboarding's Browse movies
  and a Top Shelf link each win over the title, as they win over the
  restored tab and the last channel today.

Out of scope:
- Starting playback of a movie or episode at launch.
- Syncing what was watched last between devices. Progress already syncs;
  this is about where each device opens.
- Trailers, multi-view tiles and the Guide's small picture: none of them
  counts as watched.
- A new screen. The title page and the sections are unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-restore-and-recently-watched`: adds "Reopen on the title watched
  last", "A title that cannot open gives way" and "What was watched last";
  "Reopen on the same tab and group" gives way to the first.
- `tvos-shell`: "Back to the last channel on launch" applies when the
  profile's last watch was a channel or nothing, and gives way to the title
  page otherwise.

## Impact

- AntennaCore: a small `LastWatched` value with its JSON form and tests.
- Apps: `RecentsStore` keeps it per profile; `SessionTracker` and
  `ShelfPlayback` write it; `LiveModel`, `RootView` and `LiveRegularView`
  reopen the title on iPhone, iPad and Mac; `ShellModel` and `ShellView` hold
  the launch tune and open the title on Apple TV; `TitleModel` opens on the
  episode's season.
- Builds on `session-restore-and-recently-watched/reopen-on-the-same-tab-and-group`,
  `tvos-shell/back-to-the-last-channel-on-launch`,
  `title-detail-and-episode-picker/play-or-resume-a-movie` and
  `title-detail-and-episode-picker/play-starts-the-right-episode` as they
  are. Blocked on nothing.
- No new container, external system or dependency, so the C4 diagrams stay
  as they are.
