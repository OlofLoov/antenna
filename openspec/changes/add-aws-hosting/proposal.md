# Proposal

## Why

The owner, on 2026-11-22: AWS for now, "most straightforward, we can always change later", and a new domain for Antenna instead of the company domain code-crave.se. Later that day the owner took every recommendation in design.md: a short `.app` name containing "antenna", registered in Route 53 Domains, with `www` redirecting to the bare domain. The exact name is not picked yet; this change writes it as `<antenna-domain>` until task 1.1 picks it.

> As the developer, I want one place that owns the domain, the certificates, the website and the API, so the movie info service, problem reports and the feature website do not each build their own copy.

> As a buyer reading about Antenna, I want its site on its own address, over HTTPS.

Today the site is `Web/`, with `.github/workflows/pages.yml` meant to publish it to GitHub Pages at antenna.code-crave.se. Pages was never enabled and that name has no DNS record, so nothing is served. The app has no server. `add-title-metadata` plans a lookup service with its own CDK stack and deploy role, and `add-support-requests` plans a `/v1/support` route on it. Neither is built. The app is not published, so no installed build, App Store listing or link in a user's hands names the old domain.

After this change Code Crave has one AWS account defined by Terraform in this repo. The site, a single-page app prerendered to HTML by `add-feature-website`, is served from a private S3 bucket through CloudFront at `https://<antenna-domain>` with a strict Content-Security-Policy, and the API answers at `https://api.<antenna-domain>` with no routes of its own until those two changes add them. Every deploy runs from main through GitHub Actions with a role assumed through OIDC, and nothing keeps a log of who asked for what. The domain is renamed everywhere the repo names antenna.code-crave.se, and the unused GitHub Pages workflow is removed.

## What Changes

- Terraform under `Infra/`, owner-decided on 2026-11-22 in place of a CDK app: a Route 53 hosted zone for `<antenna-domain>`, ACM certificates in us-east-1 for CloudFront, a private S3 bucket and a CloudFront distribution with Origin Access Control for the site, an empty API (API Gateway HTTP API in eu-north-1 behind its own CloudFront distribution and an AWS WAF web ACL) that later changes add routes and Lambdas to, the GitHub OIDC provider and deploy roles, and an AWS Budgets alarm at $20 a month.
- A deploy workflow: `terraform test` and a `terraform plan` comment on pull requests that touch `Infra/`, `terraform apply` and the site upload on merge to main, through roles assumed with GitHub's OIDC token. No AWS keys are stored in GitHub.
- One environment, production, and no other. The owner approves each infrastructure deploy; site uploads need no approval.
- No request logs anywhere: CloudFront standard and real-time logs off, API Gateway access logs off, S3 server access logs off, WAF logging and sampled requests off, Lambda logs limited to counts and errors with a 14-day retention.
- The site is served from CloudFront at `<antenna-domain>`, not GitHub Pages. `.github/workflows/pages.yml`, `Web/CNAME` and `Web/.nojekyll` are removed. Pages was never switched on, so there is nothing to switch off and no redirect.
- Every place the repo names antenna.code-crave.se names `<antenna-domain>` instead: the associated domains entitlement, the setup and sign-in links, the paywall's Terms and Privacy links, the App Store support and privacy addresses, the App Review notes and the review playlist's guide address. design.md has the list.
- No email on the new domain and no MX records.
- A Content-Security-Policy header on every page that lets a page run only the site's own scripts, styles and images and connect to nothing but the site. The setup page gets a stricter one: no scripts at all.
- Every address without a page answers with the site's "Page not found" page and a not-found status, never the home page with a success status.
- `www.<antenna-domain>` redirects permanently to `<antenna-domain>`.

Out of scope:
- The lookup service, the support endpoint and their Lambdas (`add-title-metadata`, `add-support-requests`). This change gives them the API, the distribution, the WAF web ACL and the deploy role to build on.
- The feature website's pages (`add-feature-website`).
- A staging environment or preview deployments per pull request.
- A redirect from antenna.code-crave.se. Nothing published uses it.
- Anything else on code-crave.se. The company domain's DNS stays where it is, apart from removing the `antenna` record.
- Email of any kind on the new domain.
- The Apple developer team and what hangs on it. Code Crave stays the team; the team id, the bundle ids (`se.codecrave.antenna` and its extensions), the iCloud container `iCloud.se.codecrave.antenna` and the Keychain service names do not change. Only the website and API domain move.

## Capabilities

### New Capabilities
- `hosting`: where the site and the API are served, how and from where they deploy, and what they never log.

### Modified Capabilities
- `antenna-website`: the site answers on the new domain and publishes from main to the new host.
- `app-release`: the review playlist and guide are served from the new domain, and the App Store addresses point there.

## Impact

- New: `Infra/` (Terraform roots and modules, their `terraform test` files), `.github/workflows/infra.yml`. Removed: `.github/workflows/pages.yml`, `Web/CNAME`, `Web/.nojekyll`.
- `scripts/publish-web.sh` keeps building the folder, and copies in the single-page app's build when it is given one; the upload moves to the new workflow, which builds the app with Node 22 first.
- App: `Config/Antenna.entitlements`, `Config/AntennaMac.entitlements`, `project.yml` (Terms and Privacy addresses), `Apps/Mobile/Info.plist`, `Apps/TV/Info.plist`, `Apps/Shared/Components/Paywall/Paywall.swift` (preview addresses), `SetupLink.host` in AntennaCore.
- Store and release: `fastlane/metadata/*/support_url.txt` and `privacy_url.txt`, `scripts/store_metadata.py`, `docs/release/app-review-notes.md`, `docs/release/app-privacy.md`, `docs/release/device-checklist.md`, `Web/review/antenna-review.m3u`, `scripts/check-rules.sh`.
- Tests: `WebsiteTests`, `SetupLinkTests`, `LoginLinkTests`, `SetupInboxTests`, `SetupUITests`, `SendLoginsUITests`. `ReleaseTests` reads `SetupLink.host` and follows on its own.
- Boards: `TV-Paywall`, `TV-Paywall-Purchasing` and `TV-Paywall-Unavailable` show the addresses as text and change with them.
- Docs: CLAUDE.md's `Web/` line, `docs/architecture/` (the CDN, the API and AWS as containers), `openspec/config.yaml`'s "no server of our own" line, amended once, here, for both later services.
- `add-title-metadata` and `add-support-requests` depend on this change for the account, the API, CloudFront, WAF and the deploy role. `add-feature-website` depends on it for the host.
- Blocked on: the owner picking the exact name and registering `<antenna-domain>` (task 1.1, the one open question), creating the AWS account, and the one-time bootstrap in design.md decision 9.
