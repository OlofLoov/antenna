# TiviMate user sentiment: what people love, hate and wish for

Research note, 2026-11-03. Input for Antenna product specs. Not a spec itself.

TiviMate (Armobsoft FZE) is the de-facto reference IPTV player on Android TV
and Fire TV. Antenna targets the platforms TiviMate does not serve (iPhone,
iPad, Mac, Apple TV), so the question this note answers is: what does the
TiviMate community value enough that Antenna must match it, and what do they
complain about that Antenna can do better?

## TL;DR

- **What keeps people on it:** the remote-first guide and UI, one lifetime
  fee, merged favourites across many playlists, multi-view for sports, and
  deep customisation of groups, logos and layout. "Tivimate is king of IPTV
  players" is a representative quote; so is "once you learn how to use it".
- **What they hate:** recording that is "hit and miss", the five-device cap on
  a lifetime licence, no settings or favourites sync between devices, a free
  tier where "almost nothing useful happens", slow or absent updates, VOD that
  is "not really very good", weak timeshift (about two minutes of pause, no
  rewind), and a purchase flow routed through a separate Companion app.
- **The loudest wish-list items, in order:** cloud sync of settings and
  favourites, timeshift / live rewind, reliable recording on Android 11+,
  more than five devices, native phone/tablet/Mac apps, better EPG matching
  and search, Trakt integration, built-in subtitle search.
- **Apple users are a known gap.** "There isn't any tvOS client for TiviMate";
  Apple users are told to use IPTV Smarters ("not even close to Tivimate"),
  iPlayTV, IPTVX, UHF, Tivimax or Chillio, none of which is a consensus pick.
- **Trust is a problem around the product, not the player.** Trustpilot for
  tivimate.org is 2.1/5, dominated by purchase, activation, refund and support
  complaints, some of them about clone sites. Nobody there calls the UI bad.

## Method and caveats

Sources read in full by fetching pages: Trustpilot (40 reviews, two pages),
seven TROYPOINT Insider forum threads (2021 to May 2026, about 200 posts), two
Channels DVR community threads, AlternativeTo, APKMirror/Uptodown/Soft112
version lists, and three comparison blogs. Web search snippets added Whirlpool
(AU), TechKings, Husham forum, and a handful of review blogs.

Not reachable, and therefore underweighted:

- **Reddit** (r/TiviMate, r/IPTV). reddit.com blocks our fetcher, and mirror
  sites were refused by the permission classifier. Reddit content appears only
  via second-hand quotes ("the developer is not bothered to address people's
  concerns on Reddit").
- **Google Play reviews.** The store page is client-rendered. Search snippets
  put the main app at about 4.1 stars from about 8.5k reviews and the
  Companion app at 3.2. Treat as approximate.
- **YouTube transcripts and comments.** Pages are client-rendered. Channel
  names and titles come from the public oEmbed endpoint; sentiment is inferred
  from titles and descriptions only.
- **TechKings, Whirlpool, Husham, APKMirror release pages, AppBrain** returned
  403 or a bot-check page. Only their search snippets are used.

Bias warning. Most "TiviMate review 2026" blog posts are written by IPTV
subscription sellers or affiliate sites and read as marketing. They are used
here only for the pricing and feature matrix, never for sentiment. The
TROYPOINT forum is the best-quality source: long-time users, dated posts,
specific devices and versions.

## Source overview

| Source | Type | Signal |
| --- | --- | --- |
| TROYPOINT Insider "TiviMate Feature Wish-list" (Jan 2026, 5 pages) | Forum, power users | Best single source for wishes and pain |
| TROYPOINT Insider "Best IPTV player" (2023), "IPTV player options" (2023), "Tivimate review" (2024), "TiviMate is NOT free" (2023), "Timeshift vs catchup" (2024-25), "Setup catchup" (2023-25) | Forum | Praise, competitor switching, timeshift and recording detail |
| Trustpilot tivimate.org | Consumer reviews | 2.1/5, 40 reviews, 60% one-star. Purchase and support anger; some clone-site confusion |
| Channels DVR community (2021, 2024-25) | Forum, Apple-heavy | Multi-view praise, channel numbering, Apple TV gap |
| Google Play (snippets only) | Store reviews | 4.1/5 main app, 3.2/5 Companion |
| AlternativeTo | Directory | No reviews, 4 likes, 56 alternatives listed |
| APKMirror, Uptodown, Soft112 | Release history | Cadence and sparse changelogs |
| YouTube (18 videos resolved) | Creators | Almost entirely promotional or install guides |

## What people love

Ranked by how often it came up unprompted.

1. **The TV guide and remote-driven UI.** "The one thing that I really like
   about TiviMate is the user interface. It's simple to use" (TROYPOINT, Jan
   2026). "The most polished in the category" for remote navigation (Sama
   blog). Channel switching "under 1 second" versus 2-3 s in Smarters is a
   claim repeated across blogs. The 5.0 redesign (Apr 2024) was received as
   "sleeker" and "the EPG look better", at the cost of a channel-order
   regression users had to fix in settings.
