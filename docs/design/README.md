# Design reference

The visual and layout source of truth for Antenna's UI. Specs cite boards and
design rules from here; the `spec-reviewer` checks that they do; the
`impl-reviewer` checks the implementation against the cited rules and board.

- Canvas (editable, private to the owner):
  https://claude.ai/artifact/T98LnnsYB3oZfBrQQSsFJm
- Board sources: [`boards/`](boards/). One `.dc.html` per screen, exported
  from the canvas. The inline `style` attributes are the measurements:
  sizes, spacing, colours and type are read from there, not guessed.
- Reference apps: TiviMate for live TV layout and remote flow, Netflix and
  Disney+ for content-first movies and series. Patterns, never assets.

Update the boards and this file in the same PR as any intentional visual
change. A screen that has no board gets one before its spec is written.

## 1. Look

| Token | Value | Use |
|-------|-------|-----|
| Ground | `#0B0E13` | App background on every platform |
| Sidebar / tab bar | `#11151C` | iPad and Mac sidebar, iPhone tab bar |
| Overlay scrim | `rgba(8,10,14,0.88)` | tvOS panels over live video |
| Surface | `rgba(255,255,255,0.06)` to `0.12` | Rows, cards, chips; `0.12` is the selected row on touch platforms and the selected-but-unfocused group on tvOS |
| Text | `#F2F4F8` | Primary |
| Text secondary | `#D7DEE8` | Body copy and descriptions |
| Text muted | `#A7B0BF` | Captions, metadata, section eyebrows. 9:1 on ground |
| Text muted on focus | `#4B5563` | Muted text on the focused white card. 7.5:1 on `#F2F4F8` |
| Accent | `#5BB8FF` | Progress fills, guide now line, NOW badge, iPhone selected tab, links |
| Live dot | `#FF5F57` | Only the small dot before "LIVE" |
| Logo placeholder | `#26344A`, `#1E3A5F` | Tile with channel initials when no logo has loaded |
| Focus (tvOS) | background `#F2F4F8`, text `#0B0E13`, shadow `0 12px 32px rgba(0,0,0,.45)` | The focused element, always |

Type is the system font. Sizes in CSS px on the boards equal points in
SwiftUI.

| Platform | Title | Body | Secondary | Caption, minimum |
|----------|-------|------|-----------|------------------|
| tvOS | 38 to 76 | 29 | 22 to 26 | 18 |
| iPadOS, macOS | 22 to 28 | 16 to 17 | 14 to 15 | 13 |
| iOS | 22 to 34 | 15 to 17 | 13 | 12 |

Radii: 14 (tvOS rows and cards), 10 to 12 (touch rows, cards, fields), 6 to 8
(logo tiles, badges), 999 (chips, tvOS tab bar).

## 2. Layout patterns

### Apple TV

- Live video is the background of every live screen. Overlays slide over it;
  the player is never torn down to show UI.
- Channel overlay: three columns from the left, groups (320) | channels (700)
  | now and next (rest), scrim width 1600 of 1920. Clock top right.
- Zap bar: bottom strip, 236 tall, identity | now playing with progress |
  badges. Channel digits typed on a hardware keyboard appear top left.
- Guide: PiP player (480 by 270) and programme detail on top, grid below
  with a 300 wide channel column, 370 per 30 minutes, accent now line.
- Non-live sections (Movies, Series, Search) use the tvOS top tab bar:
  Live, Guide, Movies, Series, Search, then the settings gear. Clock top
  right. Spec 0015 owns the bar and its Menu behaviour.
- Focus is the lifted white card. Nothing else is white-filled.

### iPad and Mac

- Three columns: sidebar (232) | list (352) | detail. The sidebar holds the
  sections and, below them, the context list (channel groups, genres,
  recent searches). Sources and Settings sits at the bottom.
- Live: the detail column is the inline player (16:9) with now and next and
  the upcoming list under it.
- Movies and Search put a toolbar on top of the detail column and scroll
  content below it.

### iPhone

- Tab bar: Live, Guide, Movies, Search, Settings. Favorites is a group chip
  inside Live, not a tab.
- Live: player pinned at the top (16:9), now playing row, scrolling group
  chips, channel list.
- Movies: tall portrait hero, chips laid over the art, copy on a solid scrim
  at the foot of the hero, then rows.
- Onboarding and add source are sheets. iPad centres the same sheet.

