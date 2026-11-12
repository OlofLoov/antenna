# Design

## Context

See proposal.md for why. Onboarding replaces the empty Channels tab from `source-management` when there are no sources.

Boards, under `openspec/specs/design-system/boards/`:
- tvOS: `TV-Onboard-1.dc.html`, `TV-Onboard-2.dc.html`, `TV-Onboard-3.dc.html`, `TV-Onboard-3-M3U.dc.html`, `TV-Onboard-3-Connecting.dc.html`, `TV-Onboard-SignIn.dc.html`, `TV-Onboard-Help.dc.html`, `TV-Onboard-4.dc.html`, `TV-Onboard-4-NoLive.dc.html`, `TV-Onboard-4-Empty.dc.html`, `TV-Onboard-5.dc.html`, `TV-Onboard-5-Two.dc.html`.
- iOS: `iPhone-Onboard-1.dc.html`, `iPhone-Onboard-Help.dc.html`, `iPhone-Onboard-2.dc.html`, `iPhone-Onboard-2-M3U.dc.html`, `iPhone-Onboard-2-Connecting.dc.html`, `iPhone-Onboard-2-NoLink.dc.html`, `iPhone-Onboard-3.dc.html`, `iPhone-Onboard-3-NoLive.dc.html`, `iPhone-Onboard-3-Empty.dc.html`, `iPhone-Onboard-3-Two.dc.html`. iPad and Mac show the same sheet centered.

Not drawn: the Stalker portal form and the Apple TV sign-in for a portal, which follow the Xtream boards with the fields under Copy; the guide line done and failed, the movies line after it stops waiting for counts, account lines without an expiry date or screen count, and the tvOS "Reading the guide…" line.

Design-system requirements that apply: “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Nothing shows before the paywall”, “Loading shows real progress per step”.

On Apple TV the user sees the welcome screen, picks M3U, Xtream or Stalker and fills in the details, chooses Connect, and watches the checklist fill in. Start watching becomes available once channels are in. The last screen sums up what was added while the first channel plays behind it, with Start watching and Add another source.

On iPhone, iPad and Mac the user sees a welcome sheet, then one sheet with the provider type, the fields and the clipboard banner. Connect moves to the checklist sheet, and Start watching opens Live with the first channel playing.

## Goals / Non-Goals

**Goals:**
- One fetch at Connect feeds both the check and the checklist.
- Validation and save go through the same code path as adding a source in Settings.

**Non-Goals:**
- The purchase flow, file import, editing or deleting providers, per-provider guide toggles, several guides per playlist and background refresh. See proposal.md.

## Decisions

- Error messages, checklist wording and summary tile rules are in Copy below. Fixed captions on the boards are copy to match.
- Connect fetches once and the checklist reuses that response.
- An absent or empty Xtream `user_info.status` counts as active. A rejected login is the Xtream client's unauthorized error.
- The movies line stops waiting 20 seconds after login and reads "Movies and series available" without counts.
- The first channel is the lowest-numbered channel of the first source group in `channel-catalogue` order, skipping Favorites and All channels. The tvOS summary and Start watching use the same channel.
- Clipboard detection uses pattern detection for a probable web URL, which does not read the pasteboard. macOS shows no banner.
- tvOS sign-in writes under the record's `credentialKey` (its id when nil), asks a Stalker record for its MAC address, names the sources still to sign in, and Menu on it suspends the app. Passwords never go in SwiftData or logs.
- Apple TV keeps passwords in its own Keychain and the sign-in screen is the way in, until the decision on where an Apple TV password is kept chooses otherwise.
- Back from Add another source returns to the summary.
- Design deviations: “One accent color” accent on done markers, the clipboard banner and the tvOS ready eyebrow; “Targets are large enough to hit” show-password control with a 44 pt hit area; “Nothing fake and nothing bundled” the tvOS keyboard card describes the continuity keyboard generically.

## Copy

Exact strings. `<...>` is a value filled in at runtime. Counts use the locale's grouping separator, so the examples read as in sv-SE.

### Welcome, type step and form

