# Design

## Context

See proposal.md for why. What exists on 2026-11-22:

- No way to contact Code Crave from the app. `support@code-crave.se` appears only on the Terms of Use and the Privacy Policy pages.
- `add-title-metadata` plans the first Code Crave server: `Services/lookup/`, a TypeScript Lambda behind an API Gateway HTTP API and CloudFront, with a CDK stack, a deploy workflow using an AWS role through OIDC, Secrets Manager for the TMDB key, every request log off, a static app header and a per-IP AWS WAF rate rule. None of it is built (its tasks 3.1 to 3.3 are open). That change also amends the "no server of our own" rule in `openspec/config.yaml`.
- `PlaybackFailure` in AntennaCore names every reason a stream fails (`offline`, `notFound`, `refused(status:)`, `cannotDecode(codec:)` and the rest) and carries no address. `SourceKind` lists `m3u`, `xtream`, `stalker`, `jellyfin`, `channelsDVR` and `m3uFile`.
- `docs/release/app-privacy.md` answers "Data Not Collected". Its "When this changes" section already says that sending crash or performance reports adds Crash Data and Performance Data. The three `PrivacyInfo.xcprivacy` files declare no collected data.
- The Privacy Policy says "Antenna collects nothing about you" and "Code Crave runs no server that receives it", and mentions that Apple may share crash reports when the user allows sharing with developers.
- The paywall is the only screen before purchase (`paywall-and-entitlement/nothing-works-before-the-app-is-unlocked`).
- Apple TV already hands work to an iPhone in one place: the QR sign-in in `apple-tv-login-from-iphone`, with a sealed CloudKit drop.

## Boards

Under `openspec/specs/design-system/boards/`, drawn as drafts in this change in the same hand-written `.dc.html` form as the other boards:
- `iPhone-Report`: the form pushed inside Settings, filled in, with the "What will be sent" list and a scrubbed link.
- `iPhone-Report-Failed`: the form as a sheet from the player error, Topic set to Playback, the error filled in, an email given, and the offline status above the fields.
- `iPhone-Report-Sent`: the confirmation with the reference code and Done.
- `TV-Report`: fields on the left, the list on the right, focus on the text.
- `TV-Report-Sent`: the confirmation with Done focused.

Follows: `iPhone-Settings`, `TV-Settings`, `iPhone-Player-Error`, `iPad-Player-Error`, `TV-Player-Error`, `iPhone-Paywall`, `TV-Paywall`, `TV-Settings-Preferences-Choices` (the topic list on Apple TV).

Not drawn yet:
- iPad and Mac. The iPhone form in Settings' detail column, and as a form sheet from the player and the paywall.
- The Settings row on the existing Settings boards, the "Report this problem" button on the three Player-Error boards, and the "Report a problem" link at the bottom of the paywall boards.
- Sending (spinner in place of Send), the rate-limited and refused statuses (same place as `iPhone-Report-Failed`, other text), the email check message, the 4,000-character line, the discard prompt, and the device-with-neither state with "Send by email".
- Apple TV with an error status, and the topic choices list.
- Right-to-left and large text.

