## 1. Proposal

- [x] 1.1 Write proposal.md, the delta specs, design.md and tasks.md

## 2. AntennaCore

- [x] 2.1 Decode `allowed_output_formats` on `XtreamAccountInfo.UserInfo`; `XtreamLiveFormat` (HLS offer, HLS link of a channel) and `XtreamHLSOffers`
- [x] 2.2 `liveLoad` keeps `.ts` links and returns `offersHLS`
- [x] 2.3 `PlaybackOptions.fallback` and `StreamFallback`; `RoutedEngine` opens the fallback on a failure before the first play, keeps the failure from the screen, names it in `fallbacks()` and exposes `loadedExtension`
- [x] 2.4 `AirPlayHLS`, `HLSFailureMemory` and `AirPlayHandoff`
- [x] 2.5 `FixtureServer.alias` for a panel's live paths
- [x] 2.6 `XtreamHLSOfferTests`, `AirPlayHLSTests`, `AirPlayHandoffTests`, `RoutedFallbackTests` and a `FixtureServerTests` case

## 3. Apps

- [x] 3.1 `HLSFailureStore` under `player.hlsFailures`; `SourceLoader` keeps each Xtream source's HLS offer
- [x] 3.2 `StreamResolver.load(toAirPlay:)`; `LiveModel` tunes with `PlayerModel.tunesForAirPlay`
- [x] 3.3 `PlayerModel+AirPlay`: the handoff fed by `AirPlayRouteWatch`, the list's delegate, external playback and the fallbacks; the notice through `TimeshiftModel.say`
- [x] 3.4 `AirPlayPicker` with the list's delegate and the Mac's player, `AirPlayRefusedButton`, `AVPlayerEngine.prepareForAirPlay`; `LivePicture` shows the button on every live channel and drops the menu's AirPlay line
- [x] 3.5 `UITESTING_XTREAM_HLS` in `UITestingLive` with a scripted route and external playback; the probe's route switch and list count
- [x] 3.6 `RoutedPlaybackTests` against the fixture server with the app's engines, `XtreamZapBenchmarkTests`, `XtreamHLSUITests`, and `PlayerExtrasUITests` for the refused press

## 4. Verify

- [x] 4.1 Every requirement in the delta specs has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 Run `XtreamHLSUITests`, `PlayerExtrasUITests`, `LiveUITests`, `LivePlayerUITests` and `PlayerErrorUITests` on a local iPhone simulator; iOS, tvOS and macOS builds pass
- [x] 4.3 `/opsx:verify` passes
