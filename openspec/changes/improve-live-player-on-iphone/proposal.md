# Proposal

## Why

> As someone watching on an iPhone, I want the picture to fill the screen whenever I hold the phone sideways, and I want to change channel or skip back without opening the list.

On a real iPhone, Live sideways often keeps the tab bar and the channel line on screen. Full screen only turns on when the phone rotates while a channel already plays on Live. Picking a channel while sideways, launching sideways, coming back to Live sideways, or coming back after a movie all leave the list layout. On an iPhone Plus or Pro Max, sideways switches to the iPad sidebar layout instead. Once the picture fills the screen, the only way to change channel is to turn the phone upright, and there is no way to skip back a few seconds without opening the controls.

## What Changes

- An iPhone held sideways on Live with a channel playing always shows the picture full screen: after picking a channel sideways, at launch, on returning to Live, and after a movie or episode.
- Exit full screen while sideways shows the list sideways until the user picks or changes channel, or turns the phone.
- Every iPhone keeps the phone layout with the tab bar, in either orientation. iPad and Mac keep choosing by window width.
- Full screen shows the channel's name and programme at the top of the picture only while the controls show, and both fade together.
- Swipe up on the picture for the next channel in the open group, swipe down for the one before, on iPhone, iPad and Mac.
- A Previous channel button in the player controls goes back to the channel watched before this one.
- Double-tap the left or right half of the picture to skip 15 seconds back or forward when the channel can rewind; otherwise a short note says why nothing moved.
- VoiceOver users reach each gesture as an action on the picture.

Out of scope:
- Locking the orientation, or turning the interface upright on Exit full screen.
- Gestures on Apple TV, which has its own swipes, and on multi-view tiles.
- Volume or brightness swipes.
- A setting that turns the gestures off.
- Changing the 30-second skip of the skip buttons and arrow keys.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `live-tv-on-iphone-ipad-mac`: full screen follows the iPhone's orientation from every state, every iPhone keeps the phone layout, the full-screen channel line fades with the controls, and the picture gains swipe, double-tap and Previous channel. The capability exists only in change `add-live-tv-on-iphone-ipad-mac` so far, so this change adds requirements rather than modifying its Full screen requirement.

## Impact

- Platforms: iOS and iPadOS, with the gestures and Previous channel also on macOS. tvOS is untouched.
- Code: the window root's layout choice and full-screen rule, the Live picture and its controls, the Live model, the timeshift model's skip, and the UI tests for the player and the regular layout.
- Boards: `iPhone-FullScreen` and `iPhone-Player` gain the channel line and the Previous channel button.
- Depends on: `add-live-tv-on-iphone-ipad-mac`, `add-player-controls-and-playback-errors`, `add-timeshift-catch-up-and-start-over`, and session restore for Recents.
- Blocked on: nothing.
