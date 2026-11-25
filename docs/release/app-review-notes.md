# App Review notes

Paste the text under "Notes for the reviewer" into App Store Connect, in the
App Review Information section of each version, for both the iOS and the
tvOS app. Leave the sign-in fields empty: Antuna has no account of its own.

Before each submission, check that the demo server, the playlist, the guide
and the streams answer:

```sh
api='https://antuna.app/review/player_api.php?username=review&password=tunein'
curl -s "$api" | grep -q '"auth": 1' && echo 'account ok'
curl -s "$api&action=get_vod_info&vod_id=101" | grep -q '"m3u8"' && echo 'movie details ok'
curl -s 'https://antuna.app/review/xmltv.php?username=review&password=tunein' | grep -q '<programme' && echo 'guide ok'
curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' https://antuna.app/review/movie/review/tunein/101.m3u8
curl -s -o /dev/null -w '%{http_code}\n' 'https://antuna.app/review/player_api.php?username=review&password=wrong'
curl -sI https://antuna.app/review/antuna-review.m3u | head -1
curl -s https://antuna.app/review/antuna-review.m3u | grep '^https' | xargs -n1 curl -sI -o /dev/null -w '%{http_code} %{url}\n'
```

The movie line prints `302` and an address on devstreaming-cdn.apple.com.
The wrong password prints `200`; its body is `{"user_info": {"auth": 0}}`.

The demo server's answers are written by `scripts/make-review-xtream.py` and
its art by `scripts/make-store-art.py`; `Infra/modules/site/review.js`
checks the login and sends each stream to Apple's sample streams. The
playlist is `Web/review/antuna-review.m3u`. The guide is written by
`scripts/make-review-guide.py` each time the site publishes, which happens
after every release, so it covers at least four weeks from the release day.
The app never names these addresses or the login; only these notes do.

## Notes for the reviewer

Antuna is a video player for IPTV sources the user already has: an M3U
playlist link, an Xtream Codes login, or a Stalker, Jellyfin or Channels DVR
server. It ships no channels, playlists, provider addresses or other content,
and it does not point users to any provider (Guideline 5.2.3). The App Store
description says a purchase is required.

To try it, use our demo Xtream Codes server. It lists four live channels with
a program guide, five movies and one series, all with made-up names and
artwork we drew. Every channel, movie and episode plays one of Apple's public
HLS sample streams from developer.apple.com/streaming/examples.

Server: https://antuna.app/review
Username: review
Password: tunein

1. Open Antuna. It shows the paywall first, because the app is a paid
   unlock with no free tier.
2. Buy either the lifetime unlock or the yearly subscription with your
   sandbox account. Restore purchase on the same screen also works for an
   account that bought before.
3. Tap Add a source and choose Xtream login. Enter the server, username and
   password above, each in its own field, and tap Connect.
4. Live lists four channels: Basic 4:3, Basic 16:9, Advanced fMP4 and
   Advanced HEVC. Each one plays, and the Guide shows a program on every
   channel now and for the next few weeks.
5. Movies lists The Long Harbor, Salt Road, Paper Cities, Quiet Engines and
   Glass Orchard, each with a poster, a description and a length. Each one
   plays.
6. Series lists Harbor Watch. Open it and pick any of its three episodes.

On Apple TV the steps are the same with the Siri Remote: choose Xtream login
and type the three fields. Or open Antuna on an iPhone signed in to the same
iCloud account, add the source there, and it appears on the TV.

If the demo server cannot be reached, the same four live channels and guide
are in a playlist: choose M3U playlist and paste
https://antuna.app/review/antuna-review.m3u as the playlist URL.

The app sends nothing to us. It connects only to the sources the user adds,
to the user's private iCloud database for sync, and to Apple for purchases.
