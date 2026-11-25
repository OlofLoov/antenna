## 1. Boards and proposal

- [x] 1.1 Update `TV-Title-Player-Transport`, `TV-Title-Player-Tracks`, `TV-Title-Player-NextButton`, the `TV-ZapBar` boards and `TV-Hints-Live`; add `TV-Title-Player-TracksButton`
- [x] 1.2 Write proposal.md, the delta specs, design.md and tasks.md

## 2. The movie and episode player on Apple TV

- [x] 2.1 Give `Transport.Bar` an accessory and add `Transport.TracksButton` with previews (unfocused, subtitles on, grayed out)
- [x] 2.2 Add `TitlePanelFocus.tracks` and `TitleRemoteMoves`; down and up in `TitleRemoteLayer` follow it, select on the button opens the panel on Subtitles, `held` covers the button's focus
- [x] 2.3 Add `ControlHintScreen.titleTracksButton` and swap the hold for swipe down in the title player's legend
- [x] 2.4 `ControlHintsTests`, `TitleRemoteMovesTests`, and UI tests in `ShelfTVUITests+Tracks`

## 3. Live's info bar

- [x] 3.1 Add `ZapBarText.tracksHint` with its text in every language in `Config/languages`
- [x] 3.2 Draw it as `zapBar.tracksHint` in `ZapBar.Status`, passed from `ZapBarView`, with previews
- [x] 3.3 `ZapBarTextTests` and a `ZapBarUITests` check

## 4. Verify

- [x] 4.1 Every requirement in the delta specs has a test citing `<capability>/<requirement-slug>`
- [x] 4.2 Run `ShelfTVUITests`, `ZapBarUITests`, `TimeshiftTVUITests` and `ControlHintsTVUITests` on a local tvOS simulator; iOS and tvOS builds pass
- [x] 4.3 `/opsx:verify` passes
