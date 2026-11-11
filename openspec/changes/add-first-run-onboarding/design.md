# Design

## Context

See proposal.md for why. Onboarding replaces the empty Channels tab from `source-management` when there are no sources.

Boards, under `openspec/specs/design-system/boards/`:
- tvOS: `TV-Onboard-1.dc.html`, `TV-Onboard-2.dc.html`, `TV-Onboard-3.dc.html`, `TV-Onboard-3-M3U.dc.html`, `TV-Onboard-3-Connecting.dc.html`, `TV-Onboard-SignIn.dc.html`, `TV-Onboard-Help.dc.html`, `TV-Onboard-4.dc.html`, `TV-Onboard-4-NoLive.dc.html`, `TV-Onboard-4-Empty.dc.html`, `TV-Onboard-5.dc.html`, `TV-Onboard-5-Two.dc.html`.
- iOS: `iPhone-Onboard-1.dc.html`, `iPhone-Onboard-Help.dc.html`, `iPhone-Onboard-2.dc.html`, `iPhone-Onboard-2-M3U.dc.html`, `iPhone-Onboard-2-Connecting.dc.html`, `iPhone-Onboard-2-NoLink.dc.html`, `iPhone-Onboard-3.dc.html`, `iPhone-Onboard-3-NoLive.dc.html`, `iPhone-Onboard-3-Empty.dc.html`, `iPhone-Onboard-3-Two.dc.html`. iPad and Mac show the same sheet centered.

Not drawn: the guide line done and failed, the movies line after it stops waiting for counts, account lines without an expiry date or screen count, and the tvOS "Reading the guide…" line.

Design-system requirements that apply: “Focus is the lifted white card”, “One accent color”, “Text stays above the platform caption floor”, “Targets are large enough to hit”, “Accessibility identifiers follow the board”, “Nothing fake and nothing bundled”, “Nothing shows before the paywall”, “Loading shows real progress per step”.

On Apple TV the user sees the welcome screen, picks M3U or Xtream and fills in the details, chooses Connect, and watches the checklist fill in. Start watching becomes available once channels are in. The last screen sums up what was added while the first channel plays behind it, with Start watching and Add another source.

On iPhone, iPad and Mac the user sees a welcome sheet, then one sheet with the provider type, the fields and the clipboard banner. Connect moves to the checklist sheet, and Start watching opens Live with the first channel playing.

## Goals / Non-Goals

**Goals:**
- One fetch at Connect feeds both the check and the checklist.
- Validation and save go through the same code path as adding a source in Settings.

**Non-Goals:**
- The purchase flow, Stalker portals, file import, editing or deleting providers, per-provider guide toggles, several guides per playlist and background refresh. See proposal.md.

## Decisions

- Error messages, checklist wording and summary tile rules are in Copy below. Fixed captions on the boards are copy to match.
- Connect fetches once and the checklist reuses that response.
- An absent or empty Xtream `user_info.status` counts as active. A rejected login is the Xtream client's unauthorized error.
- The movies line stops waiting 20 seconds after login and reads "Movies and series available" without counts.
- The first channel is the lowest-numbered channel of the first source group in `channel-catalogue` order, skipping Favorites and All channels. The tvOS summary and Start watching use the same channel.
- Clipboard detection uses pattern detection for a probable web URL, which does not read the pasteboard. macOS shows no banner.
- tvOS sign-in writes under the record's `credentialKey` (its id when nil), skips Stalker records, names the sources still to sign in, and Menu on it suspends the app. Passwords never go in SwiftData or logs.
- Apple TV keeps passwords in its own Keychain and the sign-in screen is the way in, until the decision on where an Apple TV password is kept chooses otherwise.
- Back from Add another source returns to the summary.
- Design deviations: “One accent color” accent on done markers, the clipboard banner and the tvOS ready eyebrow; “Targets are large enough to hit” show-password control with a 44 pt hit area; “Nothing fake and nothing bundled” the tvOS keyboard card describes the continuity keyboard generically.

## Copy

Exact strings. `<...>` is a value filled in at runtime. Counts use the locale's grouping separator, so the examples read as in sv-SE.

### Welcome, type step and form

- Welcome title "Welcome to Antenna". Help headings "M3U playlist" and "Xtream login".
- The Stalker card has the accessibility label "Stalker portal, coming later" and the not-enabled trait. On tvOS it takes focus and select does nothing. On iOS the segment reads "Stalker" and the caption under the picker reads "Stalker portals are coming later".
- M3U fields: Name (optional), Playlist URL, Guide URL (optional). On iPhone, iPad and Mac the row labels are "Playlist" and "Guide", and Guide has the placeholder "Optional XMLTV link".
- Xtream fields: Name (optional), Server, Username, Password, with a control that shows or hides the password.
- The add-source sheet title is "Add a source".
- Clipboard banner "A link is on the clipboard" with Fill in, and "No link on the clipboard" after Fill in finds none. A link with `username` and `password` query items picks Xtream and fills Server (scheme, host and port), Username and Password. Any other link picks M3U and fills Playlist URL.

### Errors under the form

Shown as `onboarding.error` in the error style (15 pt on iOS, 22 pt on tvOS, `#FF5F57`). Nothing is saved and the fields keep their values.

| Case | Message |
|------|---------|
| A required field is empty (the first one in form order; no request is made) | "Enter the <field name>." with "server address", "username", "password" or "playlist URL" |
| The URL or server is not valid | The `source-management` validation message |
| The Xtream client throws its unauthorized error | "Could not sign in. Check the username and password." |
| `user_info.status` is present, not empty and not "Active" (case-insensitive) | "This account is <status in lowercase>." |
| `URLError` `.notConnectedToInternet`, `.networkConnectionLost` or `.dataNotAllowed`, also inside the Xtream client's transport error | "You're offline. Connect to the internet and try again." |
| Any other `URLError` | "Could not reach <host>. Check the address and try again." |
| The server answers non-2xx other than 401 or 403, or the playlist answers any non-2xx | "The server answered with an error (<status>). Check the address and try again." |
| The account reply throws `DecodingError` | "The server replied with something Antenna could not read." |

While Connect runs it is disabled and shows an indeterminate indicator, a second press sends nothing, and Back or Menu cancels the request and keeps the values.

### Checklist lines

The loading step is titled "Setting up <source name>".

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

The title is "Sign in on this Apple TV". Server is filled from the record with the lowest `sortOrder`, Username and Password are empty. A muted line reads "<n> more source(s) to sign in after this one: <names in sortOrder>" and is absent for the last record. Connect runs the same checks and messages as the form.

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
