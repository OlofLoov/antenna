# Design

## Context

Live's channel is held behind Movies, Series and Search by `LiveHold`: the screen that owns the engine says when a tab opens, the hold pauses the channel, a 30 second timer stops it, and Live or the Guide ends the hold. iPhone, iPad and Mac run it through `LiveModel.tabOpened`, Apple TV through `ShellModel.opened`. Before this change Settings was left out on both: `tabOpened(.settings)` did nothing, and the Apple TV shell ended the hold when Settings opened.

What each platform did before and does after:

| Where | Before | After |
|---|---|---|
| iPhone, narrow iPad: Settings sheet from the profile button | Live played on under the sheet with its sound | the channel pauses, stops after 30 seconds; Close reopens the tab under the sheet |
| iPad, Mac: Settings in the sidebar or the Go menu | the channel played on | the channel pauses, stops after 30 seconds; Live or the Guide plays it on |
| Apple TV: Settings tab | the channel played on, and a hold from passing Movies, Series and Search ended there | the hold starts or keeps running; Live or the Guide ends it |

No board changes; nothing on screen moves.

## Decisions

### Settings is one more tab that holds the channel

Options considered:
- Stop the stream at once when Settings opens. Simple, but closing Settings a second later would load the channel again, and the rule would differ from Movies.
- Pause without the 30 second stop. The provider's connection would stay open as long as Settings does.
- Hold it exactly as Movies, Series and Search do. Chosen: one rule for every screen that hides the picture, already tested, and closing Settings gives back the same channel as coming back to Live does today.

On Apple TV this reverses `fix(tv): resume live when the highlight reaches Settings`. That fix stopped the hold from freezing the channel behind Settings; the owner's rule is now that nothing plays behind Settings, and the Settings tab does not show the picture anyway (`ShellTab.showsPicture` is false).

### The sheet reports itself to the Live model, not as a tab

`CompactTabs` calls `LiveModel.settingsSheet(shown:over:)` when `settingsShown` changes. Open, it runs `tabOpened(.settings)`; closed, it runs `tabOpened` for the tab under the sheet, so over Live or the Guide the hold ends and over Movies, Series or Search it stays. It goes through the same queue as tab changes, so a link that closes the sheet and switches tab at once lands in order. It does not call `opened(_:)`, which would also store Settings as the tab to reopen at launch.

A narrow iPad window that widens while the sheet is open drops the tab bar and its sheet without the binding changing, so `CompactTabs.onDisappear` reports the sheet closed; otherwise the sidebar's Live would open on a paused channel.

A reminder's Watch over the sheet picks the channel (`endHoldForPick`) before the sheet closes, so the channel plays on Live as before.

### Picture in Picture and AirPlay keep playing

The user moved the channel out of the app on purpose, so opening Settings leaves a Picture in Picture window or an AirPlay device playing. This is the hold's existing rule (`holdBehindContent` skips a channel that `playsElsewhere`). Bringing the picture back into the app while Settings is open pauses it, as on Movies.

## Tests

- `Apps/Tests/LiveHoldTests.swift`: the Settings section pauses and Live plays on; the sheet over Live pauses and Close plays on; 30 seconds behind the sheet stop the stream and Close tunes it again; the sheet over Movies leaves the hold; Picture in Picture plays on; the sheet keeps the launch tab.
- `Apps/TVTests/ShellNavigationTests.swift`: Settings pauses and Live plays on; Settings after Movies keeps the hold; 30 seconds on Settings stop the stream.
- UI tests on the scripted engine: `LiveUITests.testSettingsPausesTheChannelAndClosePlaysItOn` on iPhone and `ShellUITests.testSettingsPausesTheChannelAndLivePlaysItOn` on Apple TV read the engine's state through the debug probe.
