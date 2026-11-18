# Design

## Boards

- `TV-Hints-Live`, `TV-Hints-Movies`: the `hints.legend` note now says when the legend always shows. Its look and corner are unchanged.
- `TV-Title-Player-NextButton`, `iPhone-Title-Player-UpNext`, `iPad-Title-Player-UpNext`: the button's note says 60 seconds. Nothing is redrawn.
- Design-system rules as before: the legend sits inside the TV safe area and never takes focus.

## Decisions

### What the section switch shows

Options: the section's own list, or a short "how to use the app" summary shared by all three sections.

Chosen: the section's own list. A summary would repeat the tab bar's lines and say nothing about holding select for My list on Movies or for Favorites on Live, which is what the legend is for. It also keeps one legend per screen, so VoiceOver and the UI tests read the same text however the viewer arrived.

### What counts as a section

Live, Movies and Series, as the owner named them. The guide is part of Live, so picking a channel in the guide does not bring the Live legend back on every pick. The tab bar, title pages, the movie and episode player, the Up next card and Settings belong to no section: Movies, a title page, the player and back to Movies is no switch, and Movies, Settings, Series is one. Search has no legend.

The first arrival in a section after launch counts as a switch. That changes nothing in practice, since a first arrival always shows.

### First playback

The first arrival at the live picture and at the title player after a launch is the first time something plays. A place's first arrival always shows, and a section switch never uses up the count of a place not reached yet, so no extra rule is needed in code. A test proves it after three rounds of rows and title pages. Movies and episodes share one player place: the first episode after a movie shows only while the player has shown fewer than three times.

### Where it lives

`ControlHintSchedule.arrive(at:)` in AntennaCore keeps the last section and lets a switch through past the per-place limit. `ControlHintScreen.section` names each screen's section. `ControlHintsHost` is unchanged; it already asks the schedule on each arrival.

### Up next timing

`UpNext.buttonLead` becomes 60 seconds; `cardLead` stays 15. `-ui-testing-near-end` starts titles 25 seconds before the end, still inside the button window and 10 seconds before the card, so the UI tests keep their steps. The archived `add-autoplay-next-episode` change still says 30 seconds; it is history.

## Platforms

The legend is Apple TV only, as before. The button timing reaches every platform through the shared timer.
