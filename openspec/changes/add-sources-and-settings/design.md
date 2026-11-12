# Design

## Context

Boards: `openspec/specs/design-system/boards/TV-Settings.dc.html`, `TV-Settings-Delete.dc.html`, `TV-Settings-Preferences.dc.html` (tvOS); `iPad-Settings.dc.html`, `iPad-Settings-Delete.dc.html` (iPadOS, macOS); `iPhone-Settings.dc.html`, `iPhone-Settings-Detail.dc.html`, `iPhone-Settings-Delete.dc.html` (iOS); `TV-Onboard-SignIn.dc.html` (reused for Sign in on this Apple TV).

Design-system requirements that apply: "Live video keeps playing under overlays", "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Targets are large enough to hit", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled", "Text meets contrast minimums", "Nothing shows before the paywall", "Loading shows real progress per step".

Not drawn yet: the details while Save runs; the error line under the form; a source row while loading; the waiting-for-iCloud row; the Stalker portal details form; the signed-out iCloud footer; the "not loaded yet" status block and its failed variant; the M3U details form; the Preferences and About panes on iPad and Mac; the iPhone preference option screen; the Apple TV preference option list; the Sign in on this Apple TV form; iPhone edit mode with drag handles.

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

A Stalker portal shows the same states as an Xtream source, with its MAC address standing in for the login.

Guide part of the loaded line:

| Guide | Text |
|---|---|
| No guide link for the source | "No guide" |
| Not started | "Loading guide…" |
| Downloading | "Downloading guide…" |
| Loaded | "Guide <n> days" |
| Failed, never loaded on this device | "Guide failed" |
| Failed after a load on this device | "Guide <n> days" from the last load |

Each row also shows the source name and a type badge, "M3U", "XTREAM", "STALKER" or "JELLYFIN".

A Jellyfin server shows the same states as an Xtream source.

Details status block, one line each:
- "412 channels in 18 groups"
- "Guide for 7 days · 388 of 412 channels"
- "Refreshed 12 minutes ago"
- "Account active until <date, locale long style> · 2 connections", Xtream only, with missing values handled as in `add-first-run-onboarding`
- After a failed reload, the lines of the last success plus "Could not refresh: <sentence>" last. A failure with no earlier load shows the sentence alone. A source not loaded yet reads "Not loaded yet".

Details form:
- The Xtream password field is empty, secure, with the placeholder "••••••••". Leaving it empty keeps the saved password.
- A Stalker portal shows Portal, then a section headed "Login" with MAC address, Login (placeholder "Optional") and Password (placeholder "••••••••" when a password is saved, otherwise "Optional"). The MAC and login are filled from the Keychain item; the password field starts empty and leaving it empty keeps the saved one.
- A Jellyfin server shows Server, then Username and Password as for Xtream, the password empty with the placeholder "••••••••".
- Apple TV, login not on this device: a "Sign in on this Apple TV" button above empty username and password fields, or empty MAC address, login and password fields for a portal. Other platforms show the empty fields without the button.
- Errors under the form: "Enter a valid URL." for text without a scheme; "This source is already added." for a duplicate; "Enter your username and password." when the username is empty, or when no login exists on this device and the password is empty; "Enter the MAC address." for a portal with the MAC field empty, and "Enter a valid MAC address, like 00:1A:79:12:34:56." when it does not parse; otherwise the `add-first-run-onboarding` sentence for the failure, or the Keychain write message from `source-management`.
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

## Implementation decisions

