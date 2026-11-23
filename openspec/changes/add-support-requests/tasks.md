## 1. Proposal and boards

- [x] 1.1 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-support-requests --strict`
- [x] 1.2 Draw draft boards `iPhone-Report`, `iPhone-Report-Failed`, `iPhone-Report-Sent`, `TV-Report` and `TV-Report-Sent`
- [x] 1.3 Fold in the owner's 2026-11-22 decisions: no email, AWS for the service, and `antuna.app` in place of code-crave.se
- [x] 1.4 Fold the owner's 2026-11-22 answers to the remaining open questions into the design, proposal and tasks
- [ ] 1.5 Draw the boards listed under "Not drawn yet" in design.md: iPad and Mac, the Settings row, the error screen action, the paywall link, Sent reports and the remaining states

## 2. Report builder and scrubber in AntennaCore

- [ ] 2.1 Add `SupportReport`, `SupportReport.Topic` and `SupportReportBuilder` with the allowlist from design.md decision 4, citing `support-requests/only-what-helps-fix-the-problem-is-sent`
- [ ] 2.2 Add a fixture test that builds a report with a source name, channel, profile, host, username, password, MAC address and stream link set and finds none of them in the encoded body, citing `support-requests/nothing-about-sources-or-the-user-is-sent`
- [ ] 2.3 Add `ReportScrubber` with the rules in decision 5 and a shared fixture file the service also reads, citing `support-requests/links-and-logins-are-removed-from-the-text`
- [ ] 2.4 Add `ReferenceCode`, `LastPlaybackError` and `DiagnosticDigest`, with tests for the code alphabet, the 24-hour expiry and the 200 KB reduction
- [ ] 2.5 Add the `SupportClient` protocol, the HTTP client with the 20-second timeout and the answer-to-status mapping, and a Debug-only stub, citing `support-requests/a-report-that-cannot-be-sent-stays`
- [ ] 2.6 Add `SentReport` and `SentReports` with the 12-month expiry and `SupportClient.delete(reference:proof:)`, with tests that the stored entry holds no text and that a reference the service does not know counts as deleted, citing `support-requests/delete-a-report-from-the-device-that-sent-it`

## 3. Support endpoint and infrastructure

Blocked on `add-aws-hosting` task 1.1 (the domain name) and task group 6, and on `add-title-metadata` task 3.2.

- [ ] 3.1 Create the private repository `OlofLoov/antuna-support` and the "Antuna Support" GitHub App installed only on it, and put its key in Secrets Manager (owner, outside the repo). Check whether the App can call GraphQL `deleteIssue` and record the answer in design.md decision 6
- [ ] 3.2 Add `GET /v1/support/challenge` and `POST /v1/support` under `Services/lookup/src/support/`: schema check, 256 KB cap, App Attest and DeviceCheck verification, scrubbing from the shared fixtures, duplicate check by reference, issue creation, with unit tests citing `support-requests/only-antuna-can-send-reports` and `support-requests/reports-reach-the-developer-privately`
- [ ] 3.3 Add the routes, the support Lambda, its secrets and a WAF rate rule of 10 per IP per 5 minutes to the `AntennaApi` and `AntennaEdge` stacks in `Infra/` from `add-aws-hosting`, with every request log off
- [ ] 3.4 Amend the "no server of our own" line in `openspec/config.yaml` and CLAUDE.md to say the service also passes problem reports to the private repository and keeps nothing itself
- [ ] 3.5 Add GitHub to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg`
- [ ] 3.6 Add `POST /v1/support/delete` in `delete.ts`: the same proof, lookup by reference, `deleteIssue` or the `delete-requested` label, and "deleted" for an unknown reference, with unit tests citing `support-requests/delete-a-report-from-the-device-that-sent-it`
- [ ] 3.7 Add a scheduled workflow to `OlofLoov/antuna-support` that deletes report issues 12 months after they were made, open or closed (owner, outside this repository)

## 4. Form on iPhone, iPad and Mac

- [ ] 4.1 Add `ReportProblemScreen` and its components with previews on iPhone, iPad and Mac, citing `support-requests/write-a-report` and `support-requests/see-what-will-be-sent`
- [ ] 4.2 Add `SupportProofProvider` (App Attest, DeviceCheck, none) and the App Attest entitlement in `project.yml`, with "Reports can't be sent from this device." when neither works, citing `support-requests/only-antuna-can-send-reports`
- [ ] 4.3 Add the MetricKit subscriber and the attach box, citing `support-requests/crash-and-hang-reports-only-when-ticked`
- [ ] 4.4 Add the Settings row, citing `sources-and-settings/report-a-problem-from-settings`
- [ ] 4.5 Add "Report this problem" to the error screen for channels, movies and episodes, citing `player-controls-and-playback-errors/report-a-failed-stream`
- [ ] 4.6 Show the confirmation and the failure statuses, citing `support-requests/a-sent-report-gives-a-reference`
- [ ] 4.7 Add Sent reports to the form with the delete prompt and statuses, citing `support-requests/delete-a-report-from-the-device-that-sent-it`
- [ ] 4.8 UI tests on iPhone and iPad with the stub client: send, offline, rate limited, empty text, delete

## 5. Form on Apple TV

- [ ] 5.1 Add `ReportProblemScreenTV` with previews, the focus order from the board and the discard prompt on Menu, citing `support-requests/write-a-report`
- [ ] 5.2 Add the Settings row and the error screen action on Apple TV, keeping Try again focused
- [ ] 5.3 Add Sent reports on Apple TV, after Send in focus order
- [ ] 5.4 Try App Attest on an Apple TV 4K and record the result in design.md decision 3; ship with DeviceCheck if `isSupported` is false
- [ ] 5.5 UI tests on Apple TV with the stub client: focus order, send, offline, delete

## 6. Paywall

The owner approved reporting before purchase on 2026-11-22 (design.md decision 12).

- [ ] 6.1 In this group's PR, amend the hard constraint "shows only the paywall until an entitlement is present" in `openspec/config.yaml`, and the "Paid unlock only" hard constraint in CLAUDE.md, to allow the Report a problem form the paywall links to, as design.md decision 12 words it
- [ ] 6.2 Add the "Report a problem" link to the paywall on every platform, citing `paywall-and-entitlement/nothing-works-before-the-app-is-unlocked`

## 7. Privacy docs

Ships in the same release as groups 3 to 5.

- [ ] 7.1 Update `docs/release/app-privacy.md` with the table in decision 13
- [ ] 7.2 Add `NSPrivacyCollectedDataTypes` to `Apps/Mobile` and `Apps/TV` `PrivacyInfo.xcprivacy`, leave Top Shelf without collected data, citing `app-release/each-bundle-declares-its-privacy`
- [ ] 7.3 Update the Privacy Policy (`Web/privacy/`, or `Web/site/src/routes/privacy/` once `add-feature-website` has moved it into the site app) and `WebsiteTests`: the opening, network connections, the Problem reports section and the retention period, citing `antuna-website/the-privacy-policy-rules-out-tracking` and `antuna-website/the-privacy-policy-explains-problem-reports`

## 8. Verify

- [ ] 8.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 8.2 `/opsx:verify` passes
