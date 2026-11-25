# Design

## Context

`ShelfBanner.Phone` lays its `top` content, the section's name, the profile button and `ShelfGenreButton`, over the art with `.overlay(alignment: .top) { top }` and nothing behind it. The boards drew it that way: `iPhone-Movies` says the genre button is "plain with no fill over the art", and the board's placeholder art is a dark blue, so the missing ground never showed. The copy at the foot has `HeroFootScrim`. Real key art is often light at the top (sky, snow, a white title card), and there the name (`Palette.text`) and the count and chevron (`Palette.textMuted`) disappear.

## Decisions

### A top band, not a material capsule

`HeroTopScrim` is the background of the `top` content: 0.86 of the ground color at the top edge to 0.8 at the foot of the genre button, then clear over 56 pt below it. It mirrors `HeroFootScrim`, which takes 0.78 to 0.86 under the copy with a 56 pt fade.

Options considered:
- A material capsule behind the genre button (rejected): the board keeps the button plain, as Live's group button, and a capsule covers only the button, not the section's name. A second capsule behind the name would be two glass shapes in a row over the art, which `liquid-glass-stays-on-the-navigation-layer` keeps off the content layer.
- A shadow on the text (rejected): too weak on white for muted text at 15 pt.
- A band of the ground color that fades into the art (chosen): one shape behind the whole header, the same idea and opacities as the band under the copy, and it satisfies `the-scrim-blends-into-the-art`. No glass, so the owner's rule against glass with an extra fill or stroke does not come into play.

### How dark

The muted count (#A7B0BF) needs 4.5:1 (`text-meets-contrast-minimums`). On white, 0.8 of #0B0E13 gives a gray near #3E3F40, about 4.8:1 against the muted color. 0.8 is the lightest the band gets behind the header; it is darker toward the top edge, where the status bar sits too. On a dark picture the band changes almost nothing.

### Testing it

`HeroScrimTests` renders the band over white and checks the muted color reaches 4.5:1 at the top, middle and foot of the header, that the band has no line down its column, and that it is clear below the fade. A second test renders `ShelfBanner.Phone` with a 150 pt header and checks the art behind it is darker than the bare art; it fails without the band. Previews render the iPhone banner with the Series and Movies headers over a solid white picture and over a near-black one, from `PreviewArt.solid`, with no network.

## Platforms

iPhone, and iPad or Mac in a narrow window, which use `ShelfCompactScreen` and `ShelfBanner.Phone`. iPad and Mac in a regular window put the toolbar above the banner card on the ground color. Apple TV has no header over the art.

## Boards

`iPhone-Movies`, `iPhone-Movies-Grid` and `iPhone-Movies-Trailer` add the band behind the top bar and the genre button. Design-system requirements followed: `the-scrim-blends-into-the-art`, `text-meets-contrast-minimums`, `liquid-glass-stays-on-the-navigation-layer`.