- `SourceRefresher` is one app-wide object in the environment. It does not build channels itself: Live on iPhone, iPad and Mac and the Apple TV shell keep assembling their catalogue, and load each source through the refresher, which runs one load at a time in the order asked, gives up after 30 seconds and records each source's status. Moving the catalogue out of both screen models was larger than this change needed, and the models already handle sync changes, reordering and late logins.
- Refresh now, Refresh all and the schedule ask the screen that holds the channels to load sources again, through a closure that screen registers with the refresher. A source being refreshed keeps its channels and its loaded state while it loads and when the load fails. Coming back to the front also loads again every source that added nothing, which covers a launch while offline.
- A rename no longer loads a source again: only its kind, link, guide link or credential key does. This narrows the `source-management` rule that a name change reloads, as the modified requirement here says.
- The last successful load time is kept in `UserDefaults` under `settings.lastLoad.<sourceId>` as a JSON date. The schedule looks only at sources loaded in this run of the app.
- The guide part of a row follows the guide store's progress events.
- The Xtream account line is left out of the details. The loader asks for categories and streams only, and adding the account call to every load is left for a later change; Connect in onboarding still checks the account.
- A failed load shows the onboarding sentence for its error. A playlist's bad status maps to the server error sentence.
- Saving details with a changed link or login asks the server once through `SourceConnector.probe`, the check onboarding's Connect makes, and saves nothing when it fails. The name and guide link save without a check. A duplicate is checked before the server is asked.
- Delete removes the record, its Keychain item, its favorites in every profile, its watch history, its guide and its last load time. A deleted source's playing channel stops in Live and in the shell. A source deleted on another device is removed by the screens as before; its Keychain item on this device is not deleted yet.
- The confirmation is an alert with Delete and Cancel. It is shared by the swipe on iPhone and iPad and by Delete source in the details on every platform.
- Every platform shows Sources and Settings as one list with the details pushed on a navigation stack. The two-column layouts on iPad, Mac and Apple TV in the boards are not built yet; the rows, details, buttons and copy follow the boards.
- Reordering is drag in edit mode on iPhone and iPad and Move up and Move down in the details on Apple TV. Each move rewrites every source's sort order, so two devices converge on one order.
- Preferences live in a new synced `PreferencesRecord`, every field defaulted, as the change assumes. Several records resolve to the newest, and at equal times the smaller id, and the others are deleted when read. Showing preferences inserts nothing; the first change inserts the record.
- Open on launch applies when the tabs, the sidebar or the shell first appear, after onboarding's own request if there is one. A stored Movies falls back to Live where Movies is not offered. Refresh sources sets the schedule. The Apple TV swipe preference makes a swipe up or down on the picture show the info bar instead of changing channel.
- Guide window sets how many hours the Apple TV guide grid shows. The grid keeps its 1480 pt width and fits four, six or eight half-hour columns into it, so blocks get narrower as the hours grow. It still opens 90 minutes back. A change made in Settings or synced from another device redraws the open grid, and the window moves back inside the guide or along to keep the highlighted block in view.
- Guide window does not change the guide on iPhone, iPad or Mac. The iPad and Mac grid already has zoom, kept per device, and its hours depend on how wide the window is; the iPhone guide is one row of cards per channel with no time window. The `sources-and-settings` requirement says how many hours "the guide" shows without naming a device, and `add-tv-guide-grid` is the only guide with a fixed window, so the setting drives that one. `add-tv-guide-grid`'s design.md still says four columns show two hours; that is now the default. The row stays in Settings on every device because preferences sync, and choosing it on an iPhone changes the Apple TV guide.
- Add a source in Settings opens onboarding's form and checklist in a sheet; Start watching closes the sheet.
- Settings UI tests run on the scripted Live sources, which now load through the app's refresher so the rows show real states.
- Open on launch and the session restore from `add-session-restore-and-recently-watched` both pick the first tab. The restored tab comes first, and a preference other than Live then replaces it, so Live as the default keeps the restore. The two specs disagree on this; the order here is a stopgap until one of them settles it.
- Stalker portals load like the other sources now that `add-stalker-portal-source` is archived, so their rows show the refresher's states and the "Stalker portals are coming later" line and its status case are gone. Their details edit the portal address, the MAC address and the optional login and password, and a change to any of them signs in to the portal through `SourceConnector.probe` before it saves, as a changed Xtream login does. The Keychain item keeps the MAC in `username` and the login in `login`.
- Sign in on this Apple TV covers portals too. Every source with a login now has one, so the "Its login cannot reach this Apple TV." line is gone.
- A portal duplicate is another portal at the same address with the same MAC address in its Keychain item on this device, the rule Xtream uses for its username.
- An Xtream source always needs a username and a password, since the provider issues both; M3U links need neither. The `source-management` spec said blank fields were saved as typed, which no form allowed by then. Onboarding and the Settings add-source form share one field check. The details form now refuses an emptied username too, and a password of only spaces counts as empty. Sign in with Apple cannot stand in for this login, because it is the provider's account, not the user's Apple ID.
- Jellyfin servers load like the other sources. Their details edit the address, username and password, and a change to any of them goes through `SourceConnector.probe`, which checks the server and signs in before it saves. Sign in on this Apple TV asks a Jellyfin server for a username and password. A Jellyfin duplicate is another Jellyfin server at the same address with the same username in its Keychain item on this device, the Xtream rule.
- Deleting a Jellyfin server also clears this device's sign-in key for it.
- Channels DVR servers (`add-channels-dvr-source`) list with the badge "CHANNELS DVR" and the refresher's states. Their details edit the server address, labeled "Server", tidied the way onboarding tidies it, and a changed address is checked with the server's status and lineup before it saves. They have no login fields yet and never show Sign in on this Apple TV.
