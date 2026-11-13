# Tasks

## 1. Spec and boards

- [x] 1.1 Remove "Favorites list is read-only" and add the menu, swipe and full-screen requirements to `favorites`; drop the MODIFIED block for it from `add-tv-channel-overlay`
- [x] 1.2 Note the menu and swipe on `iPhone`, `iPad`, `iPhone-Guide` and `iPad-Guide`, and draw the star on `iPhone-FullScreen`

## 2. Components

- [x] 2.1 Add `Browse.FavoriteMenuButton` and `Browse.PlayerFavoriteButton` with previews for both states

## 3. Live and Guide

- [x] 3.1 Replace the Mac multi-view row menu with one row menu that lists the favorite item first, and add the leading swipe on iPhone and iPad
- [x] 3.2 Add the menu and a VoiceOver action to the Guide's channel cells on iPhone, iPad and Mac
- [x] 3.3 Show the star in the player controls while full screen

## 4. Tests

- [x] 4.1 UI tests on iPhone for the menu, the swipe, the Guide menu and the full-screen star, each citing its requirement

## 5. Verify

- [x] 5.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [x] 5.2 `/opsx:verify` passes
