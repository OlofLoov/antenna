# 0006. First-run onboarding and add-source flow

- Status: Accepted
- Date: 2026-11-03
- Depends on ADRs: 0001, 0002, 0003, 0005, 0006
- Builds on specs: 0004, 0010, 0013, 0014, 0015, 0016
- Platforms: iOS, iPadOS, macOS, tvOS
- User stories: US-1, US-2, US-7
- Follow-up ADR (before the implementing PR): ADR-0003 assumes passwords sync through iCloud Keychain, which Apple TV does not offer. Until that ADR is amended, this spec assumes a password typed on an Apple TV stays on that Apple TV (AC-21 and the tvOS wording on the boards). If the amendment picks another store, AC-21 and that wording follow it.

## Summary

This is for someone who has just paid for Antenna and has nothing in it yet. Instead of an empty screen, Antenna asks for their TV provider's details, checks them, shows what it found while it loads, and starts playing the first channel without waiting for the whole guide. They can add a second provider before they start watching. On Apple TV, a provider added on another device arrives without its password, so the user signs in once more on the TV. It does not cover the purchase itself, editing or removing a provider later, or Stalker portals (an older login-based provider type), which are shown as coming later.

## Design

Boards: `docs/design/boards/TV-Onboard-1.dc.html`, `TV-Onboard-2.dc.html`, `TV-Onboard-3.dc.html`, `TV-Onboard-3-M3U.dc.html`, `TV-Onboard-3-Connecting.dc.html`, `TV-Onboard-SignIn.dc.html`, `TV-Onboard-Help.dc.html`, `TV-Onboard-4.dc.html`, `TV-Onboard-4-NoLive.dc.html`, `TV-Onboard-4-Empty.dc.html`, `TV-Onboard-5.dc.html`, `TV-Onboard-5-Two.dc.html` (tvOS); `iPhone-Onboard-1.dc.html`, `iPhone-Onboard-Help.dc.html`, `iPhone-Onboard-2.dc.html`, `iPhone-Onboard-2-M3U.dc.html`, `iPhone-Onboard-2-Connecting.dc.html`, `iPhone-Onboard-2-NoLink.dc.html`, `iPhone-Onboard-3.dc.html`, `iPhone-Onboard-3-NoLive.dc.html`, `iPhone-Onboard-3-Empty.dc.html`, `iPhone-Onboard-3-Two.dc.html` (iOS; iPad and Mac show the same sheet centered).
Design rules that apply: DR-2, DR-3, DR-4, DR-5, DR-11, DR-12, DR-14, DR-15.
Not drawn: the guide line done and failed, the movies line after it stops waiting for counts, account lines without an expiry date or screen count, and the tvOS "Reading the guide…" line.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Today a new user opens Antenna and sees an empty Channels tab with a sentence pointing at Settings. People coming from TiviMate expect the app to ask for their playlist straight away, show what it found, and drop them into live TV. Adding a provider in Settings gives no feedback beyond the sheet closing, so the user cannot tell whether it worked.

## Scope

In:
- A welcome screen when the user has paid and has no provider yet, with a short "What is a source?" explanation.
- Two kinds of provider: an M3U playlist (a link to a channel list) or an Xtream login (server, username and password). Stalker portals appear but cannot be picked.
- Checking the details before anything is saved, and clear messages when the check fails.
- A checklist that fills in as channels, movies and the programme guide load, with real numbers.
- Watching before the guide has finished loading.
- On iPhone and iPad, offering to fill the form from a link the user has copied.
- Adding a second provider from the last step.
- On Apple TV, signing in again when providers synced from another device arrive without their passwords.

Out (explicitly):
- Buying Antenna (a separate spec under ADR-0006). Onboarding assumes the user has paid.
- Stalker portals.
- Importing a playlist file from the device.
- Editing or deleting a provider (0004 and a later spec).
- Turning off the programme guide for an Xtream provider.
- More than one guide per playlist.
- Refreshing providers later. Resuming a guide download after relaunch belongs to 0014.
- How playback itself behaves once the first channel starts (ADR-0001).

