# Design

## Boards

- `TV-FromIPhone-Countdown.dc.html` (new) replaces `TV-FromIPhone-Offer.dc.html` and `TV-FromIPhone-Offer-Channel.dc.html`, which are deleted. The banner sits where `TV-FromIPhone-Banner` and `TV-Reminder-Banner` sit, top trailing inside the safe area, 640 pt wide on the overlay's scrim, with the reminder banner's 64 pt buttons. It follows design-system/apple-tv-content-stays-in-the-safe-area and design-system/focus-is-the-lifted-white-card (Cancel lifted on appearance).
- `iPhone-PlayOn-Messages.dc.html` gains the "Sent" line with Cancel at its trailing end, and the "Canceled." and "Living Room already has it." lines.
- `TV-FromIPhone-Banner.dc.html` is unchanged: a request over the network still plays at once.

Not drawn: the countdown at "Starts in 1" (only the number changes) and the countdown over multi-view, which a request leaves anyway when it plays.

## Decision 1: a countdown instead of the offer (owner, 2026-11-28)

Options:

1. **Keep the Play / Not now offer.** Needs the Siri Remote for every request that went through iCloud. That is what the owner asked to remove.
2. **Play at once, no banner beyond "From Anna's iPhone".** Simplest, but a viewer at the TV gets no warning and no way to say no before the picture changes.
3. **A five-second countdown with Cancel focused (chosen).** Doing nothing plays, one click or Menu stops it, and the phone can stop it too.

Cancel has focus rather than Play now because the countdown already plays by itself: the one press the remote is likely to get should do the other thing.

## Decision 2: every request expires after one minute (owner, 2026-11-28)

The owner: a request older than about a minute is not relevant. `PlayRequest.lifetime` is 60 seconds for every item, replacing 5 minutes for live TV and 6 hours for films, episodes and catch-up. With that there is no long-waiting request, so there is no exception to the countdown and the old offer goes away entirely. Expired requests are still deleted unread by the sweep on any device.

The phone writes `created` and the TV compares it with its own clock. Both clocks are set from the network, so a few seconds of skew only shortens or lengthens the minute slightly.

A countdown that started plays when it ends, even if the minute runs out during those five seconds. The viewer saw "Starts in 5"; taking it away at 2 would look like a bug. Expiry is checked when the TV picks a request up and when it counts down one it kept behind a gate.

## Decision 3: where the countdown runs

`PlayCountdown` (AntennaCore) holds the request and when the countdown started; `secondsLeft(at:)` and `isDue(at:)` are pure. `PlayRequestInbox.countdown` replaces `offered`:

- `offer(_:now:)`: an iCloud pickup. While no shell shows (paywall, "Who's watching?") it is kept, not counted, so the five seconds start when the viewer can see them.
- `attach(now:)`: a kept request that has not expired starts its countdown.
- `detach()`: a running countdown goes back to kept.
- `tick(now:)`: plays it when due. `playNow()` plays at once, `cancelCountdown()` drops it.
- `cancel(_ id:)`: a phone's cancel. It drops a counting or kept request, or marks an id the TV has not seen as handled so it never plays; it returns false once the request played.

`ShellPlayCountdown` (Views/Shell) shows `FromDeviceCountdown` (Components/PlayOn) in each page's overlay next to `ShellReminderBanner`, where the focus engine lets it take the highlight. It drives `tick` four times a second, focuses Cancel on appearance, handles Menu with `onExitCommand`, and puts focus back where it was on Cancel. Play goes through the same delivery as a network request, so locks, the passcode and the profile apply as before.

Identifiers: `playOn.countdown`, `playOn.countdown.sender`, `playOn.countdown.title`, `playOn.countdown.time`, `playOn.countdown.cancel`, `playOn.countdown.playNow`.

## Decision 4: Cancel on the phone

A request can be taken back while it waits on the phone's side or on the TV's:

| Where the request is | Cancel does | The phone says |
|---|---|---|
| In iCloud, not picked up | deletes the record if it still holds this request | Canceled. |
| On a TV reachable on the network, counting down or kept behind a gate | sends `cancel` with the request id; the TV answers `canceled` | Canceled. |
| On a TV that is not reachable, or already playing it | nothing | Living Room already has it. |

