# Design

## Context

`ShelfCompactScreen` draws Movies and Series on iPhone and in a narrow iPad window. Today its `ScrollView` ignores the top safe area, and `ShelfBanner.Phone` fills the top 520 pt with art edge to edge. The section's name, `ProfileMenuButton` and `ShelfGenreButton` are the banner's `top` content, laid over the art on `HeroTopScrim`. After 420 pt of scroll the screen overlays a copy of the name and the profile button on `Palette.ground` with a hairline; that copy has no genre button.

Live already has the glass the owner likes: the player controls and the picture-in-picture capsule are `.glassEffect(.regular, in: Capsule())` over the picture, with no fill or stroke of their own (`BrowseControls.swift`, `LivePicture.swift`).

## Decisions

### 1. Glass controls on a transparent bar, not one glass slab

The bar is a `safeAreaBar(edge: .top)` on the scroll view. The bar itself draws nothing. The section's name is plain text in the display style, the genre button is a glass capsule (`.buttonStyle(.glass)`), and the profile button keeps its own look. Content scrolls under the bar, and the system's scroll edge effect blurs and dims it there, as it does under a navigation bar.

Options considered:
- One glass slab the width of the screen behind the name and both buttons (rejected). Apple's own apps on iOS 26 (Music, TV, Photos, App Store) do not put a glass slab behind the top bar: the bar is transparent, the controls float in glass, and the scroll edge effect keeps the title readable over what passes under it. A slab is the pre-26 material bar in glass, puts a large glass shape over the rows, and would put the glass capsule on glass, which `liquid-glass-stays-on-the-navigation-layer` forbids.
- A solid bar on the ground color, as the pinned copy today (rejected). It reads on any art but is not glass, and it is the flat bar the owner asked to replace.
- Glass capsules on a transparent bar with the scroll edge effect (chosen). It matches the Live capsules, keeps one glass shape per control, and is what Netflix's iPhone app does: its header and category pills sit on a transparent bar, the hero card starts below them, and rows blur under the header as they scroll.

The scroll edge effect is the system's default for the bar; no style is set. `safeAreaBar` is what gives a custom bar the effect; a plain `overlay` or `safeAreaInset` does not. On the iOS 27.2 simulator the posters passing under the bar blur and dim behind the name and the capsule, and the name reads over the light Snow Day poster.

The profile button stays plain: a colored disc with the profile's initial, or the person glyph with one profile. A glass circle around the colored disc would be glass with a fill inside it, which the owner's rule forbids. At rest the bar sits on the ground color, since the banner starts below it, and when content scrolls under it the edge effect darkens what is there.

### 2. One row, name then genre button then profile

`[Movies] [All movies · 214 ⌄] ··· (K)`, 44 pt tall, 16 pt from the leading edge and 12 pt from the trailing edge, the same insets as today's top bar. The name never shrinks. The genre name truncates at the tail before the count and chevron do, so a long genre such as "EN | Action & Adventure" keeps its count. Two rows, the name above the genre button, would put about 100 pt of bar over the rows at all times on the smallest iPhone.

The genre button is `ShelfGenreButton` in a glass style. Live's group button (`Browse.GroupButton`) stays plain where Live uses it. A new component, `ShelfTopBar`, takes the title and two view builders for the genre button and the profile button, so it stays free of the model and of SwiftData. The glass button is `ShelfCategoryButton`, a component that takes the name, the count and the action: the name, the count and the chevron in `.buttonStyle(.glass)` at `.controlSize(.large)`, which draws the capsule 44 pt tall, the hit target the design system asks for.

When the section has no titles (loading, empty, failed) the bar shows the name and the profile button only, as today.

### 3. The banner is an inset card below the bar

`ShelfBanner.Phone` loses its `top` content. It is 480 pt tall, inset 16 pt from each side, and clipped to `cornerShape(.large)`, the radius of the iPad banner card. Art, eyebrow, title, facts, description, buttons and dots stay in the card in today's order, on `HeroFootScrim`.

Options considered:
- Full bleed from the bar down, square corners (rejected). The art would butt against the bar's bottom edge, and as soon as the user scrolls the art runs under the bar edge to edge, so the bar and the art read as one picture again.
- Inset card with rounded corners (chosen). It is the Netflix iPhone hero card and the iPad banner card, and it reads as one unit: picture, copy and buttons together, separate from the bar.

480 pt keeps the copy and both rows of buttons in the card with about 200 pt of clear art above them, and leaves the Continue watching header in view under the card on an iPhone 17 Pro.

### 4. The top band goes

`HeroTopScrim` is only used by the iPhone banner. It is deleted with its preview and its two tests. `HeroFootScrim` and `HeroScrim` stay. The phone banner line test keeps checking that the band under the copy has no line, one column in from the card's rounded corner.

### 5. Identifiers

- `<prefix>.bar` on the bar (`movies.bar`, `series.bar`), a container.
- `<prefix>.title`, `<prefix>.genres`, `profile.button` and `<prefix>.hero` as today.

### 6. Testing

- Unit, `ShelfTopBarTests` (replaces the two top band tests in `HeroScrimTests`): the genre button's view is the system glass button style, and nothing in it draws a background, overlay, border or shadow (`design-system/liquid-glass-stays-on-the-navigation-layer`).
- UI, `ShelfUITests`: the banner's top edge is at or below the bar's bottom edge; the genre button is inside the bar and reads "All movies" and then the picked genre; after the rows scroll past the banner the bar, the name and the genre button are still where they were (`movies-and-series-browsing/a-pinned-top-bar-on-iphone`).
- Previews: the iPhone bar over a white picture and over a dark one, from `PreviewArt.solid`, and the iPhone banner card, all without network.
- Screenshots: before and after on a local iPhone simulator, with The Long Harbor's dark art and Snow Day's light art from the store art.

## Platforms

iPhone, and iPad or Mac in a narrow window, both through `ShelfCompactScreen`. iPad and Mac in a regular window (`ShelfRegularScreen`) put the name, the search field and the sort menu in a row on the ground color above the banner card, so the header never sits on art. Apple TV has no header over the art. Neither changes.

## Boards

`iPhone-Movies`, `iPhone-Movies-Grid` and `iPhone-Movies-Trailer` draw the bar and the inset card. `iPhone-Movies-Rows` and `iPhone-Movies-Discover` draw the same bar with rows under it in place of the flat pinned bar.

Design-system requirements followed: `liquid-glass-stays-on-the-navigation-layer`, `controls-use-system-styles`, `the-scrim-blends-into-the-art`, `one-spacing-and-radius-scale`, `text-meets-contrast-minimums`, `targets-are-large-enough-to-hit`, `copy-fits-in-every-language`, `layouts-mirror-in-right-to-left-languages`.

Not drawn: the bar in Arabic (it mirrors, the name at the right) and the loading state (the bar without the genre button over the loading layout).