## 3. Shared components

- **Channel row**, every platform, in this order: number (tabular, muted),
  logo tile, name, current programme title, 3 to 4 pt progress bar in
  accent. Catch-up shows a clock-arrow glyph at the trailing edge.
- **Programme progress bar** appears everywhere a current programme is
  shown: rows, now panels, zap bar, player scrubber, continue-watching
  cards.
- **Badges**: 1.5 pt muted outline, uppercase, letter-spaced (`4K`,
  `1080p`, `AAC 5.1`, `CATCH-UP 7D`; `CATCH-UP` alone when the day count
  is unknown). The only filled badges are `NOW` (accent) and `LIVE`
  (surface with the live dot). Resolution and audio badges come from the
  player and exist only for the playing channel. As running text the
  catch-up fact reads "Catch-up 7 days".
- **Section header**: title plus a muted count or "See all" at the trailing
  edge.
- **Content card**: 2:3 poster for titles, 16:9 for continue watching with
  a progress bar along the bottom edge. Focused card on tvOS gets a 5 pt
  white ring and shadow.
- **Search highlight**: the matched substring gets an accent background at
  35% opacity.

## 4. Screens and boards

| Screen | Board | Spec |
|--------|-------|------|
| TV channel overlay | `Main.dc.html` | 0007 |
| TV channel overlay, Favorites group with filled star | `Main-Favorites.dc.html` | 0007 |
| TV channel overlay, Favorites empty | `Main-FavoritesEmpty.dc.html` | 0007 |
| TV channel overlay, empty catalogue | `Main-Empty.dc.html` | 0007 |
| TV channel overlay, no programme information | `Main-NoProgramme.dc.html` | 0007 |
| TV channel overlay, guide loading | `Main-GuideLoading.dc.html` | 0007 |
| TV zap bar and number entry | `TV-ZapBar.dc.html` | 0008 |
| TV zap bar, hidden | `TV-ZapBar-Hidden.dc.html` | 0008 |
| TV zap bar, no programme information | `TV-ZapBar-NoProgramme.dc.html` | 0008 |
| TV zap bar, guide loading | `TV-ZapBar-GuideLoading.dc.html` | 0008 |
| TV zap bar, guide unavailable | `TV-ZapBar-GuideUnavailable.dc.html` | 0008 |
| TV zap bar, programme ends now | `TV-ZapBar-EndsNow.dc.html` | 0008 |
| TV zap bar, no catch-up | `TV-ZapBar-NoCatchup.dc.html` | 0008 |
| TV zap bar, buffering | `TV-ZapBar-Buffering.dc.html` | 0008 |
| TV zap bar, Favorites group | `TV-ZapBar-Favorites.dc.html` | 0008 |
| TV zap bar, All channels | `TV-ZapBar-AllChannels.dc.html` | 0008 |
| TV number entry, no match | `TV-ZapBar-PillNoMatch.dc.html` | 0008 |
| TV number entry, zeros only | `TV-ZapBar-PillZeros.dc.html` | 0008 |
| TV number entry, no such channel | `TV-ZapBar-PillNoChannel.dc.html` | 0008 |
| TV guide grid | `TV-Guide.dc.html` | 0009 |
| iPad and Mac live browse | `iPad.dc.html` | 0010 |
| iPhone live | `iPhone.dc.html` | 0010 |
| TV movies | `TV-Movies.dc.html` | 0011 |
| iPad and Mac movies | `iPad-Movies.dc.html` | 0011 |
| iPhone movies | `iPhone-Movies.dc.html` | 0011 |
| TV search | `TV-Search.dc.html` | 0012 |
| iPad and Mac search | `iPad-Search.dc.html` | 0012 |
| iPhone search | `iPhone-Search.dc.html` | 0012 |
| TV onboarding, 5 steps | `TV-Onboard-1.dc.html` to `TV-Onboard-5.dc.html` | 0006 |
| iPhone onboarding, 3 steps | `iPhone-Onboard-1.dc.html` to `iPhone-Onboard-3.dc.html` | 0006 |
| TV shell, tab bar over the dimmed picture after Menu | `TV-Shell-Menu.dc.html` | 0015 |
| TV shell, focus on the tab bar | `TV-Shell-FocusedTab.dc.html` | 0015 |
| TV shell, loading at launch | `TV-Shell-Loading.dc.html` | 0015 |
| TV shell, no channels | `TV-Shell-Empty.dc.html` | 0015 |

