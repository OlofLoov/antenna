# Device checklist

Checks that no simulator, CI runner or `swift test` can make: a real iCloud
account syncing between two devices, Siri, Picture in Picture, a receiver, a
real purchase, timings on named hardware. Each item names the OpenSpec change
and task it came from, what to do and what you should see. Run them in one
sitting per section, with the devices on the same Wi-Fi.

## The rule

A change is archived when everything in it is built, every requirement has a
test that a simulator, CI or `swift test` runs and that cites it, and what is
left can only be checked on hardware, with a real iCloud account or with a real
purchase. Its task is ticked with a pointer to this file, and the check lives
here. A change stays open while code or a test a simulator can run is missing.

Until 2026-11-13 such changes stayed open instead, as `complete-source-management`
did with its one two-device check. That left 25 changes unarchived and the main
specs out of date, so the checks moved here.

When an item fails, open a `fix-...` change that cites the requirement named in
the item. The archived change stays archived. When an item passes, tick it here
and add the date and devices next to it.

## Setup

- iPhone and Apple TV 4K on tvOS and iOS 26 or later, signed in to the same
  Apple Account, with iCloud Drive and iCloud Keychain on.
- An iPad and a Mac on macOS 26 for the items that name them, on the same
  account. One iPad item needs it signed out of iCloud.
- A development build of Antenna on each device (Xcode Run with
  `Config/Local.xcconfig` set), or TestFlight for the purchase items.
- An M3U playlist and an Xtream login you own. For the timing items, a source
  with about 20 000 channels and a seven-day guide.

## One iPhone or iPad

- [ ] **add-app-intents 3.6, Siri phrases.** Open Antenna once with a source
  loaded, lock the iPhone, and say "Tune to <a channel name> in Antenna", then
  "Search Antenna", then, with a channel playing, "Add this channel to favorites
  in Antenna" and "Remove this channel from favorites in Antenna". Expect Siri
  to ask you to unlock for the tune and the search, then Antenna opens on Live
  playing that channel, or on Search. The favorite phrases answer without
  opening the app, and the channel shows up in, then leaves, Favorites.
- [ ] **add-player-controls-and-playback-errors 6.1 and add-playback-engine 8.3,
  Picture in Picture.** Play an HLS channel and swipe home. Expect a small window
  that keeps playing, with working play and pause. Close it, play a raw MPEG-TS
  channel (one whose link ends in `.ts`) and swipe home again: the same.
  Change channel from the window's controls if they offer it, then tap the
  restore button. Expect Antenna back on Live, playing the channel the window
  showed.
- [ ] **add-player-controls-and-playback-errors 6.2, background audio.** Play a
  channel, lock the iPhone and wait a minute. Expect the sound to go on and the
  lock screen to show the channel with play and pause. Call the iPhone from
  another phone: playback pauses, and plays again when the call ends. Unplug wired or disconnect
  Bluetooth headphones: playback pauses and stays paused.
- [ ] **add-player-controls-and-playback-errors 5.1, AirPlay.** With an Apple
  TV or AirPlay speaker on the network, tap the AirPlay button in the player and
  pick it. Expect the picture or sound to move there and the player to say
  "Playing on AirPlay" with the device name.
- [ ] **add-timeshift-catch-up-and-start-over 2.3, recording fails.** Fill the
  iPhone's storage until under 1 GB is free, play a channel and press pause,
  then play. Expect "Not enough free storage to rewind live TV" on the first
  pause, the picture frozen while paused, and live again on play. Free some
  space, play a channel, pause for a minute, then fill the storage while it is
  paused. Expect playback back at live without stopping and "Storage is full.
  Back to live TV" said once.
- [ ] **add-live-tv-on-iphone-ipad-mac 2.3, 20 000 channels.** On an iPhone 15
  with the large source loaded, open Live. Expect the first rows within one
  second of the tab appearing, and a five-second flick that does not stutter.
- [ ] **add-guide-on-iphone-ipad-and-mac 6.3, guide timings.** On an iPhone 15
  and an M1 iPad, with the large source and seven days of guide, open Guide.
  Expect the first rows within one second, and no visible hitch while scrolling
  across channels and days.
- [ ] **add-movies-and-series-browsing 2.5, library timing (iPhone).** On an
  iPhone 15 with a provider library of about 20 000 titles in 400 categories,
  open Movies. Expect the first shelves within two seconds.
- [ ] **add-search 2.5 and add-title-detail-and-episode-picker 6.1, Escape on a
  keyboard.** On an iPad with a hardware keyboard, press Command-F, type a few
  letters and press Escape. Expect the query cleared and the field closed. Open
  a movie from Movies, press Escape: back to Movies at the same scroll position.
  Open one from Search, press Escape: back to Search with the query kept.

