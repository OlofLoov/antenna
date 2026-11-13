# Tasks

## 1. Spec and boards

- [x] 1.1 Add "Favorites on Apple TV" and "Hold select to favorite on Apple TV" to `favorites`, name Apple TV in sync, remove "Apple TV shows no favorites" and drop that removal from `add-tv-channel-overlay`
- [x] 1.2 Note the held-select menu on `Main`, `Main-Favorites` and `TV-Guide`, and change the empty line on `Main-FavoritesEmpty`

## 2. Overlay

- [x] 2.1 Add the held-select menu and the VoiceOver action to overlay channel rows, calling the shell's favorite toggle
- [x] 2.2 Change the empty Favorites line to "No favorites yet. Hold select on a channel to add it." in the model, preview and tests

## 3. Guide

- [x] 3.1 Give the Apple TV Guide a favorite toggle from the shell, add the menu and the VoiceOver action to the grid holder, and move focus to the day chips when the shown group empties

## 4. Tests

- [x] 4.1 tvOS unit tests for Favorites order, profile and locked channels in the overlay catalogue, citing `favorites/favorites-on-apple-tv`
- [x] 4.2 tvOS UI tests for the held-select menu in the overlay and the Guide, citing `favorites/hold-select-to-favorite-on-apple-tv`, run on a local Apple TV simulator

## 5. Verify

- [x] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 5.2 `/opsx:verify` passes