Core specs with no screen: 0013 channel catalogue, 0014 guide data. The
tvOS shell (spec 0015) owns the top bar drawn on `TV-Movies.dc.html` and
`TV-Search.dc.html`, gear included, plus the four `TV-Shell-*` boards.

Not yet drawn: paywall (ADR-0006), guide on iPhone, iPad and Mac, movie and
series detail, player controls on tvOS, Sources and Settings, and the empty,
loading and error states each spec lists under "Not drawn". The "source
arrived without its credential" state on tvOS is on `TV-Shell-Empty.dc.html`.
series detail, player controls on tvOS, Sources and Settings, the "source
arrived without its credential" state on tvOS, and the empty, loading and
error states each spec other than 0008 lists under "Not drawn".

Remote vocabulary on tvOS, used by every spec: *select* is a press of the
touch surface; *swipe* and a directional click on the clickpad are the
same input; *Menu* is the back button; *play/pause* is its own button.

## 5. Design rules

Stable ids. Specs list the ones that apply; reviewers check them. Do not
renumber; retire a rule by marking it "Retired" with a reason.

- **DR-1 Video never stops on tvOS.** Showing the overlay, zap bar, guide or
  search while a channel plays keeps the same player instance playing.
  Checkable: no `PlayerView` teardown or `pause()` on overlay presentation.
- **DR-2 Focus is the white card.** On tvOS the focused element has the
  Focus token above. No accent borders, no scale-only focus.
- **DR-3 One accent.** `#5BB8FF` is the only accent colour. It appears on
  progress, the now line, `NOW`, links and the iPhone selected tab. Nothing
  else is tinted.
- **DR-4 Type floors.** Text is never smaller than the caption minimum for
  the platform in section 1.
- **DR-5 Target sizes.** Touch targets at least 44 pt. Focusable rows on
  tvOS at least 64 pt tall.
- **DR-6 Channel row anatomy.** Section 3's order and parts, on every
  platform that lists channels.
- **DR-7 Progress wherever a programme is current.** A current programme
  is never shown without its progress bar.
- **DR-8 Logo fallback.** A channel without a loaded logo shows a tile in
  the placeholder colour with up to four characters of initials. Never an
  empty frame or a system glyph.
- **DR-9 Movies are content first.** Movies and Series screens open with a
  hero and poster rows. A plain list is never the first view.
- **DR-10 One search.** Search is a single field across channels, guide,
  movies and series, with sectioned results and highlighted matches.
- **DR-11 Identifiers follow the board.** Accessibility identifiers use
  the screen prefix of the board: `onboarding.`, `overlay.`, `zapBar.`,
  `guide.`, `browse.`, `movies.`, `series.`, `search.`, `shell.`. Element names come from the
  board's comments and labels (`overlay.groups`, `zapBar.progress`).
- **DR-12 Nothing fake, nothing bundled.** No drawn status bars in the app,
  no bundled channels or titles, no third-party logos or artwork. Channel
  and programme names on the boards are sample data for layout only and
  never ship. Copy may name platforms (Apple TV, iPhone) but never the
  user's own device name or the user.
- **DR-13 Contrast.** Text meets 4.5:1 against what it sits on, including
  muted captions; 3:1 for text at 24 pt and above.
- **DR-14 Paywall first.** Per ADR-0006 nothing in this document is shown
  until an entitlement is present. Onboarding starts after the paywall.
- **DR-15 Loading tells the truth.** Multi-step loads (onboarding, source
  refresh) show per-step state with real counts as they arrive, never a
  single spinner for the whole job.

## 6. How reviewers use this

- `spec-reviewer`: a spec that describes a screen must name its board and
  the DR ids that apply. A described state (focused, empty, loading, error)
  that is not on the board is a finding unless the spec's Design section
  lists it under "Not drawn" with the text style it uses. States listed
  there must be drawn before the implementing PR opens; the `impl-reviewer`
  treats a missing board state as NOT READY.
- Deviations from a DR are allowed when the Design section names the rule
  and the reason in one sentence (for example a compact row variant in
  search results). An unnamed deviation is a finding.
- `impl-reviewer`: for each DR the spec lists, find the evidence in the
  diff. Compare the view hierarchy to the board's structure and the inline
  sizes to section 1. Identifier prefixes per DR-11. A mismatch the spec
  did not call out is a finding.