## User flow

Apple TV:
1. The welcome screen says no channels come with the app and offers Add a source and "What is a source?".
2. The user picks M3U playlist or Xtream login, fills in the details and chooses Connect.
3. A checklist shows each part loading. Start watching becomes available once the channels are in.
4. The last screen sums up what was added while the first channel already plays behind it. Start watching closes it; Add another source starts over.

iPhone, iPad, Mac:
1. A welcome sheet, then one sheet with the provider type, the fields, and a banner if a link is on the clipboard.
2. Connect moves to a sheet that shows the checklist as it fills in.
3. Start watching opens Live with the first channel playing.

## Acceptance criteria

### AC-1 A new user is asked for a provider
Given the user has paid and has added no provider
When they open Antenna
Then they see the welcome screen instead of an empty app, and Antenna has not contacted any server.

### AC-2 A returning user goes straight to their channels
Given the user has a provider whose password, if it needs one, is on this device
When they open Antenna
Then they see their channels and no onboarding.

### AC-6 Mistakes in the form are caught before connecting
Given the user has left a required field empty or typed an address that is not valid
When they choose Connect
Then a message under the form says what to fix, the same rules as adding a source in Settings (0004) apply, and nothing is sent to the server.

### AC-7 A failed connection says why and saves nothing
Given the server turns down the login, says the account is not active, answers with an error, sends back something Antenna cannot read or cannot be reached, or the device is offline
When the user chooses Connect
Then a message under the form says which of these happened, nothing is saved, the fields keep what the user typed, and they can try again.

