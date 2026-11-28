# Tasks

## 1. Core

- [ ] 1.1 `PlayRequest.lifetime` of 60 s for every item; drop `liveLifetime`, `titleLifetime` and the offer's facts line
- [ ] 1.2 `PlayCountdown` with `secondsLeft(at:)` and `isDue(at:)`
- [ ] 1.3 `PlaySendFailure` and `PlaySendRetry.delay(after:attempt:)`
- [ ] 1.4 `cancel` frame and `canceled` answer in `PlayMessage`
- [ ] 1.5 `PlayOnText`: starts in, sent within a minute, canceled, already has it, the menu row
- [ ] 1.6 Tests for each, in AntennaCore

## 2. Apple TV

- [ ] 2.1 `PlayRequestInbox.countdown` replaces `offered`, with `tick`, `playNow`, `cancelCountdown` and `cancel(_:)`
- [ ] 2.2 `FromDeviceCountdown` and `ShellPlayCountdown`; `FromDeviceOffer` and `ShellPlayOffer` go
- [ ] 2.3 `PlayOnListener` answers `cancel`, rebinds with endpoint reuse; `PlayOnReceiver` listens first and reads devices on each pickup
- [ ] 2.4 Board `TV-FromIPhone-Countdown`; the offer boards go
- [ ] 2.5 Inbox and receiver tests, TV UI tests and the journey snapshot

## 3. iPhone, iPad and Mac

- [ ] 3.1 `PlayDestination`: browse first, 3 s discovery, the retry loop, separate reach and answer limits, fallback logging
- [ ] 3.2 Cancel: `pending`, `cancel()`, `PlayOnSending.cancel`, `PlayOnConnection.cancel`
- [ ] 3.3 `PlayOnToast` with Cancel for ten seconds; board `iPhone-PlayOn-Messages`
- [ ] 3.4 Destination and queue tests, Play on UI tests

## 4. Verify

- [ ] 4.1 Strings synced and translated in every language in `Config/languages`
- [ ] 4.2 Each requirement has a test citing `play-on-apple-tv/<requirement-slug>`
- [ ] 4.3 `/opsx:verify` passes