- Welcome title "Welcome to Antenna". Help headings "M3U playlist" and "Xtream login".
- The Stalker card reads "Stalker portal" with "A portal address and a MAC address, the way a MAG box signs in." and the footnote "Also called Ministra". On iOS the segment reads "Stalker" and has no caption under the picker. Both open the portal form like the other two kinds.
- Stalker fields: Name (optional), Portal, MAC address, Login (optional), Password (optional). On iPhone, iPad and Mac the group is headed "Portal", the row labels are "Portal", "MAC", "Login" and "Password", Portal has the placeholder "http://", MAC "00:1A:79:12:34:56", and Login and Password "Optional". On Apple TV the title is "Stalker portal" and the line under it reads "Copy these from the email or page your provider sent you. Leave the login empty unless your provider gave you one." The Keychain line is the Xtream one.
- The Jellyfin card reads "Jellyfin" with "Your own Jellyfin server's Live TV, signed in with your Jellyfin username and password." and the footnote "Live TV and guide from your server". On iOS the segment reads "Jellyfin". Apple TV shows the four cards narrower, in one row.
- Jellyfin fields: Name (optional), Server, Username, Password. On iPhone, iPad and Mac the group is headed "Server", the row labels are "Server", "Username" and "Password", and Server has the placeholder "http://jellyfin.local:8096". On Apple TV the title is "Jellyfin server" and the line under it reads "The address you open Jellyfin at in a browser, with the username and password you sign in with." The Keychain line is the Xtream one.
- M3U fields: Name (optional), Playlist URL, Guide URL (optional). On iPhone, iPad and Mac the row labels are "Playlist" and "Guide", and Guide has the placeholder "Optional XMLTV link".
- Xtream fields: Name (optional), Server, Username, Password, with a control that shows or hides the password.
- The add-source sheet title is "Add a source".
- Clipboard banner "A link is on the clipboard" with Fill in, and "No link on the clipboard" after Fill in finds none. A link with `username` and `password` query items picks Xtream and fills Server (scheme, host and port), Username and Password. Any other link picks M3U and fills Playlist URL.

### Errors under the form

Portal failures that are not in this list (offline, unreachable, a server error, an unreadable answer) use the rows below as they are.

Shown as `onboarding.error` in the error style (15 pt on iOS, 22 pt on tvOS, `#FF5F57`). Nothing is saved and the fields keep their values.

| Case | Message |
|------|---------|
| A required field is empty (the first one in form order; no request is made) | "Enter the <field name>." with "server address", "username", "password", "playlist URL", "portal address" or "MAC address" |
| The URL or server is not valid, or the portal address has no `http` or `https` | The `source-management` validation message |
| The MAC address is not six pairs of hex digits (no request is made) | "Enter a valid MAC address, like 00:1A:79:12:34:56." |
| The portal does not accept the MAC address or login | "Could not sign in. Check the MAC address, and the login if you have one." |
| The portal refuses the device with a message | "The portal refused this device with the message “<message>”." with the MAC replaced by "…" |
| No address the portal could be under answers as a portal | "No Stalker portal answered at <host>. Check the address and try again." |
| No Jellyfin server answers at the address (no password is sent) | "No Jellyfin server answered at <host>. Check the address and try again." |
| The Jellyfin server does not let this account sign in from this device | "This account is not allowed to sign in from this device." |
| The Jellyfin server's certificate cannot be verified | "Antenna can't verify this server's certificate. Use http on your network or a trusted certificate." |
| The Xtream client or the Jellyfin server turns the username and password down | "Could not sign in. Check the username and password." |
| `user_info.status` is present, not empty and not "Active" (case-insensitive) | "This account is <status in lowercase>." |
| `URLError` `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`, also inside the Xtream client's transport error | "You're offline. Connect to the internet and try again." |
| Any other `URLError` | "Could not reach <host>. Check the address and try again." |
| The server answers non-2xx other than 401 or 403, or the playlist answers any non-2xx | "The server answered with an error (<status>). Check the address and try again." |
| The account reply throws `DecodingError` | "The server replied with something Antenna could not read." |

While Connect runs it is disabled and shows an indeterminate indicator, a second press sends nothing, and Back or Menu cancels the request and keeps the values.

### Checklist lines

The loading step is titled "Setting up <source name>".

