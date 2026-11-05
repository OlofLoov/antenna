# User stories

What people want to do with Antenna, in their words. Every spec in
`docs/specs/` names the stories it serves on its `User stories:` line, so a
reader can go from "why" to "what" in one hop. Stories change rarely; specs
come and go underneath them.

The stories come from the owner's product direction and from
`docs/research/tivimate-user-sentiment.md`, which records what users of the
leading Android IPTV player love, hate and ask for.

Ids are stable. A story that no longer applies is struck through, not
renumbered.

## Who uses Antenna

- **The living-room viewer.** Watches live TV on an Apple TV with the Siri
  Remote, mostly news and sport, often channel-hopping. Wants it to feel like
  cable: fast, predictable, no menus in the way.
- **The household setter-upper.** Has one or more IPTV subscriptions and sets
  things up for the family, on several Apple TVs and phones. Hates typing long
  URLs and passwords with a remote, and hates doing it twice.
- **The sports fan.** Wants several games at once, a quick way back to live
  after pausing, and catch-up when they miss the start.
- **The on-the-go viewer.** Watches on iPhone, iPad or Mac, in bed, on a
  train, at a desk. Expects the same channels, favorites and progress as at
  home.
- **The movie and series watcher.** Uses the provider's on-demand library and
  wants it to feel like a streaming app, not a file list.

## Setting up

- **US-1** As a new user, I want to add my IPTV subscription (a playlist link
  or provider login) in a few steps, so I am watching within minutes of
  installing.
- **US-2** As a household setter-upper, I want sources I add on one device to
  appear on my other devices, so I never type a URL or password twice.
- **US-3** As a household setter-upper, I want to type long details on my
  iPhone instead of with the TV remote, so setting up an Apple TV is not a
  chore.
- **US-4** As a user with several subscriptions, I want them merged into one
  channel list and one guide, so I do not switch between apps or lists.
- **US-5** As a user, I want to edit, refresh or remove a source, and change
  how the app behaves, so my setup stays right as my subscription changes.
- **US-6** As a user of a less common service (a Stalker portal, Jellyfin,
  Channels DVR) or of a playlist file on disk, I want to use it like any
  other source.
- **US-7** As a user, I want my passwords kept private, so a synced device or
  a log never shows them in plain text.

## Watching live TV

- **US-8** As a living-room viewer, I want to flip channels quickly with the
  remote, by up and down or by typing a number, so it feels like cable.
- **US-9** As a viewer, I want to see what is on now and next without leaving
  the picture, so I can decide whether to stay.
- **US-10** As a viewer, I want a guide grid of what is on across channels
  over the coming days, so I can plan what to watch.
- **US-11** As a viewer, I want to browse live channels by group on iPhone,
  iPad and Mac, so the phone and computer are as useful as the TV.
- **US-12** As a viewer, I want my favorite channels together in one list,
  across all my subscriptions and devices.
- **US-13** As a viewer, I want simple player controls (pause, audio track,
  subtitles, programme info) and a clear message when a stream fails, so I
  know what happened and what to try.
- **US-14** As a sports fan, I want to pause and rewind live TV, and start a
  programme over or watch one I missed when my provider allows it.
- **US-15** As a sports fan, I want to watch up to four channels at once on
  Apple TV or Mac, and choose which one I hear.
- **US-16** As a viewer, I want a reminder when a programme I care about is
  about to start.
- **US-17** As a viewer, I want the app to come back to the channel I was
  watching, and to find recently watched channels quickly.

## Movies and series

- **US-18** As a movie and series watcher, I want to browse my provider's
  movies and series with posters and details, like a streaming app.
- **US-19** As a series watcher, I want to pick a season and episode and see
  what each one is about.
- **US-20** As a watcher, I want to resume a movie or episode where I left
  off, on any of my devices, and keep a list of things to watch later.

## Finding things

- **US-21** As a user, I want one search across channels, guide programmes,
  movies and series, so I do not have to know where something lives.
- **US-22** As a user, I want to start watching from Siri, Shortcuts or the
  Apple TV home screen, without opening the app and navigating.

## Organising

- **US-23** As a user with thousands of channels, I want to hide, rename,
  reorder and lock groups, and make my own, so the list shows what I watch.
- **US-24** As a user whose guide does not match my channels, I want to pick
  the guide source and fix a channel's match by hand.
- **US-25** As a family sharing one Apple TV, I want each person's
  favorites, history and progress kept separate.

## Paying

- **US-26** As a buyer, I want to pay once, share the purchase with my
  family, and restore it on a new device without contacting anyone.
