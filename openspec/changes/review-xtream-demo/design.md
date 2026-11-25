# Design

## Context

The review source is `Web/review/antuna-review.m3u` with a guide that `scripts/make-review-guide.py` writes when the site publishes (`app-release/app-review-gets-a-test-source-outside-the-app`, `app-release/the-reviewer-guide-covers-the-coming-weeks`). An M3U source gives Movies and Series only when its entries look like films and episodes, and Apple's sample streams do not, so the reviewer sees Live and Guide only.

The site is S3 behind one CloudFront distribution (`Infra/modules/site`). Every behavior runs the `antuna-site-address` viewer-request function (`address.js`), which redirects www and maps folder addresses to `index.html`. The `pages` cache policy leaves the query string out of the cache key. Request logs are off (`hosting/nothing-keeps-a-record-of-requests`).

`XtreamClient` in AntennaCore makes these requests against the server address the user typed, keeping any path the address has:

| Request | Where the app sends it |
|---|---|
| `player_api.php?username&password` | Connect, the account check; the live load, for the time zone; catch-up |
| `player_api.php?...&action=get_live_categories` | Live load |
| `player_api.php?...&action=get_live_streams` | Live load |
| `player_api.php?...&action=get_vod_categories` | Movies load |
| `player_api.php?...&action=get_vod_streams` | Movies load |
| `player_api.php?...&action=get_vod_info&vod_id=<id>` | A movie's page |
| `player_api.php?...&action=get_series_categories` | Series load |
| `player_api.php?...&action=get_series` | Series load |
| `player_api.php?...&action=get_series_info&series_id=<id>` | A series' page |
| `xmltv.php?username&password` | The guide |
| `/live/<user>/<password>/<id>.ts` | A channel, always `.ts` |
| `/movie/<user>/<password>/<id>.<container_extension>` | A movie |
| `/series/<user>/<password>/<id>.<container_extension>` | An episode |

The list actions take an optional `category_id` that the app never sends. The app asks for no short EPG. `/timeshift/` is asked for only for a channel with `tv_archive`, and the demo channels have none. The client logs no address: `XtreamCredentials` and `XtreamClient` describe themselves as the host only, and no log line in Apps or Packages prints a stream address.

## Decisions

### 1. The server address is `https://antuna.app/review`

Options considered:
- The site root, `https://antuna.app` (rejected): `/player_api.php`, `/live/`, `/movie/` and `/series/` would sit beside the site's pages, and a feature page at `/movies` is one typo from `/movie/`.
- A subdomain such as `review.antuna.app` (rejected): a new certificate name, DNS records and either a second distribution or a new alias, for four reviewers a year.
- A path on the site, `https://antuna.app/review` (chosen). The review files already live there. The client keeps the path of the server address on every request (`XtreamClient.url(path:)`), and so do the guide resolver and the catch-up builder, which read `source.url` as typed. Pasting a full panel link strips the path (`CopiedLink`), which is why the notes give the address, username and password as three fields.

### 2. Static files and a CloudFront Function

Options considered:
- Lambda@Edge or a Lambda function URL behind CloudFront (rejected): a server of our own with its own role, logs to turn off, cold starts and cost, to answer about ten fixed JSON bodies.
- S3 redirect objects (`x-amz-website-redirect-location`) for the stream addresses (rejected): they work only on the S3 website endpoint, and the bucket is private behind Origin Access Control. They also cannot read the query string, so `player_api.php?action=` still needs a function.
- The function writing the JSON bodies itself (rejected): the catalogue would live in function code with a 10 KB limit, and AntennaCore could not decode it without running JavaScript.
- Static JSON files in the site bucket and a viewer-request CloudFront Function that picks the file (chosen). The function reads the query string, checks the login and rewrites the address to a file before the cache lookup, so the `pages` policy keys each answer by its file and the query string still stays out of the key.

The function is its own resource, `aws_cloudfront_function.review` named `antuna-review-server`, with code from `Infra/modules/site/review.js`, on a new ordered cache behavior `/review/*` with the `pages` cache policy and the site's response headers policy. It comes before the other behaviors in the list. `address.js` stays as it is: no review address is a folder, and the www host answers the review server the same as the bare domain, which is harmless. A behavior takes one viewer-request function, so the two cannot both run there; the `/review/*` behavior runs only the review function.

