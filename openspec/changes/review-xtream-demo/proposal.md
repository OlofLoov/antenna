# Proposal

## Why

App Review can see only Live and Guide. The review source is an M3U playlist of four of Apple's sample streams, and Movies and Series appear only for a source that has them, which in practice means an Xtream Codes login. The store screenshots show the Movies tab, a movie's page and a movie playing, so a reviewer who cannot reach them has grounds to reject the build under Guideline 2.3 (screenshots that do not match the app).

After this change a reviewer adds one Xtream source with a server address, a username and a password from the review notes, on iPhone, iPad, Mac or Apple TV. Live and Guide show the same four test channels as today, Movies lists five made-up movies and Series one made-up series with three episodes. Every movie and episode plays one of Apple's public sample streams. The owner approved hosting this small demo server on antuna.app with demo credentials printed in the notes.

## What Changes

- antuna.app answers the Xtream Codes requests the app makes under `/review`: the account, the live, movie and series categories and lists, a movie's and a series' details, the guide, and the live, movie and episode stream addresses.
- The answers are static JSON files written by a script when the site publishes, next to the review guide. Posters and backdrops are abstract art drawn by the script that draws the store screenshot art, served from antuna.app.
- A CloudFront Function on `/review/*` checks the demo username and password, maps each request to its file, and redirects a stream address to its Apple sample stream. Any other login gets the answer a panel gives a wrong password.
- The review notes give the server address, username and password and the steps to see Live, Guide, Movies and Series, on iPhone and on Apple TV. The M3U playlist stays published as a fallback.
- Tests: AntennaCore decodes the published files with the app's own Xtream client and checks every address in them; a Node test runs the function against sample requests; `terraform test` checks the new behavior and function.

Out of scope:
- Any change to the app. The app never names the review server.
- Catch-up, timeshift and short EPG on the demo server; its channels have no archive.
- Real titles, real people, real providers or any stream outside Apple's sample streams.
- A server of our own (Lambda, a VM): the demo server is static files and one function.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `app-release`: two new requirements, "App Review can open Movies and Series" and "The review server answers only the demo login".

## Impact

- Infra: `Infra/modules/site` gets a second CloudFront Function and a `/review/*` cache behavior. The owner applies it with the next `Infra/antuna` apply; it changes the distribution in place.
- Site: `scripts/publish-web.sh` writes `review/xtream/` and copies `Web/review/art/`. `scripts/make-store-art.py` also draws the review art.
- CI: the Infra workflow runs the function's Node test, and runs on changes to the review generator.
- Docs: `docs/release/app-review-notes.md`, the container diagram's CDN box.
- Depends on `add-aws-hosting` (the distribution, the site bucket and the publish step), which is in place in code. The server answers nothing until the owner registers antuna.app and applies, as for the rest of the site (`add-aws-hosting` task 1.1).
