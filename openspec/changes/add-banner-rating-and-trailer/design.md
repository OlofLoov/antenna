# Design

## Context

- `ShelfBannerHost` builds the banner from `ShelfModel.details`, a `ShelfDetails` per title made from the info call (`ShelfDetails(movie:)`, `ShelfDetails(series:)`). `ShelfDetails` has year, duration, seasons, plot, age rating and backdrop. The info call's `rating` and `trailerURL` are dropped there.
- `BannerText.facts` is the year and the length or seasons. `ShelfBanner.Facts` draws them between dots, then the badges.
- The title page writes the rating with `TitleMetadata.rating(_:)`: "★ 7.4", one decimal, nil for 0 or less or not finite. It uses the info call's rating, else the list row's (`ShelfTitle.rating`).
- `TitleScreen.trailer(_:)` decides the Trailer action. On iPhone, iPad and Mac it calls `openURL`, which hands the link to the browser or the YouTube app. On Apple TV it returns nil unless `TrailerLink.playsInApp` (an http or https link ending in m3u8, mp4, m4v or mov, never YouTube), and then calls `ShelfPlayback.playTrailer`, which plays it full screen, saves no place and closes at its end.
- `Loose.trailer` turns an 11-character YouTube id into `https://www.youtube.com/watch?v=<id>`. Panels that send a trailer usually send `youtube_trailer` as such an id, so on Apple TV few titles have a Trailer button today.
- Xtream movie rows read `rating`. Many panels send both `rating` (0 to 10) and `rating_5based` (the same halved), as the fixture `vod_streams.json` does. Series rows read no rating.

## Decisions

### How the rating is written

As on the title page: "★ 7.4", a star glyph then the number out of ten with one decimal, as one more fact after the length or seasons. `BannerText` calls `TitleMetadata.rating(_:)`, so both screens share one formatter.

Options considered:
- Five stars, filled to the rating (rejected). Halving a 7.4 to 3.7 stars throws away precision, the stars read as an editorial verdict the app does not make, and the title page already says "★ 7.4".
- "7.4/10" (rejected). Clearer about the scale but longer on the iPhone line, and different from the title page.
- A star and the number (chosen). Same as the title page, short enough for the iPhone facts line.

The spoken form is "rated 7.4 out of 10". `ShelfBanner.Facts` gives the rating fact its own accessibility label, and `TitleMetadata` gets a `spokenRating(_:)` beside `rating(_:)` so the title page can use the same label.

### Which scale

Everything is held on a ten-point scale. In the Xtream wire types, `rating` wins when it is above 0 and at most 10. Without it, `rating_5based` above 0 and at most 5 is doubled. Anything above its scale is dropped, since a panel that sends 74 for 7.4 or 7 on the five-point field is sending something the app cannot interpret safely. Series rows read both fields the same way, so a series banner has its rating before the info call answers.

M3U playlists carry no rating, so their titles show none.

### Where the rating comes from on the banner

`BannerText.init(_:details:)` uses `details?.rating ?? title.rating`, the title page's order. The row's rating shows as soon as the banner shows the title; the info call's replaces it if it differs. The facts line fades with the rest of the copy, as `smooth-the-movies-banner` set up, so a late year and length join the rating in the same 0.6 s fade.

### Next to the TMDB score

`add-title-metadata` puts a score row ("TMDB 74%") on the title page and takes the provider's star out of the page's details line once scores show, so the page never shows two numbers for the same thing. Its matching runs only when a page opens, and it rules out scores on posters in rows.

The banner keeps the provider's star whether or not a TMDB match is cached. Showing TMDB on the banner only for titles the viewer has opened before would make the banner inconsistent from one title to the next, and matching every banner title would add the lookup calls that change avoided. Panels often fill `rating` from TMDB's vote average, in which case the two numbers agree. If the owner wants one source on screen at a time, the rule in `add-title-metadata` can extend to the banner later: a cached TMDB score replaces the star.

### Where the Trailer button sits

Between More info and My list, on every platform, with the `play.rectangle` glyph the title page uses.

