# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Settings.dc.html`, `TV-Settings-Delete.dc.html`, `TV-Settings-Preferences.dc.html` (tvOS); `iPad-Settings.dc.html`, `iPad-Settings-Delete.dc.html` (iPadOS, macOS); `iPhone-Settings.dc.html`, `iPhone-Settings-Detail.dc.html`, `iPhone-Settings-Delete.dc.html` (iOS); `TV-Onboard-SignIn.dc.html` (reused for Sign in on this Apple TV).

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the details while Save runs; the error line under the form; a source row while loading; the Stalker row and the waiting-for-iCloud row; the signed-out iCloud footer; the "not loaded yet" status block and its failed variant; the M3U details form; the Preferences and About panes on iPad and Mac; the iPhone preference option screen; the Apple TV preference option list; the Sign in on this Apple TV form; iPhone edit mode with drag handles.

## Goals / Non-Goals

**Goals:**
- One app-layer loader keeps every source loaded and the guide fed, and its per-source states drive the status lines.
- Source screens, the loading loop and preferences ship as one change because the status lines and actions are the loop's states and calls.

**Non-Goals:**
- Keeping channel lists between launches.
- A separate Refresh guide action, unless the implementation finds a reason for one.

## Decisions

- The agreed texts are under Copy below: status lines, the delete confirmation, the iCloud footer and the preference option lists. Error sentences are the ones change `add-first-run-onboarding` uses. Use them.
- Source loading lives in an app-layer `SourceRefresher` that loads one source at a time in the user's order, tags each channel with its source, rebuilds the catalogue after each source, and calls the guide store in the order `guide-data` sets. `channel-catalogue` and `guide-data` wait on it, and several screens read its per-source states.
- Xtream loads call account info, then categories, then streams. An account failure stops the load.
- Load results are never written to the source record. This supersedes the `source-management` behavior. The last successful load time per source lives in this device's `UserDefaults.standard` under `settings.lastLoad.<sourceId>`, never in SwiftData or iCloud. At launch every source loads whatever its age. The schedule applies only to sources already loaded in this process.
- Changes this device made are handled once. The store observer ignores a deletion it already handled and a link change whose load is already running. A save on a loading source cancels that load first.
- Deleting a source deletes its Keychain item and its favorite records and calls the guide store's remove once. A source removed by sync deletes the Keychain item on this device but never the favorites, which the deleting device already removed. Keychain errors log only the source id and the status code.
- Preferences record (pending the storage decision): a new kind of synced record, so every field is defaulted and nothing is unique. On duplicates the newest is read and the rest deleted; at equal times the record with the smaller id is kept. Showing preferences inserts nothing.
- Large-source targets: a 50 000-channel M3U parses, tags and builds within 10 seconds in debug CI, off the main thread. A request is canceled after 30 seconds.
- A channel that disappears from a reloaded source keeps playing until the user tunes elsewhere.
- No source link or host appears in a row, label or identifier. Log lines use the `redacted(_:)` helper from `guide-data`.

## Copy

Counts use the locale's grouping separator. Relative times use `Date.RelativeFormatStyle` in the named style ("12 minutes ago", "yesterday").

Source row status line:

| State | Text |
|---|---|
| Loaded | "412 channels · Guide 7 days · 12 minutes ago" |
| First load, never loaded on this device | "Loading…" with an indeterminate indicator |
| First load of this launch, loaded before on this device | "Loading… · last loaded <relative time>" with the indicator |
| Reloading | "412 channels · Refreshing…" with the indicator |
| Failed, never loaded | the `add-first-run-onboarding` error sentence, error style |
| Failed after a load | the loaded line with the time of the last success, and below it "Could not refresh: <sentence>" in the error style, for example "Could not refresh: You're offline. Connect to the internet and try again." |
| Xtream login not on this device | "Waiting for login from iCloud"; on Apple TV "Not signed in on this Apple TV"; muted |
| Record arrived without its link | "Waiting for iCloud…"; details offer Delete source only |
| Stalker portal | "Stalker portals are coming later"; details offer Name and Delete source only |

Guide part of the loaded line:

| Guide | Text |
|---|---|
| No guide link for the source | "No guide" |
| Not started | "Loading guide…" |
| Downloading | "Downloading guide…" |
| Loaded | "Guide <n> days" |
| Failed, never loaded on this device | "Guide failed" |
| Failed after a load on this device | "Guide <n> days" from the last load |

Each row also shows the source name and a type badge, "M3U" or "XTREAM".

Details status block, one line each:
- "412 channels in 18 groups"
- "Guide for 7 days · 388 of 412 channels"
- "Refreshed 12 minutes ago"
- "Account active until <date, locale long style> · 2 connections", Xtream only, with missing values handled as in `add-first-run-onboarding`
- After a failed reload, the lines of the last success plus "Could not refresh: <sentence>" last. A failure with no earlier load shows the sentence alone. A source not loaded yet reads "Not loaded yet".

Details form:
- The Xtream password field is empty, secure, with the placeholder "••••••••". Leaving it empty keeps the saved password.
- Apple TV, login not on this device: a "Sign in on this Apple TV" button above empty username and password fields. Other platforms show the empty fields without the button.
- Errors under the form: "Enter a valid URL." for text without a scheme; "This source is already added." for a duplicate; "Enter your username and password." when no login exists on this device and either field is empty; otherwise the `add-first-run-onboarding` sentence for the failure, or the Keychain write message from `source-management`.
- A duplicate is another source of the same type with the same link, compared after trimming whitespace and one trailing slash and lower-casing scheme and host. For Xtream it must also have the same username in its Keychain item on this device; a different username, or an unreadable or missing item, is not a duplicate.
- An emptied name is replaced by the link's host.

Delete confirmation:
- Title: "Delete <name>?"
- Body: "Removes its 412 channels, 3 favorites and guide from every device signed in to your iCloud account."
- The favorites clause is left out at 0 favorites, the channels clause when the source never loaded, and the ending reads "from this device." when not signed in to iCloud.
- Buttons Delete and Cancel. Cancel has focus on Apple TV.

iCloud footer under the source list:
- Signed in: "Sources sync to your other devices through iCloud. Logins sync through iCloud Keychain when it is on, and never to Apple TV."
- Signed out: "Not signed in to iCloud. Sources stay on this device."

Preferences, defaults first:

| Row | Options | Default |
|---|---|---|
| Open on launch | Live, Guide, Movies | Live |
| Guide window | 2 hours, 3 hours, 4 hours | 2 hours |
| Refresh sources | Every 6 hours, Every 12 hours, Every 24 hours, Only manually | Every 12 hours |
| Swipe up or down (Apple TV only) | Changes channel, Shows the zap bar | Changes channel |

Movies is offered only where change `add-movies-and-series-browsing` shows the Movies section; a stored Movies value falls back to Live without a write. Open on launch takes effect after the launch tune selects the channel.

About: "Version <CFBundleShortVersionString> (<CFBundleVersion>)".

## Risks / Trade-offs

- Open question: synced preferences (assumed) or kept per device? The refresh interval and the Apple TV swipe setting are per device in nature. The answer changes where the preference values are stored, not what the user sees on this device.
- Open question: leaving edited details discards changes without asking. A "Discard changes?" prompt can be decided during implementation.
- Open question: the link field shows an M3U link in full, including any password in it, so VoiceOver reads it aloud. Masking it until edited can be decided during implementation.
- [One change covers screens, loader and preferences, so the work may be large] → split into several PRs before implementation if needed.