The phone tries iCloud first, then the network: over the open link when connected to that TV, else over a new link with the same handshake. Cancel shows on the "Sent" line for ten seconds (`PlayDestination.cancelWindow`), long enough for an open TV to pick the request up by push and count it down. A request the TV started at once has no Cancel; the connected bar covers it.

Options considered:

1. **iCloud only.** Misses the countdown, which is when the sender is most likely to change their mind.
2. **Poll iCloud to see when the TV took it.** Extra reads, and still no way to stop the TV without the network.
3. **iCloud, then the network (chosen).**

Wire format: a new frame type `cancel` with `{ "cancel": <request id> }`, and a new answer result `canceled`. The frame version stays 1. An older TV reads `cancel` as an unknown type and ignores it; the phone then hears no answer and says "already has it". Only a phone with this change sends `cancel`, so no older phone sees `canceled`.

## Decision 5: why the network path fails "sometimes", and the fixes

Read from the code, with Antuna open on the TV on the same Wi-Fi:

1. **New keys every launch.** Each device makes its key pair at launch (the archived play-on-apple-tv design). The TV read the device list only when it became active and after a refused handshake. iOS ends suspended apps often, so after the iPhone app restarts the TV holds its old key and refuses the first send. The phone waited 1 s, read the list, and tried once more. The TV's own read is a CloudKit round trip followed by a listener restart, and a retry that landed before the read finished, or during the restart, failed. The TV also reads at most once every 5 s, so a second refusal did not trigger a second read. The request then went to iCloud and the TV showed the offer. This is the most likely cause of "sometimes".
2. **The TV listened only after two CloudKit calls** (save its record, read the devices) every time it came back to the foreground, as after the TV sleeps. A send in those seconds found no TV.
3. **The phone browsed only after two CloudKit calls** on becoming active, and waited 1.5 s for a TV to show up. A send soon after opening the app found no endpoint.
4. **Three seconds covered the TV's work too.** The TV answers once it has started the item. A source still loading gets up to 10 s, and an episode list is fetched from the provider. The phone gave up after 3 s, queued the request and said "offers it when Antuna opens there" while the TV played it. The TV plays an id once, so no offer showed, but the phone showed the wrong line and no bar.
5. **A connection in `waiting`** (a refused TCP connection while the TV restarts its listener) ended the link at once, and nothing tried again.

Fixes:

- The TV starts listening first when it already knows the devices, then saves and reads. It reads the device list on every 30-second pickup as well, so a phone that restarted is usually known before it sends. The listener rebinds its port with `allowLocalEndpointReuse`.
- The phone starts the browser first on becoming active, and waits up to 3 s for a TV it has not found.
- `PlaySendRetry` (AntennaCore) decides what follows a failed send: a refused handshake is tried again after 1 s and then 2 s, each time after reading the devices again; a dropped or refused connection is tried again after 0.5 s; at most three tries. No endpoint, refused local network access and no answer go straight to iCloud. The TV plays a request id once, so a retry never plays twice.
- `NetworkPlaySender` has 3 s to reach the TV and then 12 s for the answer once the request is on the link (`reachLimit`, `answerLimit`).
- Each fallback logs its reason through `PlayOnLog.fallback(_:)` as `sent through iCloud: refused after 3 tries`, and each retry as `retry 2 after unreachable`. The lines carry no title, link or name.

Not fixable here: a TV asleep or with Antuna in the background (tvOS suspends it), local network access refused on the phone, a network that isolates clients or blocks Bonjour, and keys that change every launch (keeping a private key would need a new exception to the secrets rule).

## Strings

| Where | English |
|---|---|
| TV countdown time | Starts in 5 |
| TV buttons | Cancel, Play now |
| Phone, sent through iCloud | Sent. Living Room plays it if Antuna opens there within a minute. |
| Menu row, TV not reachable | Plays if opened within a minute |
| Phone, canceled | Canceled. |
| Phone, too late | Living Room already has it. |

The offer's facts line ("Movie · Resumes at 40 min") goes with the offer.