Design-system requirements that apply: "Focus is the lifted white card", "One accent color", "Text stays above the platform caption floor", "Text meets contrast minimums", "Accessibility identifiers follow the board", "Nothing fake and nothing bundled" (no copy names the user's device, which is why the Apple TV hint says "an iPhone nearby").

## Research

The Apple rows were checked on 2026-11-22 in Apple's documentation data and developer forums. The GitHub and AWS WAF rows are from their documentation as last read, not rechecked; confirm them in the service PR.

| What | Platforms | Notes |
|------|-----------|-------|
| App Attest, `DCAppAttestService` | Listed for iOS 14, macOS 11, tvOS 15 | `isSupported` is false on a Mac, including Catalyst and iPad apps on Apple silicon ([isSupported](https://developer.apple.com/documentation/devicecheck/dcappattestservice/issupported)). WWDC26 session 201: "App Attest is supported on all Apple platforms, including macOS 27 and higher, which was previously not supported" ([session](https://developer.apple.com/videos/play/wwdc2026/201/)), for full apps in a user session only ([forum](https://developer.apple.com/forums/thread/836329)). Neither source says which Apple TV models return true; not checked on a device. Keys do not survive reinstall, migration or restore, and Apple asks apps to keep new keys rare ([integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)). |
| DeviceCheck, `DCDevice.generateToken` | iOS 11, macOS 10.15, tvOS 11 | A short-lived token the server checks with Apple's DeviceCheck API using a team key. Proves a genuine Apple device and the developer's app, not an unmodified binary. Whether `DCDevice.isSupported` is true on a Mac was not checked. |
| MetricKit, `MXDiagnosticPayload` | iOS 14, macOS 12 | Not on tvOS ([payload](https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload)). Call stacks arrive unsymbolicated, as binary UUIDs and offsets. |
| GitHub issues | | Issue and comment bodies are capped at 65,536 characters. A GitHub App installation token lasts one hour and can be scoped to one repository and the Issues permission. |
| AWS WAF rate rules | | Limit as low as 10 requests per IP over 1, 2, 5 or 10 minutes. |

Apple's App Privacy rules ([details](https://developer.apple.com/app-store/app-privacy-details/)):
- Customer Support is "Data generated by the user during a customer support request" under User Content. Email Address is under Contact Info. Crash Data, Performance Data ("launch time, hang rate") and Other Diagnostic Data are under Diagnostics.
- App Functionality includes "perform customer support" and "minimize app crashes".
- Optional disclosure needs every one of its criteria, including "the user's name or account name is prominently displayed in the submission form". Antenna has no account and no name to show, so the report data has to be disclosed.
- Data is linked to the user unless it is de-identified before collection. An email address cannot be.

## Goals / Non-Goals

**Goals:**
- A report from any of the four platforms in under a minute, with the values that tell a provider problem from an Antenna bug.
- Nothing about the user's sources leaves the device, and the user can check that before sending.
- No GitHub credential in the app, and no public trace of a report.

**Non-Goals:**
- Analytics or app-wide crash reporting. App Store Connect and the Xcode Organizer give crash and hang numbers from users who share with developers.
- A support inbox or replies in the app.

## Decisions

### 1. Where the endpoint runs: the lookup service on AWS (pending the owner)

The owner is considering hosting this API himself.

Options considered:
- **A. A `/v1/support` route on the lookup service from `add-title-metadata` (recommended).** Same CDK stack, Lambda runtime, CloudFront distribution, WAF web ACL and OIDC deploy role. No machine to patch, no uptime to watch, TLS from AWS, and access logs are off by configuration. Cost at a few hundred reports a month: one more WAF rule (about $1 a month), one more secret (about $0.40 a month), Lambda and HTTP API inside the free tier. A route of its own keeps the support Lambda separate from the lookup Lambda, so a bug in one does not hold the other's secrets.
- **B. A self-hosted box or VPS** (a machine at home or a small VPS). Full control and a flat price of a few euros a month. The owner then patches the OS, renews certificates, keeps it running, keeps backups of the GitHub App key, and turns off the web server's access logs, which record IP addresses by default. A home connection exposes the owner's IP address and has no shield against floods. App Attest and DeviceCheck checks are the same code either way.
- **C. A separate AWS stack for support only.** Cleaner blast radius than A, but a second distribution, WAF and deploy role for one route.
- **D. A third-party form or helpdesk endpoint.** No code, but a new processor that receives email addresses and text, a monthly price, and its own logging rules.

If the owner picks B, the endpoint contract below stays, and the app reads its base address from one place, so it can move later.

### 2. Where reports land: issues in a private repository

Options considered:
- **Issues in this public repository.** Users will paste provider addresses and logins, and the scrubber will miss some. Ruled out.
- **Issues in a private repository (chosen).** `OlofLoov/antenna-support`, private, issues only. The owner already works in GitHub issues; labels sort reports; notifications arrive by email.
- **Email through SES to support@code-crave.se.** No tracker, mail retention to manage, and SES domain setup.
- **A helpdesk (Help Scout, Zendesk).** Replies by email built in, but a monthly fee and another processor.

The credential is a GitHub App, "Antenna Support", installed only on that repository with Issues read and write and Metadata read. Its private key sits in Secrets Manager. The Lambda signs a ten-minute JWT, exchanges it for an installation token, and keeps the token in memory until five minutes before it expires. A fine-grained personal access token was considered: simpler, but tied to the owner's account, expiring after at most a year with no warning to the service.

Each report is one issue:
- Title `[R-4F7K2Q] Playback: ` and the first 60 characters of the scrubbed text.
- Labels `report`, `topic:<topic>`, `platform:<ios|ipados|macos|tvos>`, `source:<kind>` per kind, and `diagnostic` when one is attached.
- Body: the scrubbed text, then a table of the values, then the email when given.
- The diagnostic, when attached, as the first comment in a `json` block, cut to 60,000 characters with a note when longer.

### 3. Proving a report comes from Antenna

Options considered:
- **App Attest once per install, then an assertion per request.** Apple's recommended flow. Needs a store on the service for each key's public key and counter, which is a per-install identifier Code Crave would keep.
- **A fresh App Attest key and attestation per report (recommended).** The service checks the attestation against Apple's App Attest root with a challenge it issued, then forgets the key. Nothing is stored. Reports are rare, a few per device in its life, so the extra keys stay well below what Apple warns about. If Apple throttles attestations, fall back to the first option.
- **A DeviceCheck token per report.** Stateless; the service checks the token with Apple. Weaker than App Attest (it proves the device and the team, not the binary), and needs Apple's API on every report.
- **The static header only**, as the lookups use. Enough for cached reads, not for writes into the owner's tracker.

Chosen: App Attest per report where `DCAppAttestService.isSupported` is true, a DeviceCheck token where it is not, and neither means the form offers "Send by email" on iPhone, iPad and Mac (a mail with the same text and values) and a line naming support@code-crave.se on Apple TV. Expected per platform: iPhone and iPad App Attest; Mac App Attest from macOS 27, DeviceCheck or email on macOS 26; Apple TV unknown until tried on a device (open question 3). Builds signed with a personal team have no App Attest or DeviceCheck key and fall back to email.

The challenge is stateless: `GET /v1/support/challenge` returns a random value, a timestamp and an HMAC over both with a key in Secrets Manager, valid five minutes. The app hashes the challenge with the request body as the attestation's client data, so a proof cannot be reused for another body.

Rate limits: a WAF rate rule on `/v1/support*` at 10 requests per IP per 5 minutes, separate from the lookup rule. Bodies over 256 KB are refused by the Lambda before parsing. The service validates the body against a strict schema and refuses unknown fields.

### 4. What a report carries

The app builds the body in AntennaCore from values the screens hand it, so the allowlist is in one tested place:

```json
{
  "reference": "R-4F7K2Q",
  "text": "scrubbed text, at most 4,000 characters",
  "topic": "playback | channelsAndGuide | moviesAndSeries | sourcesAndSignIn | purchase | other | null",
  "email": "optional, at most 254 characters",
  "app": { "version": "1.4", "build": "52", "language": "en" },
  "device": { "platform": "tvos", "os": "26.1", "model": "AppleTV14,1" },
  "unlocked": true,
  "sources": ["xtream", "m3u"],
  "lastError": { "reason": "notFound", "status": 404, "codec": null, "engine": "demux", "secondsAgo": 120 },
  "diagnostic": null
}
```

- `model` is the hardware identifier (`utsname.machine`), the same one the Xcode Organizer groups by. Decoder support differs by chip, so "Apple TV" alone would not tell an Apple TV HD from a 4K. Open question 5.
- `sources` lists each kind once, from the sources on this device, with `m3uFile` reported as `m3u`.
- `lastError` comes from a small per-device value the player writes when an error screen shows: the reason, status or codec, the engine, and the time. It lives in `UserDefaults` under `support.lastPlaybackError`, holds no link, and is cleared after 24 hours. Opening the form from the error screen uses that error.
- The source name, channel, title, profile, server address, username, password, MAC address, stream link, device name, iCloud identifiers and the entitlement's product or receipt are never inputs to the builder, so they cannot reach the body. A test builds a report from a fixture with all of them set and checks the encoded body for each.

### 5. Scrubbing

`ReportScrubber.scrub(_:knownSecrets:)` in AntennaCore runs on every keystroke for the list and once more on Send. In order:
1. Exact matches of the user's own source hosts, usernames and passwords of four characters or more, case-insensitive, become `[login removed]` (hosts `[address removed]`). The values come from the Keychain on the device and never leave it.
2. Links with a scheme (`http`, `https`, `rtmp`, `rtsp`, `udp`, `rtp`, `mms`) and `www.` links become `[link removed]`.
3. Email addresses become `[email removed]`.
4. MAC addresses, IPv4 and IPv6 addresses, and `host:port` become `[address removed]`.
5. `name: value` or `name=value` where the name is user, username, login, pass, password, pwd, token, key or mac become `[login removed]` for both parts.
6. Runs of 24 or more letters, digits or `+/=_-` with no space (tokens) become `[login removed]`.

The service runs rules 2 to 6 again (it cannot know the user's secrets). Both read one fixture file of inputs and expected outputs, as the title matching in `add-title-metadata` does, so the two stay in step.

Channel names the user types stay. The user wrote them and sees them in the list; removing them would make many reports unreadable.

### 6. Email and replies

An optional email field, checked for a plausible shape (something, `@`, a dot in the domain). The owner replies by hand from support@code-crave.se. Without an email the report is one-way, and the footer says so. The email is never stored on the device after the form closes.

### 7. Crash and hang reports

A `MXMetricManager` subscriber on iPhone, iPad and Mac keeps the latest `MXDiagnosticPayload` that has a crash or hang in `Caches/support/latest-diagnostic.json`, replaced by each newer one and deleted after 30 days or once sent. On Send with the box ticked, the app reduces it to the diagnostic's metadata (app and OS version, exception type, signal, termination reason, hang duration) and the call stack of the crashed thread, or the main thread for a hang, to at most 200 KB. The owner symbolicates with the build's dSYMs.

App-wide analytics and automatic crash upload stay out. The Organizer and App Store Connect remain the source for numbers.

### 8. Where it shows

- Settings, every platform: a "Report a problem" row under About, after Version (`settings.report`). On iPhone it pushes the form inside the Settings sheet; on iPad and Mac it shows in the detail column; on Apple TV it opens full screen.
- Player error, every platform, for channels, movies and episodes: "Report this problem" next to Try again (`player.report`), opening the form as a sheet (full screen on Apple TV) with Topic Playback. Try again keeps first focus on Apple TV.
- Paywall: a "Report a problem" link at the bottom (`paywall.report`), pending open question 6.

`ReportProblemScreen` in `Apps/Shared/Views/Support/` owns the draft, the model and sending. The components (`ReportPreviewList`, `ReportStatusBanner`, `ReportSentView`) take values and closures. The Apple TV arrangement is `ReportProblemScreenTV`, a separately named view, not a flag.

### 9. Apple TV text entry

The text and email fields use the system keyboard. tvOS sends the Apple TV Keyboard notification to iPhones on the same account nearby, so a long text can be typed there.

A QR hand-off like the sign-in (the TV shows a code, the iPhone opens the form with the TV's values and sends on its behalf) was considered. It would reuse a known pattern, but the report would then come from the iPhone's proof and network, the TV's values would travel in the link, and the keyboard notification already covers typing. Not in this change; open question 4.

### 10. When sending fails

The draft lives in the screen's model only. It survives leaving and reopening the form while the app runs, and is gone when the app quits. It is not written to `UserDefaults` or disk, because the user's text may hold a secret the scrubber missed, and per-device storage must hold no secret.

No background queue. A report sent later on its own would surprise a user who closed the form believing it failed, and would need the text on disk. The status says why it failed, and Send works again.

Timeout 20 seconds. Answers map to statuses: no network, `offline`; timeout or 5xx, "Couldn't reach Antenna support"; 429, too many; 400, 401 and 413, refused.

### 11. Reference code and duplicates

The app makes the reference when the form opens: `R-` and six characters from Crockford base32 without I, L, O and U, about a billion values. It is what the user quotes; private issue numbers mean nothing outside the repository.

A retry after a timeout sends the same reference. Before creating an issue the service lists the repository's issues labeled `report` updated in the last hour and looks for the reference in their titles. When it finds one it answers with that reference and creates nothing. The list endpoint is used because GitHub's search lags behind new issues.

### 12. Reporting before purchase (needs the owner's OK)

A user who cannot buy, or whose purchase does not restore, is the one most likely to need help, and has only the paywall. The form contacts only the support service and no source, so `paywall-and-entitlement/nothing-works-before-the-app-is-unlocked` keeps its promise about sources; the "shows only the paywall" wording changes. The PR that builds it amends `openspec/config.yaml`'s line "The app is free to download and shows only the paywall until an entitlement is present" to add "and the Report a problem form it links to". It is not a feature gate and changes nothing about entitlement.

### 13. Privacy label and policy

App Store Connect, both apps:

| Data type | Linked to the user | Tracking | Purpose |
|-----------|--------------------|----------|---------|
| Contact Info, Email Address | Yes | No | App Functionality |
| User Content, Customer Support | Yes | No | App Functionality |
| Diagnostics, Other Diagnostic Data | Yes | No | App Functionality |
| Diagnostics, Crash Data (iOS app only) | Yes | No | App Functionality |
| Diagnostics, Performance Data (iOS app only) | Yes | No | App Functionality |

"Linked: yes" because a report can carry an email, and Apple counts anything stored next to one as linked. Open question 7 covers answering "No" for reports without an email.

The manifests gain `NSPrivacyCollectedDataTypes` with the same types (`NSPrivacyCollectedDataTypeEmailAddress`, `CustomerSupport`, `OtherDiagnosticData`, and on iOS `CrashData` and `PerformanceData`), `Linked` true, `Tracking` false, purpose `AppFunctionality`. The Top Shelf manifest stays empty of collected data.

The Privacy Policy changes its opening ("collects nothing about you" becomes "collects nothing unless you send a problem report"), adds a Problem reports section, adds the support service and GitHub to network connections, and states the retention from open question 8. `docs/release/app-privacy.md` changes its answer, its "Why" section and the "When this changes" note.

### 14. Identifiers

AntennaCore, `Sources/AntennaCore/Support/`: `SupportReport` (the body, `Codable`), `SupportReport.Topic`, `SupportReportBuilder`, `ReportScrubber`, `ReferenceCode`, `LastPlaybackError`, `SupportClient` (protocol, `send(_:proof:) async throws -> SupportReceipt`), `SupportError` (`offline`, `unreachable`, `rateLimited`, `refused`), `DiagnosticDigest` (the reduction in decision 7, from JSON so it stays Foundation only).

Apps: `ReportProblemScreen`, `ReportProblemScreenTV`, `SupportProofProvider` (App Attest, DeviceCheck, none), `DiagnosticInbox` (the MetricKit subscriber, not built for tvOS).

Accessibility: `settings.report`, `player.report`, `paywall.report`, `report.root`, `report.text`, `report.text.hint`, `report.topic`, `report.email`, `report.email.footer`, `report.diagnostic`, `report.preview`, `report.preview.<field>`, `report.preview.footer`, `report.send`, `report.status`, `report.discard`, `report.sent`, `report.sent.reference`, `report.sent.done`.

Service: `Services/lookup/src/support/` with `challenge.ts`, `report.ts`, `scrub.ts`, `attest.ts`, `devicecheck.ts`, `github.ts`. Secrets `antenna/support/github-app-key`, `antenna/support/challenge-hmac`, `antenna/support/devicecheck-key`.

## Risks / Trade-offs

- The scrubber will miss some secrets typed in odd forms. Mitigations: the user sees the text before Send, the repository is private, and the owner can delete an issue. A pasted login in a private tracker is the residual risk.
- The privacy label leaves "Data Not Collected". Some users read any label as a warning. The data only exists when a user writes and sends a report.
- A first write path into the owner's tracker. Proof, rate limits and the size cap bound abuse; a flood still costs the owner triage time.
- Apple TV may end up with DeviceCheck only, which is easier to replay within a token's short life than App Attest.
- The service does not exist yet. Until it does, the form can be built against a stub client in Debug builds, as `add-title-metadata` decision 8 did for lookups.

## Migration Plan

Additive. A new per-device `UserDefaults` key and a Caches folder. No synced data changes. Older builds have no form.

## Open Questions

Open questions for the owner, each with a recommendation:

1. **Self-hosted or AWS?** Recommend AWS, as a route on the lookup service (decision 1, A): no patching, no uptime, logs off by configuration, about $1.50 a month extra. Self-hosting fits only if the box already exists and is kept patched with access logs off.
2. **Repository name and owner.** Recommend `OlofLoov/antenna-support`, private, with the "Antenna Support" GitHub App installed on it only.
3. **Apple TV proof.** Recommend trying App Attest on an Apple TV 4K first, and shipping with DeviceCheck as the fallback if `isSupported` is false there.
4. **Write the report on an iPhone from the Apple TV?** Recommend not in this change: the system keyboard notification covers long text, and a hand-off moves the report to the iPhone's network and proof.
5. **Device model detail.** Recommend the hardware identifier (`AppleTV14,1`) over a class ("Apple TV 4K"), since decoder bugs follow the chip and millions of devices share each identifier.
6. **Reporting before purchase.** Recommend yes, with the paywall link and the `openspec/config.yaml` amendment in decision 12. Purchase problems happen before purchase.
7. **"Linked to you" on the label.** Recommend "Yes" for every type, because a report may carry an email. Answering "No" would need reports without an email kept apart from those with one.
8. **How long reports are kept.** Recommend deleting closed report issues 12 months after closing, with a scheduled workflow in the private repository, and at once on request by reference. The Privacy Policy states the period.
9. **Attempts with neither proof.** Recommend "Send by email" on iPhone, iPad and Mac and the support address on Apple TV, over accepting unproven reports at a tighter rate limit.
10. **Queue a failed report?** Recommend no (decision 10): keep the draft in memory and say why it failed.
