# Tasks

## 1. Core

- [x] 1.1 `UpNext` constants and `next(after:in:)` in the season picker's order, with no wrap and no step from a season into specials
- [x] 1.2 `UpNextTimer`: the button from 30 seconds before the end, the card from 15, the countdown, the end, Cancel, moving back out, short and unknown lengths
- [x] 1.3 `UpNextRun` and the question after three episodes without input
- [x] 1.4 `UpNextText` and `AutoplaySetting`
- [x] 1.5 `ControlHintScreen` cases for the button, the card and the question, and `RemoteControl.swipeDown`
- [x] 1.6 Tests citing `up-next/*` and `control-hints/each-screen-lists-its-own-actions`

## 2. App

- [x] 2.1 `ShelfPlayback`: find the next episode from the loaded list, drive the timer, save the finished episode as watched, play the next in the same player, close an episode that ends with nothing next
- [x] 2.2 `TitleTransport.Dependencies.input` reports every input to the run
- [x] 2.3 `NextEpisode.Button` and `NextEpisode.Card` with previews on each platform
- [x] 2.4 `ShelfPlayerView`: the button and card on Apple TV (focus, swipe down, Menu, play/pause) and on iPhone, iPad and Mac (placement over the controls, Return and Escape)
- [x] 2.5 `TitleScreen` reveals the episode that played last
- [x] 2.6 `AutoplayRow` in Settings on every platform
- [x] 2.7 Scripted engine `-ui-testing-near-end`, unit tests for `ShelfPlayback` up next
- [x] 2.8 UI tests in `ShelfPlayerUITests` and `ShelfTVUITests`

## 3. Verify

- [x] 3.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 3.2 `/opsx:verify` passes