2. **One reasonable fee, forever.** "Pay one reasonable fee for a lifetime of
   Premium. Pay and don't worry about it again." "Less than a night out at
   Olive Garden for a lifetime sub." Current price is about $9.99/year or
   $33.99 lifetime for up to five devices.
3. **Many playlists merged into one guide and one favourites list.** "There is
   no need to leave one iptv listing to enter another." One user combined 11
   services into a single favourites guide. Backup to cloud and restore on a
   second device is praised as the way to clone a setup.
4. **Multi-view for sports and news.** "Spectacular", "mind blown". "The best
   by a mile for multi-view solutions." Up to four streams; audio follows the
   highlighted tile. Channels DVR users push nine streams into it on a Shield.
5. **Customisation depth.** Groups you can create, rename, hide, lock and
   reorder; logo folders and logo priority; colour themes ("changing colors
   was a big hit with me"); skip-step sizes; auto frame rate; parental
   controls; PiP; recently-watched list.
6. **Hidden and locked groups** keep the guide clean on providers with
   thousands of channels, which also "helps with load times".
7. **It just plays.** Multiple reviewers on Trustpilot and the forums say it
   buffers less than the provider's own app and that it "works well" where
   five other players did not.

## What people dislike

1. **Recording is unreliable.** "A huge complaint about Tivimate is its
   inconsistent recording." "Sometimes it will stop after 30 minutes." "It
   will say its recorded 60 minutes but no player can play it." Root cause
   cited repeatedly: on Android 11 and newer the system storage picker does
   not appear on many boxes (Mecool, M9, onn), so recording to external
   storage fails; BuzzTV and rooted boxes work. Recordings are `.ts` only, and
   "recording freezes if the app is open during recording". Trustpilot: "Does
   not record as advertised."
2. **Five devices per lifetime account, and clumsy device management.**
   "Number One is to increase the limit." "The only way you can add more than
   5 devices is you have to buy another Tivimate Premium subscription with a
   second email account." "I need to remove devices." Users who set up IPTV
   for family hit the cap first.
3. **Nothing syncs.** "Saving the settings in the cloud would be my #1
   wishlist item." "It doesn't sync anything to other devices." "Setting up
   urls etc. can be a pain in the neck." Backup/restore is manual and "has
   always been a pain". A long-time Premium user left for iMPlayer solely for
   sync, while still saying "I love the interface and customization inside of
   Tivimate".
4. **The free tier is a demo.** "Almost nothing useful happens in the 'free'
   version. What a complete disappointment." One playlist, two days of EPG,
   no recording, no catch-up, no multi-view, no groups editing. Trustpilot
   adds that VOD and series from the provider appear but prompt for Premium,
   "which is not disclosed on the site or Google Play".
5. **Slow development.** "Tivimate hasn't done an update in probably over a
   year?" (Oct 2023). "No substantial updates since 5.2.0 (Aug 2025)" (Jan
   2026). Release history confirms the pattern: 5.0 in Apr 2024, 5.1 Aug 2024,
   5.2 Aug 2025, 5.3.x May-Jun 2026, with changelogs that say "Fixes and
   improvements". "I don't hold much hope for tivimate to add new features."
6. **VOD and series are an afterthought.** "Tivimate is great for live TV but
   not really very good for VOD." Episodes show "only the episode number with
   no description". New films appear in Smarters days before TiviMate or not
   at all. Users run Kodi, Stremio, Emby or Smarters alongside it for VOD.
7. **Timeshift is nearly absent.** "Without a doubt timeshift! It's the one
   glaring feature missing." Pause works for about two minutes; "you cannot
   ff/rw your timeshift". Catch-up exists but is provider-side and "found less
   and less". Sparkle TV is cited as "far superior" here.
8. **Purchase flow and support.** Premium is bought via the separate
   Companion app with a Google account; Fire TV without Play Services needs a
   workaround. Trustpilot is full of "premium didn't work", "refund request
   ignored", "unresponsive" on Telegram, email and WhatsApp. Some of this is
   clone sites ("the real deal is through the app on google play"), but the
   Companion app itself sits at 3.2 stars and an 80-year-old forum member
   could not work out "how does the two come together".