- Stalker portal: "Signed in" with the portal's host beneath, in place of the playlist line. A portal has no movies line.
- Jellyfin server: "Signed in" with the server's host beneath, in place of the playlist line. A Jellyfin server has no movies line and no guide line; its guide loads once onboarding closes.
- Login: "Signed in", with "Account active until <date in the locale's long style>" and " · 1 connection" or " · <n> connections" beneath. `exp_date` is Unix seconds as a number or a numeric string; absent, null, non-numeric or 0 leaves the date out. `max_connections` absent, non-numeric or 0 leaves out the connections. The line beneath shows only the parts that exist, joined by " · ": with no date it reads "1 connection" or "<n> connections" with no separator, and with neither part there is no line beneath "Signed in".
- Playlist (M3U only): "Playlist downloaded" with the host beneath. An M3U source has no login or movies line.
- Channels: "412 live channels in 18 groups", with the first eight group names and "and <n> more" beneath. Groups are the `channel-catalogue` groups without Favorites and All channels.
- Movies: "1 240 movies and 86 series" with "Posters and descriptions load as you browse" beneath. After the 20 second cutoff it reads "Movies and series available" and counts as done.
- Guide while downloading: an indeterminate bar and "Downloading the guide · <bytes as ByteCountFormatStyle with one decimal>". After the last byte, until the guide is loaded or failed: "Reading the guide…".
- Guide loaded: "Guide for 7 days · 388 of 412 channels" with a full bar.
- Guide failed: "Guide could not be loaded" in the error style, with no bar.
- No live channels but movies or series: the channels line reads "No live channels" in the muted style and Browse movies replaces Start watching and opens Movies.
- Nothing at all: the channels line reads "No channels found" in the error style and Start watching is disabled. On iPhone, iPad and Mac the sheet is headed "Nothing to watch yet", has Back in the navigation bar and no Add another source. Back cancels the guide download, deletes the source only if this Connect inserted it, deletes any Keychain item this Connect wrote, and returns to the form with its values.

Each line is one VoiceOver element that reads state, title and detail. The summary appears within one second of the last line turning done or failed.

### Summary

- tvOS: the eyebrow reads "<source name> added", or "<source name> signed in" after the Apple TV sign-in. The title is "You're set". The caption over the playing channel reads "Live · <number> <name>".
- tvOS tiles: channels (live channels with the group count), guide (days with the matched channel count), movies (movies plus series), catch-up (the most common catch-up days across channels with catch-up, or "Catch-up" when none has a day count, with the number of such channels). A tile whose value is zero is left out. The guide tile is left out when the guide failed or there is none, the movies tile after the 20 second cutoff. With no live channels the channels tile, the caption and the playing channel are absent and Browse movies replaces Start watching.
- iPhone, iPad and Mac: the sheet title is the source name (the `source-management` default name when the user gave none). The channels line reads "<n> live channels" over "<n> groups", the movies detail reads "In the Movies tab", the guide line is the checklist's, and there is no catch-up line.
- Two sources: the title reads "2 sources added". Channel, group, matched-channel, movie, series and catch-up channel counts are summed. Guide days and catch-up days take the larger source's value. The tvOS eyebrow joins the source names with " · ". iPhone, iPad and Mac show one section per source.

### Apple TV sign-in

The title is "Sign in on this Apple TV". Server is filled from the record with the lowest `sortOrder`, Username and Password are empty. For a Stalker portal the filled row is labeled "Portal" and the fields are MAC address, Login (optional) and Password (optional), all empty. A Jellyfin server asks for Username and Password like an Xtream login, with its address in the Server row. A muted line reads "<n> more source(s) to sign in after this one: <names in sortOrder>" and is absent for the last record. Connect runs the same checks and messages as the form.

## Risks / Trade-offs

- [The project rule is that secrets sync through iCloud Keychain, and Apple TV has no iCloud Keychain] → the Apple TV sign-in requirement covers it until a decision says where a password typed on an Apple TV is kept. The options are an encrypted CloudKit field in SwiftData, or the Keychain on that Apple TV with sign-in as the permanent path. The change is blocked on that decision.
- Open question: should Fill in understand provider messages that contain more than a single link? Can be decided during implementation.