## One Mac

- [ ] **add-app-intents 4.2, Shortcuts on the Mac.** In Shortcuts, run Tune
  Channel, Play Title, Open Search and Toggle Favorite once with Antenna closed
  and once with a channel playing. Expect Antenna to open on the channel, the
  title or Search, and Toggle Favorite to answer without bringing Antenna
  forward.
- [ ] **add-player-controls-and-playback-errors 5.1, Mac keys.** Play a channel
  in Live. Press M: sound off, M again: sound on. Command-Up and Command-Down:
  the volume slider moves.
- [ ] **add-multi-view 4.1, start on the Mac.** Right-click a channel in Live
  and choose the multi-view item, then press Command-Shift-M on another channel.
  Expect two tiles, the sidebar folded, and the window refusing to shrink below
  1024 points wide.
- [ ] **add-multi-view 4.2, tiles on the Mac.** With three tiles, click each one
  and press Command-1 to Command-3. Expect the selection and the sound to follow.
  Pick a channel in the list: it fills the selected tile. Double-click a tile:
  it fills the window, and double-click again goes back. Remove a tile, then
  leave multi-view: the remaining channel keeps playing in Live.
- [ ] **add-search 2.5 and add-title-detail-and-episode-picker 6.1, Escape.** Do
  the iPad keyboard item above on the Mac.

## Apple TV

- [ ] **add-top-shelf 3.3, Top Shelf.** Install a signed build, watch two
  channels and part of a movie, then put Antenna in the top row of the Home
  Screen and highlight it. Expect the shelf to show the channels and the movie
  Antenna wrote, and selecting a tile to open Antenna playing it.
- [ ] **add-playback-engine 8.1, picture format.** Turn on Match Content in
  Settings, Video and Audio. Play an HEVC HDR10 channel. Expect the TV to switch
  to HDR, the info panel to name HEVC and HDR10 within two seconds, and a second
  HDR10 channel at the same frame rate to play without another mode switch.
  Repeat with an HLG channel if your provider has one.
- [ ] **add-playback-engine 8.2, surround sound.** With a receiver or soundbar
  that takes Dolby Digital Plus, play a channel with AC-3 and one with E-AC-3
  (Atmos if you have it), on an HLS channel and on a raw `.ts` channel. Expect
  the receiver's display to show Dolby Digital, Dolby Digital Plus or Atmos.
  With TV speakers only, the same channels play with sound.
- [ ] **add-playback-engine 9.3, 1080i50.** On an Apple TV 4K, play a 1080i50
  broadcast channel with fast motion, such as football. Expect smooth motion with
  no combing on moving edges. In Xcode's Instruments with the Antenna signposts,
  expect 50 frames a second shown.
- [ ] **add-playback-engine 10.1, switching speed.** On an Apple TV 4K (3rd
  generation) on Ethernet, record 50 channel changes on raw `.ts` channels and
  50 on HLS channels in Instruments. Expect half the raw switches within 1.0
  second and nine in ten within 1.5 seconds, and half the HLS switches within
  2.0 seconds.
- [ ] **add-tv-channel-overlay 1.3, overlay timing.** On an Apple TV 4K (3rd
  generation) with the large source, press select on the full-screen picture.
  Expect the channel rows within one second.
- [ ] **add-tv-guide-grid 2.5, guide timing.** Same Apple TV, seven days of
  guide. Open Guide in Instruments. Expect the first frame within one second and
  no hitch longer than one frame over 20 seconds of scrolling.
- [ ] **add-movies-and-series-browsing 2.5, library timing (Apple TV).** The
  same as the iPhone item, on an Apple TV 4K (3rd generation).
- [ ] **add-multi-view 6.1, four tiles for 30 minutes.** On each Apple TV 4K
  generation you have, and on an M1 Mac, run four tiles against the fixture
  server (`scripts/make-stream-fixtures.sh`) for 30 minutes and move the sound
  20 times on each tile. Expect no tile to freeze or drop out, the sound to move
  each time, and the "tile audible" signposts in Instruments to match the moves.
  This is the requirement `multi-view/four-tiles-hold-up-on-real-hardware`.

## iPhone and Apple TV on one iCloud account

- [ ] **add-iphone-as-setup-device 1.1, platform questions.** On the Apple TV,
  start onboarding and reach the QR card. Expect, and write down in the
  archived change's design.md: whether the iPhone shows a Handoff offer for
  Antenna in the App Switcher; whether, after Connect on the iPhone, the TV says
  the source arrived (SwiftData posted its CloudKit export); whether the link
  works without the associated domain in the TV's entitlements.
