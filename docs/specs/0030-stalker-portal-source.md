# 0030. Stalker portal source: sign-in, channels and guide

- Status: Draft
- Date: 2026-11-04
- Depends on ADRs: 0001, 0003, 0005
- Blocked on: an ADR for a tune-time step in the playback path that turns a portal channel into a playable address, and an ADR that lets AntennaCore use Apple's CryptoKit for the device identity, widening 0005. AC-4 and AC-17 wait on them; the rest can be built.
- Builds on specs: 0003, 0004, 0013, 0014, 0016
- Needs from other specs: 0006, a revision that enables the Stalker card with Portal, MAC, Login and Password fields, wording for each Connect error, and Stalker sources in its Apple TV sign-in step; 0023, the same fields in its edit form; 0014, a path for a Stalker source without a guide address.
- Supersedes: 0004's "Stalker contributes no channels" behavior and its inert Stalker type, and 0006's disabled Stalker card.
- Platforms: iOS, iPadOS, macOS, tvOS (AntennaCore and the app's Keychain mapping; no UI)
- User stories: US-6, US-7

## Summary

Some IPTV providers give their customers a Stalker portal (also sold as Ministra): a web address plus the MAC address, a hardware id, that the provider registered for them. This spec teaches Antenna to sign in to such a portal, load its channels grouped by genre, play them, and read the portal's own programme guide. A user whose provider only offers a portal gets the same live TV as an Xtream user. It does not add movies, series, radio, catch-up or recordings from the portal, and it draws no screens: the add-source form is 0006 and 0023.

## Design

Boards: none, no UI. The add-source form belongs to 0006 and 0023.
Design rules that apply: none here. DR-8, DR-11 and DR-15 apply to the specs that render Stalker channels and the form.
Not drawn: nothing.

Layout, sizes, states and identifiers come from the boards and are settled in the implementation plan, not here.

## Problem

Antenna can save a Stalker source today but loads nothing from it, so a user whose provider only offers a portal sees an empty app after paying (ADR-0006). A portal is addressed by its URL and a MAC address, not by a playlist link or a username. It also hands out each stream address at the moment the user tunes, with a short-lived key in it, so Antenna cannot build stream addresses ahead of time the way it does for Xtream.

## Scope

In:
- Reading the MAC address the user types, in the forms providers write it.
- Accepting the portal address in the forms providers hand out.
- Signing in to the portal, with an optional login and password when the portal asks for one.
- Loading genres and channels into the catalogue.
- Asking the portal for a stream address each time the user tunes.
- Reading the portal's own programme guide for 0014.
- Renewing the portal's session key (a password the portal hands out for each sign-in) once when the portal stops accepting it.
- Errors that say what went wrong and never contain the MAC, login, password or session key.
- Keeping the MAC, login and password in the Keychain, with a login field the Keychain item gains.

Out (explicitly):
- Any screen. The form, its wording and the loading checklist are 0006 and 0023.
- Downloading, scheduling and size limits for the guide: 0014.
- Portals that hand out their channel list in pages.
- Movies, series and radio from the portal.
- Catch-up and timeshift: the catch-up spec.
- Recording, parental lock and messages from the portal.
- Playing the stream, and asking for a new address when one expires mid-stream: the playback spec.
- The screens for a source whose credential has not synced yet: 0006, 0010 and 0015 already cover them.
- A custom serial number or device id per source.
- Spotting an Xtream service behind the same portal.

## User flow

1. The user picks Stalker portal in the add-source form and enters the portal address, the MAC address from the provider and, if the portal asks, a login and password.
2. Connect finds the portal and signs in. If the portal refuses the device or cannot be reached, the reason shows under the form and nothing is saved.
3. On success the MAC, login and password go to the Keychain and the portal address to the source.
4. Channels appear in the catalogue grouped by the portal's genres, with the portal's channel numbers.
5. Tuning a channel asks the portal for a fresh stream address, which plays through the engine ADR-0001 picks.
6. The guide shows the portal's own programme data.
7. On iPhone, iPad and Mac the source waits for its MAC and login to arrive through iCloud Keychain. On Apple TV the user enters them once, which needs 0006's sign-in step to accept Stalker sources.

## Acceptance criteria

### AC-1 Type the MAC and portal address the way your provider wrote them
Given a user typing a MAC address with colons, with dashes, as twelve plain hex digits, in either case or with stray spaces around it, and a portal address
When the form checks them
Then every one of those MAC forms is accepted as the same MAC, written back as `00:1A:79:12:34:56`; a MAC with too few, too many or non-hex digits, or a portal address without `http` or `https` in front, is turned down so the form can say so.

### AC-3 Connect with the portal address you were given
Given a user with a portal address in any form a provider hands out (with or without a trailing `/c/`, under `/stalker_portal` or not, with a port) and, if the portal asks for one, a login and password
When the user taps Connect
Then Antenna finds the portal, signs in with the login when there is one, and saves the source under a tidied address, so the sources list shows the portal's host name.

### AC-3a Connect says why it failed
Given a portal that is offline, has a server error, refuses the device or its login, refuses the device with a message of its own, or is not a portal at all
When the user taps Connect
Then the app gets a different error for each case (no connection, server error, not authorized, device refused with the portal's message, no portal found), and a server outage is never reported as a wrong address.

### AC-4 Portals that remember your device still let you in
Given a MAC address that a portal has already tied to the device id of another player such as StbEmu or TiviMate
When Antenna signs in with that MAC
Then it sends the same serial number, device id and signature those players send for that MAC, so the portal accepts it.

### AC-9 Channels, guide and playback share one sign-in
Given a portal source that has not signed in yet in this session
When the channel loader, the guide or playback asks for something, even two of them at the same moment
Then Antenna signs in once, answers both, and reuses the same session for later requests.

### AC-10 An expired session renews itself once
Given a portal that has expired or replaced Antenna's session key, for example because another device signed in with the same MAC
When the portal turns down a request
Then Antenna signs in again once, repeats the request and returns the answer, even when several requests were turned down at the same time.

### AC-14 Channels show up grouped by genre
Given a portal with genres and channels
When the source loads
Then each channel appears with its name, the portal's channel number, its genre as the group, its logo, whether it has catch-up and for how many days, and an identity that stays the same across reloads, so favorites stick; the portal's catch-all "All" genre is not shown as a group, and channels with an unknown genre are listed as ungrouped.

### AC-17 Tuning gets a fresh stream address
Given a channel from a Stalker source
When the user tunes to it
Then Antenna asks the portal for that channel's stream address and hands back the playable address from the answer; a channel that is not from a portal, or an answer with no usable address, fails with an error and no address.

### AC-20 Secrets never show up in messages or logs
Given a source with a MAC, login, password, a session key, the device ids worked out from the MAC, a stream address handed back for tuning, and a portal message that contains the MAC
When any of these values, or any error, is printed or logged
Then none shows the MAC in any form, the login, the password, the session key, the device ids, a stream address, or the portal's port and path; the portal's message reads with the MAC replaced by "…", and the source prints as the portal's host name only.

### AC-23 The portal's guide fills the programme grid
Given a Stalker source with no separate guide address, and channels with and without an XMLTV id (the id guide files use)
When 0014 loads the portal's guide for up to seven days
Then programmes appear on the right channels, a channel without an XMLTV id still gets its programmes through the portal's own channel id, a guide address the user adds still matches by XMLTV id, and rows for unknown channels or with impossible times are counted rather than shown.

### AC-24 A broken answer is an error, not a crash
Given a portal answer that is an HTML login page, XML, empty, or a channel list with some broken rows
When Antenna reads it
Then an answer it cannot read becomes a reading error that quotes nothing from the answer, and broken channel or genre rows are skipped and counted while the rest load.

### AC-25 Your MAC and login stay in the Keychain
Given a Keychain item with a MAC, password and login, an item saved before this spec with only a MAC and password, and an item whose username is not a MAC
When the app reads each one for a Stalker source
Then the first gives all three, the second loads without a login so no login step runs, and the third counts as no credential; the MAC is kept only in the Keychain item, never in the synced source, a favorite, a channel id or a log.

## Edge cases

- Offline: every request fails as no connection; channels already loaded in this session stay in the catalogue.
- Two devices on one MAC: most portals cancel the other device's session, and each device renews its own on its next request (AC-10) at the cost of one round trip. If the repeat is turned down too, the request fails as not authorized with no third try. The portal may still refuse a second stream at the same time, which shows up in playback.
- The portal needs a login the user left empty: it refuses the device or sends an empty list, and 0006 tells the user to check the login.
- A portal with tens of thousands of channels sends them in one answer with no size cap; a slow link has five minutes before the request gives up.
- The first tune after launch signs in first, so it takes a few more round trips; a tune after the session expired takes one more round of those.
- Portals and stream hosts on plain `http` work; the app already allows them.

## Test plan

| Criterion | Layer |
|-----------|-------|
| AC-1 | core |
| AC-3 | core |
| AC-3a | core |
| AC-4 | core |
| AC-9 | core |
| AC-10 | core |
| AC-14 | core |
| AC-17 | core |
| AC-20 | core |
| AC-23 | core |
| AC-24 | core |
| AC-25 | integration |

## Open questions

- Does the StbEmu derivation (MD5 and SHA-256 of the MAC, `device_id2` equal to `device_id`, `hw_version_2` equal to the serial) match a real portal that locks device ids? Changes AC-4; check before Accepted.
- Ask the portal for a link on every tune even when it marks a channel as not needing one, or play the stored command directly? Can be decided in the plan.
- Is the portal's archive duration always in hours? Can be decided in the plan; the catch-up spec confirms against real portals.

## Notes for the plan

- The text of this spec before the trim (commit 19e8729) holds the wire detail: headers, the MAG250 user agent, query items per call, the `ver` and `metrics` literals, endpoint discovery order, and the expected device-identity values for `00:1A:79:12:34:56`. Start from it.
- The session key is never written to disk.
- Hand-offs to other specs: a portal channel never falls back to the normal stream route and shows the playback failure state when it cannot be resolved; zapping away cancels the address request; a `Channel`'s printed form hides its stream address, which can hold the MAC (ADR-0003).
- Tests use a `URLProtocol` stub that records requests in order, as 0003 and 0016; no test opens a network connection.
- A rejection is exactly 401, 403, a body of `Authorization failed.`, or JSON whose `js` is null, `""` or absent. `{"js":false}` is an empty answer, not a rejection.
- `Channel.streamURL` holds a `stalker://<host>/<id>?cmd=…` reference; `Channel.id` is `stalker#<host>#<id>` and never uses `cmd`. Playback picks the client by `Channel.sourceID`; the resolved URL is held for one tune and never stored or logged.
- The app keeps one client per source for the life of the process and shares it between loader, guide and playback, so two instances never cancel each other's session.
- The URL session stores no cookies and no cache, and follows redirects only to the same host and port, so the MAC cookie and session key never reach another server.
- 0014 downloads the guide with its own session, so on a rejection it calls the client's `invalidateToken()` and asks for a new request once.
- The Keychain item keeps the MAC in `username` and gains an optional `login`; items saved before this spec decode unchanged and no migration runs.
- Account info's `end_date` is read in UTC, date-only strings included, for 0006's "Account active until" row.
- Owner's numbers: 50 000 channels and 200 000 guide rows decode in under 10 s in a debug CI run; bare logo file names go under `misc/logos/320/`; the guide period is clamped to 1 to 168 hours.

## Dropped

- Moved to the implementation plan: AC-5a, AC-5b, AC-7, AC-7a, AC-9a, AC-11a, AC-18, AC-26.
- Merged into AC-3: AC-2, AC-5, AC-8.
- Merged into AC-3a: AC-12a, AC-19.
- Merged into AC-9: AC-6.
- Merged into AC-10: AC-10a, AC-11, AC-17a.
- Merged into AC-14: AC-13, AC-14c, AC-14d.
- Merged into AC-17: AC-16.
- Merged into AC-20: AC-21.
- Merged into AC-23: AC-15, AC-22, AC-23a, AC-23b.
- Merged into AC-24: AC-12, AC-14a, AC-14b.
- Required of other specs: moved to the Needs from other specs line and Notes for the plan.
