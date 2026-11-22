# Proposal

## Why

> As a living-room viewer, when a channel will not play, I want to tell the developer from the Apple TV without finding a laptop and writing an email.

> As a household setter-upper, I want to report that a source stopped loading and get an answer, without pasting my provider's address and password into a public bug tracker.

> As the developer, I want each report to arrive with the app version, the platform and the playback error, so I can tell a provider outage from a bug in Antenna.

Today the only way to reach Code Crave is the support@code-crave.se address on the website's legal pages. Nothing in the app points to it, Apple TV users have no mail client, and an email says nothing about the build or the error unless the user copies it out by hand.

After this change a user opens Settings, chooses Report a problem, writes what happened, sees exactly what will be sent, and gets a reference code back. From a failed channel or movie, "Report this problem" opens the same form with the error filled in. The report becomes an issue in a private GitHub repository that only the owner can read. A user who adds an email can get a reply; without one the report is one-way.

## What Changes

- A Report a problem form on iPhone, iPad, Mac and Apple TV: what happened (required), an optional topic, an optional email for a reply, and on iPhone, iPad and Mac an optional box to attach the latest crash or hang report. Below the fields, a "What will be sent" list shows every value, with the text as it will be sent.
- A "Report a problem" row in Settings on every platform, and a "Report this problem" action on the player's error screen for channels, movies and episodes that fills in the error.
- What a report carries: the user's text, the topic, the app version and build, platform and OS version, device model, app language, whether the app is unlocked, the kinds of sources set up (M3U, Xtream and so on), and the last playback error's reason, engine and age. Never a source address, source name, username, password, MAC address, channel name or stream link. Links and login-looking strings are removed from the user's text on the device, and again on the service.
- A `POST /v1/support` endpoint on the Code Crave service planned in `add-title-metadata` (API Gateway, Lambda, CloudFront, AWS WAF). It checks that the request comes from Antenna (App Attest where the device supports it, a DeviceCheck token otherwise), rate-limits by IP, rejects oversized or malformed bodies, scrubs the text again, and creates the issue with a GitHub App installation token held in Secrets Manager. The app holds no GitHub credential.
- Issues go to a separate private repository. This repository is public.
- A reference code on the confirmation screen instead of an issue number.
- A report that cannot be sent stays in the form with the reason. Nothing is queued in the background.
- Report a problem works before purchase, from a link on the paywall. This amends the "shows only the paywall until an entitlement is present" constraint and needs the owner's OK (design.md, open question 6).
- The App Privacy answers change from "Data Not Collected" to Contact Info, User Content and Diagnostics, for App Functionality, not used for tracking. `docs/release/app-privacy.md`, the three privacy manifests and the Privacy Policy change in the same change.

Out of scope:
- Analytics, usage statistics or crash reporting across the app. App Store Connect and the Xcode Organizer stay the source of numbers and crash logs.
- Replies inside the app, a ticket list, or a status for a sent report.
- Attachments other than the one MetricKit diagnostic: no screenshots, playlist files or logs.
- Crash and hang reports on Apple TV. MetricKit is not available on tvOS.
- A web form on antenna.code-crave.se.
- Reading or answering reports anywhere but GitHub (no helpdesk tool).
- Sending a report from a widget, App Intent or Top Shelf.

## Capabilities

### New Capabilities
- `support-requests`: the report form, what a report carries and never carries, scrubbing, the preview, sending, failure handling, the reference code and the service's checks.

### Modified Capabilities
- `sources-and-settings`: the Report a problem row.
- `player-controls-and-playback-errors`: Report this problem on the error screen.
- `paywall-and-entitlement`: reporting works before the app is unlocked (pending the owner's OK).
- `antenna-website`: the Privacy Policy names the support service, what a report holds, GitHub as where it is kept, and how to have it deleted.
- `app-release`: the privacy manifests declare the data a report collects.

## Impact

- Depends on `add-title-metadata`: the lookup service under `Services/lookup/`, its CDK stack, the OIDC deploy role and the amendment to the "no server of our own" rule. That service does not exist yet; its tasks 3.1 to 3.3 are open. This change adds an endpoint to it and cannot ship before it.
- The `antenna-website` delta is written on top of `add-title-metadata`'s version of "The Privacy Policy rules out tracking". Archive that change first, or merge the two texts when archiving this one.
- Infrastructure outside the app: a private GitHub repository for reports, a GitHub App installed only on it with Issues read and write, its private key in Secrets Manager, and Apple's App Attest and DeviceCheck keys for the team.
- AntennaCore: the report builder, the text scrubber, the request encoding and the reference code.
- Apps: the report form on every platform, the Settings row, the error screen action, the paywall link, the MetricKit subscriber on iPhone, iPad and Mac, and the App Attest entitlement.
- `docs/architecture/`: GitHub becomes an external system in the context and container diagrams.
- Web: Privacy Policy and `WebsiteTests`. Docs: `docs/release/app-privacy.md`. Manifests: `Apps/Mobile`, `Apps/TV` and `Apps/TopShelf` `PrivacyInfo.xcprivacy`.
- Boards: new draft boards `iPhone-Report`, `iPhone-Report-Failed`, `iPhone-Report-Sent`, `TV-Report` and `TV-Report-Sent`. The rest are listed in design.md as not drawn yet.
- Blocked on: the owner's answers to the open questions in design.md, above all hosting (1), the paywall amendment (6) and the privacy label (7), and on `add-title-metadata`'s service.