- [ ] **add-apple-tv-login-from-iphone 7.2, the login drop.** Run the "Only on
  devices" list in the archived change's design.md, Testing section: scan the TV's
  code with the iPhone camera (Antenna opens on "Sign in your Apple TV"), tap
  Send, and time it until the TV says the login arrived. Expect the source to
  load on the TV, the iPhone to say the login was picked up, and the QR code to
  scan from the couch. Record the times in that design.md.
- [ ] **add-apple-tv-login-from-iphone 6.1, Reduce Motion.** Turn on Reduce
  Motion in Accessibility on both devices and repeat the send. Expect the words
  "In progress" where a spinning ring would show, on the TV's card and on the
  iPhone's sending sheet. XCUITest cannot turn the setting on.
- [ ] **add-local-m3u-file-import 5.1, a file source on the Apple TV.** Import an
  `.m3u` file on the iPhone. Expect the Apple TV to list the source, show
  "Waiting for iCloud" until the file arrives, then load its channels and play
  one.

## Two devices on one iCloud account

Any two of iPhone, iPad, Mac and Apple TV, unless the item names them. Each
item ends on device B with nothing done there but waiting up to a minute with
Antenna open.

- [ ] **complete-source-management 2.1, sources.** On A, add an M3U source and
  an Xtream source. On B, open Sources and Settings. Expect both rows in the same
  order with name, type and status and no link, the M3U source loaded, and the
  Xtream source waiting for its login and then loading once iCloud Keychain
  delivers it.
- [ ] **add-sources-and-settings 4.1, delete.** On A, delete the Xtream source
  and confirm. On B, expect the source, its favorites and its channels gone.
- [ ] **fix-m3u-channel-ids 2.5, rewritten favorites.** Install a build from
  before `fix-m3u-channel-ids` on A, favorite three M3U channels, then install
  the current build on A and B. Expect each favorite once on both devices, not
  twice.
- [ ] **add-group-management 5.2, groups.** On A, hide a group, rename one, lock
  one and make a group of your own. On B, expect the same, with the locked group
  closed until you unlock it on B.
- [ ] **add-guide-sources-and-channel-mapping 5.5, guides.** On A, add a guide
  link, turn one guide off, reorder the guides and match one channel by hand. On
  B, expect the same guides, order and match, and the matched channel's
  programmes in the guide.
- [ ] **add-profiles 5.3, profiles.** On A, add a profile "Kids" and favorite a
  channel as Kids. On B, expect "Who's watching?" to offer Kids, and the favorite
  only under Kids.
- [ ] **add-programme-reminders 5.3, reminders.** On B, set a reminder on a
  programme later today. On A, expect it in Settings, Reminders.
- [ ] **add-watch-progress-sync 6.1, progress, My list and searches.** Use an
  iPhone, an Apple TV and a Mac on the account and an iPad signed out of iCloud.
  On the iPhone, watch half a movie, add a series to My list and search for
  something. Expect the Apple TV and the Mac to show the movie in Continue
  watching at the same point, the series in My list and the search in recent
  searches. Put the iPhone in Airplane Mode, watch more of the movie, and turn
  Airplane Mode off: the later position shows on the other two. The iPad keeps
  its own progress and shows none of it.

## Real purchase

TestFlight or a sandbox Apple Account, once the App Store record for every
platform exists.

- [ ] **add-paywall-and-entitlement 5.1, one purchase everywhere.** Buy the
  yearly subscription on the iPhone. Open Antenna on an iPad, a Mac and an Apple
  TV on the same Apple Account. Expect each to skip the paywall without a
  purchase or Restore. This is the requirement
  `paywall-and-entitlement/one-purchase-on-every-device`.
- [ ] **add-paywall-and-entitlement 5.2, Family Sharing.** On a device signed in
  to another member of the same family group, open Antenna. Expect it to open
  without buying. Family Sharing does not work in TestFlight, so this one waits
  for the App Store release.

## Owner setup, no device

- [ ] **add-iphone-as-setup-device 1.2, publish the site.** Set the repository
  variable `APPLE_TEAM_ID` to the ten-character team id, point the DNS name
  `antenna.code-crave.se` at GitHub Pages, and rerun the Pages workflow. Expect
  `https://antenna.code-crave.se/.well-known/apple-app-site-association` to serve
  the association file with the team id, and `/setup` to show the plain fallback
  page with no scripts, images or third-party content.
