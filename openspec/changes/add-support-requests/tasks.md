## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-support-requests --strict`
- [x] 1.2 Draw draft boards `iPhone-Report`, `iPhone-Report-Failed`, `iPhone-Report-Sent`, `TV-Report` and `TV-Report-Sent`
- [ ] 1.3 Get the owner's answers to the open questions in design.md and fold them into the design and specs
- [ ] 1.4 Draw the boards listed under "Not drawn yet" in design.md: iPad and Mac, the Settings row, the error screen action, the paywall link and the remaining states

## 2. Report builder and scrubber in AntennaCore

- [ ] 2.1 Add `SupportReport`, `SupportReport.Topic` and `SupportReportBuilder` with the allowlist from design.md decision 4, citing `support-requests/only-what-helps-fix-the-problem-is-sent`
- [ ] 2.2 Add a fixture test that builds a report with a source name, channel, profile, host, username, password, MAC address and stream link set and finds none of them in the encoded body, citing `support-requests/nothing-about-sources-or-the-user-is-sent`
- [ ] 2.3 Add `ReportScrubber` with the rules in decision 5 and a shared fixture file the service also reads, citing `support-requests/links-and-logins-are-removed-from-the-text`
- [ ] 2.4 Add `ReferenceCode`, `LastPlaybackError` and `DiagnosticDigest`, with tests for the code alphabet, the 24-hour expiry and the 200 KB reduction
- [ ] 2.5 Add the `SupportClient` protocol, the HTTP client with the 20-second timeout and the answer-to-status mapping, and a Debug-only stub, citing `support-requests/a-report-that-cannot-be-sent-stays`

## 3. Support endpoint and infrastructure

Blocked on `add-title-metadata` tasks 3.1 to 3.3 and on open question 1.

- [ ] 3.1 Create the private repository and the GitHub App installed only on it, and put its key in Secrets Manager (owner, outside the repo)
- [ ] 3.2 Add `GET /v1/support/challenge` and `POST /v1/support` under `Services/lookup/src/support/`: schema check, 256 KB cap, App Attest and DeviceCheck verification, scrubbing from the shared fixtures, duplicate check by reference, issue creation, with unit tests citing `support-requests/only-antenna-can-send-reports` and `support-requests/reports-reach-the-developer-privately`
- [ ] 3.3 Add the routes, the support Lambda, its secrets and a WAF rate rule of 10 per IP per 5 minutes to the CDK stack, with every request log off
- [ ] 3.4 Amend the "no server of our own" line in `openspec/config.yaml` and CLAUDE.md to say the service also passes problem reports to the private repository and keeps nothing itself
- [ ] 3.5 Add GitHub to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg`

## 4. Form on iPhone, iPad and Mac

- [ ] 4.1 Add `ReportProblemScreen` and its components with previews on iPhone, iPad and Mac, citing `support-requests/write-a-report`, `support-requests/see-what-will-be-sent` and `support-requests/a-reply-needs-an-email`
- [ ] 4.2 Add `SupportProofProvider` (App Attest, DeviceCheck, none) and the App Attest entitlement in `project.yml`, with "Send by email" when neither works
- [ ] 4.3 Add the MetricKit subscriber and the attach box, citing `support-requests/crash-and-hang-reports-only-when-ticked`
- [ ] 4.4 Add the Settings row, citing `sources-and-settings/report-a-problem-from-settings`
- [ ] 4.5 Add "Report this problem" to the error screen for channels, movies and episodes, citing `player-controls-and-playback-errors/report-a-failed-stream`
- [ ] 4.6 Show the confirmation and the failure statuses, citing `support-requests/a-sent-report-gives-a-reference`
- [ ] 4.7 UI tests on iPhone and iPad with the stub client: send, offline, rate limited, empty text

## 5. Form on Apple TV

- [ ] 5.1 Add `ReportProblemScreenTV` with previews, the focus order from the board and the discard prompt on Menu, citing `support-requests/write-a-report`
- [ ] 5.2 Add the Settings row and the error screen action on Apple TV, keeping Try again focused
- [ ] 5.3 Try App Attest on an Apple TV 4K and record the result in design.md (open question 3)
- [ ] 5.4 UI tests on Apple TV with the stub client: focus order, send, offline

## 6. Paywall

Waits for the owner's answer to open question 6.

- [ ] 6.1 Amend the paywall line in `openspec/config.yaml` and CLAUDE.md as design.md decision 12 words it
- [ ] 6.2 Add the "Report a problem" link to the paywall on every platform, citing `paywall-and-entitlement/nothing-works-before-the-app-is-unlocked`

## 7. Privacy docs

Ships in the same release as groups 3 to 5.

- [ ] 7.1 Update `docs/release/app-privacy.md` with the table in decision 13
- [ ] 7.2 Add `NSPrivacyCollectedDataTypes` to `Apps/Mobile` and `Apps/TV` `PrivacyInfo.xcprivacy`, leave Top Shelf without collected data, citing `app-release/each-bundle-declares-its-privacy`
- [ ] 7.3 Update `Web/privacy/` and `WebsiteTests`: the opening, network connections, the Problem reports section and the retention period, citing `antenna-website/the-privacy-policy-rules-out-tracking` and `antenna-website/the-privacy-policy-explains-problem-reports`

## 8. Verify

- [ ] 8.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 8.2 `/opsx:verify` passes