### 3. Routing and the login

Demo login: username `review`, password `tunein`. Both are public: they are in the review notes and in `review.js`. They unlock only the demo catalogue. Query values and path segments are percent-decoded before the comparison.

`review.js` handles, for a request URI of:
- `/review/player_api.php`: with the demo login, no `action` gives `/review/xtream/account.json`; a list action gives `/review/xtream/<action>.json`, or `/review/xtream/<action>/<category_id>.json` when `category_id` is digits; `get_vod_info` with a digits `vod_id` gives `/review/xtream/get_vod_info/<id>.json`; `get_series_info` with a digits `series_id` gives `/review/xtream/get_series_info/<id>.json`; any other action answers 404. With any other login it gives `/review/xtream/denied.json`, which is `{"user_info":{"auth":0}}` with status 200, as panels answer.
- `/review/xmltv.php`: with the demo login, `/review/guide.xml`, the guide the playlist already uses; otherwise 403.
- `/review/live/<user>/<password>/<id>.<ext>`, `/review/movie/...`, `/review/series/...`: with the demo login and a known id, 302 to that id's Apple sample stream; an unknown id answers 404; any other login answers 403.
- `/review/xtream/...`: 404, so the answer files are reachable only through the login.
- Anything else (`antuna-review.m3u`, `guide.xml`, `art/*.jpg`): passes through unchanged.

The function writes no log line.

### 4. Streams redirect to Apple's sample streams

Options considered:
- A small HLS playlist of our own at each stream address (rejected): Apple's master playlists list several variants with relative addresses; ours would have to copy them and follow every change Apple makes.
- A 302 to the Apple master playlist (chosen). Checked on macOS 27.2: `AVPlayer` given `http://127.0.0.1/live/u/p/1.ts`, with the HLS MIME type override the app sets for HLS at a raw-looking address, followed the 302 to `bipbop_16x9_variant.m3u8` and played, and asked the local server for nothing else, so it resolved the variants against Apple's address. The same held for a `.m3u8` address.

The engines take it this way:
- A channel is `/live/.../<id>.ts`, so `EngineRouter` sends it to the demuxer. Its HTTP reader follows the redirect (`playback-engine`, "A film behind a redirect"), sees `#EXTM3U`, and hands the same address back to the system player (`EngineHandoff.toSystemPlayer`). `AVPlayerEngine` probes again, sees HLS at a non-`.m3u8` address, and opens it with the HLS MIME type override.
- Movies and episodes list `container_extension` `m3u8`, so their addresses end in `.m3u8` and go straight to the system player. HLS stays on AVPlayer.

| Stream id | Kind | Apple sample (under `https://devstreaming-cdn.apple.com/videos/streaming/examples/`) |
|---|---|---|
| 1 | live, Basic 4:3 | `bipbop_4x3/bipbop_4x3_variant.m3u8` |
| 2 | live, Basic 16:9 | `bipbop_16x9/bipbop_16x9_variant.m3u8` |
| 3 | live, Advanced fMP4 | `img_bipbop_adv_example_fmp4/master.m3u8` |
| 4 | live, Advanced HEVC | `bipbop_adv_example_hevc/master.m3u8` |
| 101 | movie, The Long Harbor | `img_bipbop_adv_example_fmp4/master.m3u8` |
| 102 | movie, Salt Road | `bipbop_16x9/bipbop_16x9_variant.m3u8` |
| 103 | movie, Paper Cities | `img_bipbop_adv_example_ts/master.m3u8` |
| 104 | movie, Quiet Engines | `bipbop_adv_example_hevc/master.m3u8` |
| 105 | movie, Glass Orchard | `bipbop_4x3/bipbop_4x3_variant.m3u8` |
| 2011, 2012, 2013 | episodes 1 to 3 of Harbor Watch (series 201) | `img_bipbop_adv_example_fmp4/master.m3u8`, `img_bipbop_adv_example_ts/master.m3u8`, `bipbop_16x9/bipbop_16x9_variant.m3u8` |

The live channels are the four the playlist lists. The movies and the series reuse names the store screenshots show, so a reviewer comparing the screenshots with the app finds the same titles. All are made up. The advanced examples run ten minutes and the basic ones thirty, which the details give as each title's length. Dolby Vision and Atmos (`adv_dv_atmos`) are left out: the simulator a reviewer may use cannot decode them.