9. **EPG gaps blamed on the app.** "No EPG with some providers. I've stopped
   using Tivimate because of this." Regulars reply that EPG is the provider's
   problem, but the sentiment is real: when StbEmu shows a guide for the same
   Stalker portal and TiviMate does not, users blame TiviMate. Mapping is by
   exact `tvg-id`; there is no fuzzy match and no built-in logo or EPG search.
10. **Android-only, and remote-only.** "You cannot install TiViMate on a cell
    phone." "Tivimate doesn't really have an interface that works easy with
    touch." "Native Mac version" and "an app for android phones and tablets
    that can be synced" are explicit asks. Apple users "have to use smarters
    for those... not even close to Tivimate".
11. **Setup is not beginner-friendly.** "It's more of a pia to set up." Fire
    TV requires sideloading via Downloader (code 272483 circulates), a stray
    space after a pasted URL breaks login, and the favourite button "is so far
    down the list".
12. **Smaller but recurring:** channel numbers ignore `tvg-chno` and follow
    playlist order (Channels DVR users script around it); only five retries
    on a dropped stream; 15 s lag before channel change on first launch; a
    blank playlist screen until cache clear; catch-up streams that stop on
    onn boxes; VPN causing 404s; no HDHomeRun or TVHeadend sources.

## Feature wish-list, ranked

Counted across the Jan 2026 wish-list thread plus older threads. Frequency is
posts that raise it, not votes.

| Rank | Wish | Evidence |
| --- | --- | --- |
| 1 | Cloud sync of settings, playlists, favourites, "My List" | 6+ posts; the stated reason one Premium user left |
| 2 | Timeshift / live rewind with real buffer | 4+ posts; "the one glaring feature missing" |
| 3 | Reliable recording on modern Android, continuous buffer recording, record on-demand | 6+ posts |
| 4 | More than five devices, easier device removal | 4 posts |
| 5 | Phone, tablet and Mac apps | 3 posts, plus every Apple thread |
| 6 | EPG and channel search scoped to own groups; EPG refresh only for active channels; faster first load | 3 posts |
| 7 | Trakt integration | 1 post, but ties to sync |
| 8 | Subtitle search (OpenSubtitles) and subtitle offset | 2 posts |
| 9 | Sports guide like iMPlayer's | 1 post |
| 10 | Themes, "eye candy" for the guide | 1 post |
| 11 | Per-channel audio gain | 1 post |
| 12 | Built-in VPN, device rename, logo search, HTSP/TVHeadend, Windows build | 1 post each |

## Competitors and why people switch

- **IPTV Smarters Pro.** The free, cross-platform fallback and the one Apple
  users are pushed to. Verdicts: "B+ grade copy", "almost too simple", "makes
  me want to pay for cable", "tivimate puts smarters to shame". Repeatedly
  pulled from stores. Antenna's main comparison point on iOS.
- **Sparkle TV.** Closest layout to TiviMate; better timeshift and recording;
  also a PVR front end (Tvheadend, HDHomeRun, Plex, Jellyfin). "Many have
  reported that it records better than tivimate." Weaker multi-pane view and
  programme descriptions. Developer "very active on Reddit", which users
  contrast with TiviMate's silence.
- **OTT Navigator.** The tinkerer's choice: decoders, buffers, recording.
  Framed on YouTube as "convenience or customization" versus TiviMate.
- **iMPlayer.** Won one long-time user purely on cross-device sync; praised
  for picture quality and a sports guide; buffers more and UI called busy.
- **MyTVOnline3.** Formuler-only. Users miss its left-hand playlist column and
  built-in VLC.
- **Kodi, Stremio, Emby.** Used alongside TiviMate for VOD.
- **Apple TV field.** Tivimax ("free app is so overloaded with ads"), UHF
  ("feels a bit better than Tivimate. The app's UI needs some work"), IPTVX
  (polished, subscription), iPlayTV (simple, "lags while scrolling down the
  TV guide"), Chillio (Apple-first, multi-view, catch-up), Snappier (paid
  multi-screen). One Channels user's shopping list for a tvOS client:
  "Exposes channel ID's", "Allows interactive building on tvOS", "Uses native
  sound (including AC4)". No Apple app is called the TiviMate of tvOS.

## YouTube and influencer landscape

YouTube coverage of TiviMate is large but low-signal. Of 18 videos resolved,
none is from an independent tech press channel. Groups:

