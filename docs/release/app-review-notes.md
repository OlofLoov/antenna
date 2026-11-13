# App Review notes

Paste the text under "Notes for the reviewer" into App Store Connect, in the
App Review Information section of each version, for both the iOS and the
tvOS app. Leave the sign-in fields empty: Antenna has no account of its own.

Before each submission, check that the four streams and the guide answer:

```sh
curl -sI https://antenna.code-crave.se/review/antenna-review.m3u | head -1
curl -sI https://antenna.code-crave.se/review/guide.xml | head -1
curl -s https://antenna.code-crave.se/review/antenna-review.m3u | grep '^https' | xargs -n1 curl -sI -o /dev/null -w '%{http_code} %{url}\n'
```

The playlist is `Web/review/antenna-review.m3u`. The guide is written by
`scripts/make-review-guide.py` each time the site publishes, which happens
after every release, so it covers at least four weeks from the release day.
The app never names either address; only these notes do.

## Notes for the reviewer

Antenna is a video player for IPTV sources the user already has: an M3U
playlist link, an Xtream Codes login, or a Stalker, Jellyfin or Channels DVR
server. It ships no channels, playlists, provider addresses or other content,
and it does not point users to any provider (Guideline 5.2.3). The App Store
description says a purchase is required.

To try it, use this test playlist. It lists four of Apple's public HLS sample
streams from developer.apple.com/streaming/examples, with a program guide we
made for them:

https://antenna.code-crave.se/review/antenna-review.m3u

1. Open Antenna. It shows the paywall first, because the app is a paid
   unlock with no free tier.
2. Buy either the lifetime unlock or the yearly subscription with your
   sandbox account. Restore purchase on the same screen also works for an
   account that bought before.
3. Tap Add a source, choose M3U playlist, and paste the address above as the
   playlist URL. You do not need to enter a guide address; the playlist
   names its own.
4. Live lists four channels: Basic 4:3, Basic 16:9, Advanced fMP4 and
   Advanced HEVC. Each one plays, and the Guide shows a program on every
   channel now and for the next few weeks.

On Apple TV the steps are the same with the Siri Remote. You can type the
address on the TV, or open Antenna on an iPhone signed in to the same
iCloud account, add the source there and it appears on the TV.

The app sends nothing to us. It connects only to the sources the user adds,
to the user's private iCloud database for sync, and to Apple for purchases.