### AC-9 A working provider is saved once
Given the Xtream login is accepted or the M3U playlist downloads
When the user chooses Connect
Then the provider is saved as in 0004, or reused if one with the same type and address exists, its password goes to the Keychain (Apple's secure password store), and the loading checklist appears.

### AC-10a The checklist shows real progress
Given the loading checklist is showing
When the login, playlist, channels, movies and guide finish or fail
Then each line turns done or failed with real numbers: live channels and groups, movies and series, guide days and how many channels have a guide, and when the account expires and how many screens it allows if the server says; the guide line shows its download progress while it runs.

### AC-14a A summary when everything has loaded
Given the loading checklist is showing
When every line is done or failed
Then the user sees a summary of what the provider added, leaving out anything that came to nothing or failed; on Apple TV the first channel is already playing behind it.

### AC-15 Start watching without waiting for the guide
Given the channels have loaded and the guide may still be loading
When the user chooses Start watching
Then onboarding closes, the first channel of the first group plays (full screen on Apple TV, in Live elsewhere), and the guide keeps loading in the background until it is done.

### AC-16a Add a second provider
Given the user is on the summary
When they add a second provider and it finishes loading
Then the summary names both providers and adds up their numbers, and the first provider's guide keeps downloading without starting over.

### AC-17a Fill the form from a copied link
Given the user has copied a link and the add-source sheet on iPhone or iPad offers to fill it in
When they tap Fill in
Then Antenna reads the clipboard only now; a link that carries a username and password fills the Xtream fields, any other link fills the playlist field, and if the clipboard holds no link the banner says so and nothing is filled.

### AC-21 Sign in again on an Apple TV
Given every provider is an Xtream login and none of their passwords is on this Apple TV
When the user opens Antenna on Apple TV
Then they are asked for the username and password of each provider in turn with the server already filled in, each password is kept on this Apple TV without adding a new provider, and after the last one the loading checklist appears.

### AC-32 A provider with no live channels
Given the provider connected but has no live channels
When the checklist finishes
Then if it has movies or series the user is offered Browse movies instead of Start watching; if it has nothing at all the only way on is back to the form, which removes what this attempt saved.

## Edge cases

- Offline or the server is down at Connect: AC-7.
- The guide is slow: the user starts watching and it finishes in the background (AC-15).
- No guide at all (a playlist without a guide link, or an Xtream account without one): no guide line, and the summary does not mention a guide.
- A very large Xtream account whose movie list is slow: the movies line stops waiting for numbers and the summary leaves them out.
- The same provider added on another device meanwhile: AC-9 keeps it from appearing twice.
- The purchase lapses during onboarding: the purchase screen replaces onboarding and a saved provider stays saved.
- Not signed into iCloud: the note that providers sync through iCloud is hidden.
- The password cannot be saved to the Keychain: as in 0004.
- A saved provider with no channels after a relaunch: the empty Apple TV home of 0015, the empty Live screen of 0010 elsewhere.
- Largest accessibility text size: the form scrolls and Connect stays reachable.
- Leaving during loading after the provider was saved: the next launch opens on the channels (AC-2).
- On iPhone, iPad and Mac, providers whose password has not reached this device yet: onboarding is not shown; Live shows the waiting-for-password state of 0010.
- Menu on the Apple TV welcome screen leaves the app, as the system does by default.
- VoiceOver reads each checklist line as one item: its state, title and detail.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | ui |
| AC-2 | integration |
| AC-6 | integration |
| AC-7 | integration |
| AC-9 | integration |
| AC-10a | integration |
| AC-14a | integration |
| AC-15 | ui |
| AC-16a | integration |
| AC-17a | integration |
| AC-21 | integration |
| AC-32 | integration |

## Open questions

- Decided: Apple TV keeps passwords in its own Keychain and AC-21 is the sign-in path, until the follow-up ADR in the header chooses otherwise.
- Should Fill in understand provider messages that contain more than a single link? Can be decided in the plan.

## Notes for the plan

- The exact error messages, checklist wording and summary tile rules are in this spec as accepted at c758aa4; carry them over. Fixed captions on the boards are copy to match.
- Connect fetches once; the checklist reuses that response. Validation and save go through the 0004 code path.
- Onboarding replaces 0004's empty Channels tab when there are no sources.
- An absent or empty Xtream `user_info.status` counts as active. A rejected login is 0016's unauthorized error.
- The movies line stops waiting 20 seconds after login and reads "Movies and series available" without counts.
- First channel: lowest-numbered channel of the first source group in 0013 order, skipping Favorites and All channels. The tvOS summary and Start watching use the same channel.
- Clipboard: detect a probable web URL with pattern detection, which does not read the pasteboard; no banner on macOS.
- tvOS sign-in writes under the record's `credentialKey` (its id when nil), skips Stalker records, names the sources still to sign in, and Menu on it suspends the app. Passwords never go in SwiftData or logs (ADR-0003).
- Design deviations: DR-3 accent on done markers, the clipboard banner and the tvOS ready eyebrow; DR-5 show-password control with a 44 pt hit area; DR-12 the tvOS keyboard card describes the continuity keyboard generically.

## Dropped

- Moved to the implementation plan: AC-3, AC-4a, AC-4b, AC-5, AC-18, AC-19a, AC-19b, AC-25, AC-28, AC-30, AC-34, AC-35.
- Merged into AC-2: AC-20.
- Merged into AC-6: AC-31.
- Merged into AC-7: AC-8, AC-23, AC-26, AC-29, AC-33.
- Merged into AC-9: AC-24.
- Merged into AC-10a: AC-10b, AC-11, AC-12a, AC-12b, AC-12c.
- Merged into AC-14a: AC-14b, AC-27.
- Merged into AC-15: AC-13, AC-22.
- Merged into AC-16a: AC-16b, AC-16c.
- Merged into AC-17a: AC-17b, AC-17c, AC-17d.
- From the old AC-16a, Back from Add another source returning to the summary: moved to the implementation plan.