- **TROYPOINT** (site plus Insider forum, with affiliate VPN links) ranks
  TiviMate first in its "Best IPTV players" list every year and runs the
  wish-list thread. Its forum, not its videos, is where the substance is.
- **Install and settings guides:** The Savvy Media Guy ("How to Use TiviMate
  2025", "Best Settings for Smooth Playback & EPG"), MiSTicR4iN ("Not
  Working? Change These 5 Settings"), NINEZEROFIVE, DJ's Tutorials, Triple M,
  huby media. The existence of a genre of "change these settings first"
  videos is itself evidence that defaults confuse people (buffer size,
  decoder, EPG refresh, "No information" in the guide).
- **Comparison videos, 2026:** Calderon Bridger and HMD Tech ("TiviMate vs
  OTT Navigator"), framed as polish versus control. Tech Tested ("Premium vs
  Free"). How To Thomas ("Is This IPTV Player Worth It?").
- **Seller channels in disguise:** "Strong Iptv Premium", "OpticTv", "TivMate"
  (a channel named after the app), plus the "Legit or Scam?" video, which is
  about tivimate.com clone sites rather than the player.

Takeaway: no creator is doing critical review. Sentiment lives in forums,
Trustpilot and Reddit, and the YouTube narrative is uniformly "TiviMate is
the best, buy Premium, here is the Downloader code".

## Implications for Antenna

Things to match, because the community treats them as table stakes:

1. **Guide first.** A fast, remote-navigable EPG with sub-second channel
   switching is the product. Everything else is secondary.
2. **One favourites list across all sources.** Merge playlists, Xtream and
   later Stalker into one guide and one favourites list.
3. **Groups you can hide, lock, rename and reorder**, respecting playlist
   order and `tvg-chno` when present.
4. **Multi-view** on Apple TV and Mac, up to four tiles, audio follows focus.
5. **Multiple EPG sources per playlist** and manual guide assignment per
   channel, because provider EPG quality is the number one support topic.
6. **Simple pricing.** Lifetime or yearly, bought in the App Store, no
   companion app, no device counting. Family Sharing instead of a five-device
   cap removes TiviMate complaints 2 and 8 outright.

Things to do better, where the complaints are loudest and Antenna's platform
helps:

1. **Sync via CloudKit** (already decided). Sources, favourites, groups,
   logos, settings and "My List" appear on every device with no backup
   ritual. This is wish-list item 1 and the stated reason a loyal user left.
2. **Touch and pointer UI** on iPhone, iPad and Mac, not a remote UI scaled
   down. TiviMate "doesn't really have an interface that works easy with
   touch" and Smarters is "not even close".
3. **Timeshift that works.** A real local buffer with pause, rewind and
   fast-forward, plus provider catch-up when available. Users have wanted
   this for three years.
4. **Recording that either works or is honest.** If Antenna records, it must
   not stop at 30 minutes, must produce playable files, and must keep
   recording while the app is in use. If it does not record at launch, say
   so clearly rather than ship a hit-and-miss PVR.
5. **A free tier that is usable**, so the "complete disappointment" review
   never gets written. Decide what is free and disclose premium gating before
   purchase, on the store page.
6. **Visible, regular releases with real changelogs.** "Fixes and
   improvements" twice a year is a repeated grievance.
7. **Search that is scoped to the user's own groups**, and EPG refresh only
   for channels the user actually has visible.
8. **Diagnose, don't blame.** When EPG is empty or a stream 404s under VPN,
   show why (no `tvg-id` match, provider returned 404) instead of leaving the
   user to decide whether to blame the app.

Risks to avoid:

- A separate "companion" purchase or account step. It is the single biggest
  source of one-star reviews.
- Shipping VOD as a flat list with no metadata. Users notice when Smarters
  shows artwork and TiviMate does not.
- Depending on provider catch-up as the only form of timeshift.

## Candidate specs this note feeds

- Guide and channel switching performance.
- Unified favourites and group management across sources.
- Multi-view.
- CloudKit sync of sources, favourites and settings, extending the sync that exists.
- Timeshift buffer and catch-up.
- EPG source management and manual channel-to-guide mapping.
- Pricing, free tier scope and Family Sharing.
- Recording, or an explicit decision not to ship it in v1.

## Sources

Forums and communities

- TROYPOINT Insider, TiviMate Feature Wish-list (Jan 2026):
  <https://troypointinsider.com/t/tivimate-feature-wish-list/153806>
- TROYPOINT Insider, Tivimate Review (Oct 2024):
  <https://troypointinsider.com/t/tivimate-review/120110>
- TROYPOINT Insider, Best IPTV player (2023):
  <https://troypointinsider.com/t/best-iptv-player/84459>
- TROYPOINT Insider, IPTV Player Options (Oct 2023):
  <https://troypointinsider.com/t/iptv-player-options/97956>
- TROYPOINT Insider, TiViMate is NOT free (Mar 2023):
  <https://troypointinsider.com/t/tivimate-is-not-free/87335>
- TROYPOINT Insider, Timeshift vs Catchup (2024-25):
  <https://troypointinsider.com/t/timeshift-vs-catchup/116256>
- TROYPOINT Insider, Tivimate Setup Catchup (2023-25):
  <https://troypointinsider.com/t/tivimate-setup-catchup/98248>
- TROYPOINT Insider, Tivimate Premium Inside Look (2021):
  <https://troypointinsider.com/t/tivimate-video-and-iptv-best-provider-lists/34018>
- Channels community, TiviMate Users - Channel Number Issue (2021):
  <https://community.getchannels.com/t/tivimate-users-channel-number-issue/27441>
- Channels community, Multiview via Channels, page 8 (2024-25):
  <https://community.getchannels.com/t/iptvx-iprotv-and-quadstream-multiview-via-channels/32670?page=8>
- TechKings, Tivimate 5.0 update channel mess (Apr 2024, snippets only):
  <https://www.techkings.org/threads/tivimate-5-0-update-channel-mess.172454/>
- Whirlpool, TiviMate general discussion (snippets only):
  <https://forums.whirlpool.net.au/archive/32461v01>
- Husham forum, VOD threads (snippets only):
  <https://forum.husham.com/threads/vod-movies-not-playing-on-tivimate-premium-live-tv-and-series-are-fine-all-working-on-smarters.4221/>

Reviews and directories

- Trustpilot, tivimate.org: <https://uk.trustpilot.com/review/tivimate.org>
- Google Play, TiviMate IPTV Player (snippets only):
  <https://play.google.com/store/apps/details?id=ar.tvplayer.tv>
- Google Play, TiviMate Companion (snippets only):
  <https://play.google.com/store/apps/details?id=ar.tvplayer.companion>
- AlternativeTo: <https://www.alternativeto.net/software/tivimate/about/>
- APKMirror release list: <https://www.apkmirror.com/apk/armobsoft-fze/tivimate-iptv-player/>
- Uptodown versions: <https://tivimate.en.uptodown.com/android/versions>
- Soft112 changelog: <https://tivimate-iptv-player.soft112.com/>

Guides and comparison blogs (affiliate or vendor; used for facts only)

- TROYPOINT, Best IPTV Players: <https://troypoint.com/the-best-iptv-players-2/>
- Plume, TiviMate: what it does and what it won't fix:
  <https://shop.plume.com/blogs/news/tivimate>
- Sama blog (vendor), Best IPTV players 2026:
  <https://samaplayer.com/blog/best-iptv-players-2026/>
- Tvimate4K (IPTV seller), TiviMate vs Sparkle:
  <https://tvimate4k.com/tivimate-vs-sparkle-player-comparison/>
- FirestickTVStream (affiliate), TiviMate alternatives:
  <https://www.firesticktvstream.com/best-tivimate-alternative/>

YouTube (titles and channels via oEmbed; content not reviewed)

- The Savvy Media Guy, How to Use TiviMate (2025): <https://www.youtube.com/watch?v=mdhVRswXcnc>
- The Savvy Media Guy, Best Settings for Smooth Playback & EPG: <https://www.youtube.com/watch?v=btwiJU0z18Q>
- MiSTicR4iN, TiviMate Not Working? Change These 5 Settings First: <https://www.youtube.com/watch?v=nDU9d7GpyBY>
- Tech Tested, Premium vs Free: <https://www.youtube.com/watch?v=63rM97x6sZY>
- How To Thomas, Is This IPTV Player Worth It?: <https://www.youtube.com/watch?v=z-dySHFaTE0>
- Calderon Bridger, TiviMate vs OTT Navigator Review (2026): <https://www.youtube.com/watch?v=As3ysOI8bxA>
- HMD Tech, TiviMate vs OTT Navigator (2026): <https://www.youtube.com/watch?v=eiW20zpvsyE>
- OpticTv, Tivimate is THE BEST IPTV Player For Firestick in 2026: <https://www.youtube.com/watch?v=VSBnCnI142g>
- Strong Iptv Premium (seller), Premium Features Explained: <https://www.youtube.com/watch?v=cATRWxxosr8>
- A-hAAn, Sparkle IPTV app review: <https://www.youtube.com/watch?v=DN1VBT8I4xk>