### 5. The catalogue is generated when the site publishes

Options considered:
- Committed JSON under `Web/review/xtream/` (rejected): the files hold the site's address in every poster link, so a local copy could not show its own art, and the guide already sets the pattern of writing review files at publish.
- `scripts/make-review-xtream.py <folder> <base address>` writes the files, and `scripts/publish-web.sh` runs it into `<out>/review/xtream` with `https://antuna.app/review`, or `$REVIEW_BASE_URL` when set (chosen). The same arguments give the same files. The catalogue (names, plots, years, genres, categories, ids, extensions) lives in the script. The stream table lives in `review.js`; the Node test ties the two together by asking the function for every stream the files list.

Categories: live `1` Apple samples; movies `11` Drama, `12` Adventure; series `21` Crime. Each list action also gets one file per category for `category_id`.

Files written: `account.json`, `denied.json`, `get_live_categories.json`, `get_live_streams.json`, `get_vod_categories.json`, `get_vod_streams.json`, `get_series_categories.json`, `get_series.json`, `get_vod_info/<id>.json`, `get_series_info/<id>.json`, and `<list action>/<category id>.json`. The account says status Active, auth 1, no expiry, one connection and time zone UTC.

### 6. The art

`scripts/make-store-art.py` gets a second table and writes `Web/review/art/<kind>-<id>-<poster|backdrop>.jpg` with the same formulas, palettes matching the store screenshot titles of the same name. The JPEGs are committed, as the store art is, so publishing needs no ffmpeg. The details list the backdrop, and an episode lists the series backdrop as its picture.

### 7. Tests

- AntennaCore `ReviewServerTests` (macOS, runs `publish-web.sh` into a temporary folder): decodes every published file with the client's own decoders (`decodeLossyList`, `decodeVODList`, `decodeVODInfo`, `decodeSeriesInfo`, `XtreamAccountInfo`); checks the counts, that every poster and backdrop is under the base address and its file is published, that the files name no other host, that every stream address the client builds for them is under the server address, that `denied.json` makes the client throw `unauthorized`, and that every `https` address in `review.js` is under Apple's sample path. The existing `reviewSourceNotInApp` test covers the app side, since the server address is under `antuna.app/review`.
- Node, `Infra/modules/site/tests/review.test.mjs` on `node --test` with no packages: loads `review.js` in a `vm` context as CloudFront would, runs the generator into a temporary folder, and checks each row of the routing in decision 3, that every stream id the files list redirects to Apple's sample path, and that every rewritten address names a file the generator wrote.
- `terraform test` in `Infra/antuna/tests/site.tftest.hcl`: the `/review/*` behavior exists, runs the review function, uses the `pages` cache policy and keeps HTTPS; the function's runtime is `cloudfront-js-2.0` and its code is `review.js`; every other behavior still runs the address function.
- The Infra workflow's check job runs the Node test, and the workflow runs for changes to `Web/review/**` and `scripts/make-review-xtream.py`.

### 8. The review notes

Options considered:
- Replace the playlist with the demo server (rejected): the playlist has passed review before and needs no login, and the files cost nothing to keep.
- Keep both and lead with the demo server (chosen). The notes give the server address, username and password, the steps for Live, Guide, Movies and Series, the Apple TV path, and the playlist as a fallback in one line. The curl checks at the top of the file test the account answer, a movie's details and one redirect.

## Owner steps

1. Merge the implementation PR. `Infra/antuna` changes, so the Infra workflow's apply job applies on main when the AWS variables are set; otherwise the owner runs `terraform -chdir=Infra/antuna apply` once the domain is registered (`add-aws-hosting` task 1.1). The plan adds `aws_cloudfront_function.review` and changes `aws_cloudfront_distribution.site` in place.
2. The site job on the same push uploads `review/xtream/` and `review/art/`.
3. Run the curl checks at the top of `docs/release/app-review-notes.md` and paste the notes into App Store Connect for the iOS and the tvOS app.

## Platforms

No app change. The notes cover iPhone, iPad, Mac and Apple TV.

## Boards

No screen changes, so no board.

## Architecture

The container diagram's CDN box adds the review server function.
