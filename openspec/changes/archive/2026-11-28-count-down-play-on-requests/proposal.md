# Proposal

## Why

> As the owner, who sends from the iPhone to the Apple TV every day: "do we need the modal being shown sometimes when sending play on apple tv? what about a countdown that can be cancelled — as a user I don't want to switch from one controller to another".

Over the home network the TV starts a request at once. When the network send fails, the request waits in iCloud and the TV shows a modal offer with Play and Not now, which only the Siri Remote can answer. The owner sees that offer "sometimes" even at home, with Antuna open on the TV, and then has to find the remote to press Play.

Afterwards a request the TV did not start at once plays by itself after a five-second countdown. The viewer can stop it on the TV with one click or Menu, and the sender can stop it from the phone. The network path also fails less often, and each fallback leaves a log line saying why.

## What Changes

- The Apple TV's offer for a waiting request becomes a countdown banner at the top trailing corner: "From Anna's iPhone", the item, and "Starts in 5", counting down. At zero the item plays with no remote press. Cancel has focus, so one click stops it; Play now is the other button; Menu or Back stops it too. This covers a request picked up from iCloud and one the TV kept behind the paywall or "Who's watching?".
- Every request expires one minute after it was sent, for a channel, a programme, a film or an episode alike (owner, 2026-11-28), replacing 5 minutes for live TV and 6 hours for the rest. No request waits long, so every one gets the countdown and the Play / Not now offer goes away. A countdown that started finishes even if the minute runs out during it.
- The phone's "Sent" line offers Cancel for ten seconds while the request can still be taken back. Cancel deletes the request from iCloud while it waits there. Once a TV has it, counting down or holding it behind a gate, Cancel tells that TV over the network to drop it. When neither works the phone says "Living Room already has it."
- The phone's line for a request in iCloud reads "Sent. Living Room plays it if Antuna opens there within a minute." The menu row for a TV that is not reachable reads "Plays if opened within a minute".
- Network fixes: the TV listens before it reads iCloud when it comes back to the foreground, and reads the account's devices every 30 seconds while open. The phone browses for TVs before it reads iCloud. It waits 3 seconds instead of 1.5 for a TV to show up, retries a refused handshake twice and a dropped connection once, and waits for the TV's answer for 12 seconds once the request has reached the TV.
- Debug builds log why each send went through iCloud, in the `playOn` category, with no title, link or name.

Out of scope: a countdown for requests that arrive over the network while the shell shows (they still start at once), cancel from the phone after the TV started playing (the connected bar's controls cover that), keeping key pairs across launches, and waking a TV that is asleep.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `play-on-apple-tv`: "The TV offers a waiting request" becomes "The TV counts down a waiting request". "Starts at once on the same network", "Waits in iCloud when the TV is not reachable", "Requests expire and leave no trace", "The TV keeps its own locks and profile" and "The phone says why the TV cannot play" change their wording to the countdown and the one-minute expiry. "Apple TVs on the same iCloud account" and "The local network is asked for only when needed" change the menu row's words. A new requirement, "The phone can take a request back", adds Cancel on the phone.

## Impact

- Platforms: Apple TV (countdown, listener), iPhone, iPad and Mac (Cancel, retries, browsing).
- Code: `PlayRequestInbox`, `PlayOnReceiver`, `PlayOnListener`, `PlayDestination`, `NetworkPlaySender`, `PlayOnConnection`, `PlayOnRuntime`, the shell's play requests, a new `PlayCountdown` and `PlaySendRetry` in AntennaCore, a `cancel` frame and a `canceled` answer in `PlayMessage`.
- Boards: `TV-FromIPhone-Countdown` replaces `TV-FromIPhone-Offer` and `TV-FromIPhone-Offer-Channel`; `iPhone-PlayOn-Messages` gains Cancel.
- Depends on the archived `play-on-apple-tv` and `show-sync-status` changes. Blocked on nothing.