## Implementation decisions

- `OnboardingGate` wraps the window root on every platform and shows onboarding while the store holds no source record. Any record opens the app, with or without its password and with or without channels, so the user who left during loading and the user whose password has not synced both land on their channels. Deleting the last source shows onboarding again. On Apple TV the gate sits outside the profile picker, so "Who's watching?" never shows before a source exists.
- The app behind the gate is not built while onboarding shows, so no source loads and no server is contacted. The guide store exists from launch but starts no download on its own.
- Paying is assumed. No entitlement exists until `add-paywall-and-entitlement` is built, so task 1.3 stays open.
- The iCloud note reads `FileManager.ubiquityIdentityToken` once when the welcome screen appears. On iPhone, iPad and Mac the note is the "Synced with iCloud" feature row; on Apple TV it is the line at the bottom. Both go when the device is not signed in.
- iPad and Mac show the iPhone welcome at most 520 pt wide, centered in the window, not a separate board.
- "What is a source?" is a sheet on iPhone, iPad and Mac and a full-screen cover on Apple TV, closed by Done.
- `-ui-testing-onboarding signedIn|signedOut` launches a Debug build on an empty in-memory store with the iCloud state scripted.
- The form rules, the failure sentences and the copied-link parsing are in AntennaCore (`SourceFields`, `ConnectFailure`, `CopiedLink`, `SourceLink`). `SourceConnector` in the app makes the one request and saves through `NewSource.save`, the path the Settings sheet uses.
- The form checks that the server, username and password are filled in before Connect. The `source-management` save path still stores blank values as typed, so the "Blank username or password" scenario holds for that path and not for this form.
- A provider counts as the same when its type matches and its link matches after dropping spaces and one trailing slash and lower-casing the scheme and host. A reused Xtream source gets the typed login written under its credential key, and a key is set on a record that synced without one.
- A Keychain item counts as written by this Connect only when none existed under that key before. Back from an empty provider deletes only such an item, so a login that synced from another device stays.
- A playlist answering 401 or 403 shows the server error message, because a playlist link has no login to reject.
- Fill in takes only a single http or https link. A provider message with text around the link counts as no link, which answers the open question for now.
- Apple TV moves through the steps in a `NavigationStack`, so Menu goes back one step and leaving the form cancels a running Connect. The boards' "Back" label and step dots are not drawn on Apple TV, since Menu is the way back. iPhone, iPad and Mac show the form in a sheet with Back in the navigation bar.
- The show-password control is on iPhone, iPad and Mac only. Apple TV uses the system secure field and its full-screen keyboard.
- `-ui-testing-clipboard <text>` stands in for the pasteboard in UI tests.
- Groups 3 and 4 ship in one pull request. Start watching closing onboarding is the checklist's main button, so the summary and the hand-over to the app cannot be tested apart.
- `OnboardingGate` owns the onboarding model and keeps onboarding up while a source connected in it is still on the checklist or summary, even after the store holds the source. Start watching or Browse movies closes it. Back from a provider with nothing also keeps it up, because the store's query sees the delete a moment later and would otherwise flash the app.
- The checklist reads each source through `SourceSetup`. The Connect reply is the playlist for M3U; for Xtream the checklist asks for categories and streams, then movies and series, which the account reply does not carry. Live and the shell load every source again once onboarding closes, so a playlist is downloaded a second time. Handing the loaded channels to Live is left to `add-sources-and-settings`, which adds the shared loader.
- The guide line follows the app's guide store: the checklist registers the source's guide links, gives it the channels and asks for stale guides, which leaves a running download alone. Adding a second source never restarts the first one's download, and closing onboarding cancels none of it. An Xtream source always has a guide line, because its guide link is built from the login; the line fails if the provider has none.
- When the channel request fails, the channels line reads "No channels found" in the error style, as when the provider sent none.
- A provider whose movie and series lists both come back empty shows "No movies or series" in the muted style.
- While the guide waits for its first byte the line reads "Downloading the guide" without a size.
- The indeterminate bar is a fixed accent segment, as drawn, so previews stay deterministic.
- iPhone, iPad and Mac show the checklist and the summary as one sheet. The heading reads "Setting up <name>" until the first live channels arrive, then "You're set". The subtitle reads "Everything has loaded." once every line finished. A provider with nothing reads "Nothing to watch yet" with "The playlist has no channels. Go back and check the link." for a playlist and "The provider sent no channels, movies or series. Go back and check the details." for an Xtream login.
- The Apple TV summary plays the first channel on an engine of its own. When Start watching closes onboarding, the shell tunes the same channel on its engine, so the picture restarts once.
- Start watching hands the first channel to the app through `OnboardingHandoff`, an `@Entry` value the gate sets. On iPhone, iPad and Mac Live plays it in place; on Apple TV the shell tunes it full screen. Browse movies opens the Movies tab or section.
- The Apple TV summary footnote reads "Not signed in to iCloud, so it stays on this Apple TV." when signed out, and leaves out the login sentence for a playlist.
- `-ui-testing-onboarding connect` answers Connect in the app with two fixture playlists, and `-ui-testing-playlist <link>` fills the Apple TV form, since typing with the remote from a UI test is unreliable.
- The Apple TV sign-in shows when every source is an Xtream login or a Stalker portal and none has its login on this Apple TV. Each login is checked with the server, the way Connect checks one, and kept in this device's Keychain under the record's credential key; a record that synced without a key gets one, its id. The sources start loading together after the last sign-in, and the summary's eyebrow reads "<name> signed in". The server shows as text, not a field. A Stalker source is signed in with its MAC address, checked the way Connect checks a portal.
- A source that already loaded on Apple TV but later lost its login is handled by Sign in on the playback error and in Settings, not by onboarding.
- Stalker portals are enabled now that `add-stalker-portal-source` is archived. The form keeps the MAC address in its own field of `SourceFields`; the Login and Password fields carry the optional portal login, so `check()` asks only for the portal and the MAC. A portal address that `stalker-portal-source` would turn down and a MAC that does not parse fail in `check()`, before any request. The Keychain item keeps the MAC in `username` and the login in `login`, as that change decided.
- The portal's "not authorized" answer gets its own sentence about the MAC address and login, since the Xtream one names a username the portal form does not have.
- The Stalker checklist has no guide line. Connect hands the portal's channels to the checklist, and the portal's own guide loads through the app's guide store once onboarding closes, the way it does for a portal added before. Account expiry from the portal is not shown, since the account call is not on the Connect path.
- The Stalker form and sign-in have no boards. They reuse the Xtream layout, rows and Keychain line, with the fields and copy above.
- Jellyfin servers are enabled in this change and `add-jellyfin-live-tv-source`. Connect asks `/System/Info/Public` first, so an address that is not a Jellyfin server fails before the password is sent, then signs in and loads the Live TV channels; Connect hands those channels to the checklist, as for a portal. The Keychain item keeps the username and password, as for Xtream, and the sign-in key stays in memory on each device until the per-device key decision exists.
- An address that answers the server check with something other than Jellyfin's answer, or with 404, reads as "No Jellyfin server answered". Any other failure uses the rows above.
- The Jellyfin form and sign-in have no boards. They reuse the Xtream layout, rows and Keychain line, with the fields and copy above. The Apple TV kind step shows four cards 400 points wide instead of three at 480, since four at 480 do not fit 1920.
- Channels DVR servers are added here by `add-channels-dvr-source`. The card reads "Channels DVR" with "The address of your Channels DVR server at home. Its channel numbers and guide come with it." and the footnote "A server on your home network"; the five Apple TV cards shrink to 340 points wide and 460 tall to fit 1920. On iOS the segment reads "Channels" with the accessibility label "Channels DVR", and the segment labels shrink to 70 percent to fit one line. The form has Name and Server (placeholder "192.168.1.20 or nas.local", URL keyboard). The Remote access username and password stay hidden until playback can send a password with streams, so no Keychain line shows and Connect saves no Keychain item. The checklist's first line is "Server" with "Channels DVR <version>". Failures use the `add-channels-dvr-source` wording, with the local network hint on iPhone, iPad and Mac. The Apple TV sign-in skips Channels DVR servers, since none has a password yet. No board draws the Channels DVR card or form.
