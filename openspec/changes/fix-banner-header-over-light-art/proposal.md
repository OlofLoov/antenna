# Proposal

## Why

> The owner, on Series: the "Series" title and the "All series" button over the picture at the top have no shade or background, so they disappear when the picture is light.

On iPhone, and in a narrow iPad window, the section's name, the profile button and the genre button sit straight on the banner art. The copy at the foot of the banner has its band, the top has nothing. On a white or pale picture the white name and the gray count and chevron are close to invisible. Movies has the same header and the same fault.

After this change the name and the genre button read on any picture, and a dark picture looks as before.

## What Changes

- A band of the ground color behind the section's name, the profile button and the genre button at the top of the iPhone banner, darkest at the top edge and fading into the art below the genre button, as the band under the copy fades into the art above it.
- The iPhone Movies boards draw the band.

Out of scope:
- iPad and Mac in a regular window put the name and the sort menu above the banner card on the ground color, not over the art.
- Apple TV has no name or genre button over the art. The tab bar is the system's, and the clock has its own ground.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `design-system`: "The scrim blends into the art" covers the header at the top of the iPhone banner.

## Impact

- Platforms: iPhone, and iPad in a narrow window, where Movies and Series use the iPhone layout.
- Code: the iPhone banner layout and a new scrim next to the existing two in `Apps/Shared/Components/`.
- Boards: `iPhone-Movies`, `iPhone-Movies-Grid` and `iPhone-Movies-Trailer` draw the band.
- Depends on nothing and is blocked on nothing.