- Apple TV: "Trailer" with the glyph, the title page's `TrailerButton` style at the banner's 26 pt button size. My list stays the last button, so moving right from My list still pages the banner and moving left from Play still pages back (`movies-and-series-browsing/new-titles-up-front`).
- iPad and Mac: "Trailer" with the glyph, 44 pt high, between More info and My list.
- iPhone: the glyph alone in a 44 by 44 pt button like My list, with the spoken label "Trailer". Play takes the remaining width. With Play, Info, Trailer and My list in the 358 pt between the margins, Play keeps about 180 pt.

The title page puts Trailer after My list. On the banner My list has to stay at the right edge for paging on Apple TV, and putting Trailer in the same place on every banner keeps the platforms alike, so the banner order differs from the page's.

Options considered:
- Trailer after My list, as on the page (rejected). Paging right would move from My list to Trailer depending on the title, and the viewer's right swipe would sometimes page and sometimes move to a button.
- Trailer in place of More info when there is a trailer (rejected). More info is the way to the page; hiding it for some titles is worse than one more button.
- Between More info and My list (chosen).

Focus on Apple TV: the banner pages only from Play or My list, and while focus is in the buttons it does not page by itself. So focus is never on Trailer when the title changes. When the info call answers late and Trailer appears, My list keeps its identity in the `HStack` and keeps the highlight.

### How the trailer opens

The banner follows `title-detail-and-episode-picker/trailer` exactly. `BannerContext.Actions` gains `trailer: (() -> Void)?`, and `ShelfBannerHost` builds it with the same rule as `TitleScreen.trailer(_:)`, moved to a shared `ShelfActions.trailer(_:of:)` so the two cannot drift:

- iPhone, iPad and Mac: `openURL`. A YouTube link opens in the YouTube app when it is installed, else in Safari.
- Apple TV: only for `TrailerLink.playsInApp` links, through `ShelfPlayback.playTrailer`. Closing or the trailer's end goes back to the banner. `ShelfTVBannerButtons` already puts focus back on More info after a page opened from the banner; the same `returning` path puts it on Trailer after a trailer.

Apple TV has no web browser, and the YouTube page link cannot be played by AVPlayer. What it would take, not built here:
- Opening the YouTube app on Apple TV with `openURL`. Whether the tvOS YouTube app accepts a `youtube.com/watch` link handed over from another app has not been checked on a device. If it does, the button could show when the YouTube app is installed, with "Opens in YouTube" as its hint.
- A QR code for the phone to scan. It works without the YouTube app but turns a lean-back action into a phone task.
- Resolving the YouTube page to a video stream. YouTube's terms of service forbid it.

### Provider load

Unchanged. The rating and trailer link come from the info call the banner already makes for the shown title and the next one, once per title per launch, and from the list rows already loaded.

## Boards

New, under `openspec/specs/design-system/boards/`:
- `TV-Movies-Trailer`: the Apple TV banner for a rated title with a playable trailer, Play highlighted. Trailer focused is the same lifted white card as More info focused.
- `iPad-Movies-Trailer`: the iPad and Mac banner card with the rating and Trailer.
- `iPhone-Movies-Trailer`: the iPhone banner with the rating and the Trailer glyph button.

Follows: `TV-Movies`, `iPad-Movies`, `iPhone-Movies`. A title without a rating or trailer looks as those boards do today.

Not drawn: the Series banner (the same with seasons in place of the length), and the trailer playing, which is the movie player on `TV-Title-Player-Transport` with the trailer's title.

Design-system requirements followed: "Focus is the lifted white card" (Trailer is a secondary banner button until focused), "One accent color" (the star is the text color, not a second accent), "Targets are large enough to hit" (44 pt on iPhone, iPad and Mac), "Text stays above the platform caption floor", "Accessibility identifiers follow the board".

## Identifiers

- `movies.hero.trailer`, `series.hero.trailer`: the banner's Trailer button.
- `movies.hero.rating`: the rating fact inside the facts line, for UI tests.

## Open questions

1. **The YouTube app on Apple TV.** Recommend checking on a device whether `openURL` with a `youtube.com/watch` link opens the tvOS YouTube app. If it does, a follow-up change shows Trailer there when the app is installed, on the banner and the title page together.
2. **Provider star or TMDB score on the banner once `add-title-metadata` ships?** Recommend the provider star on the banner and the TMDB score on the page, as written above, and revisit if the two numbers confuse anyone.
3. **"★ 7.4" or "7.4/10"?** Recommend keeping "★ 7.4" to match the title page. Changing it means changing both.
