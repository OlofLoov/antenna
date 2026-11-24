# Proposal

## Why

The owner, on 2026-11-22: AWS for now, "most straightforward, we can always change later", and a new domain for Antuna instead of the company domain code-crave.se. Later that day the owner took every recommendation in design.md: a short `.app` name containing "antuna", registered in Route 53 Domains, with `www` redirecting to the bare domain. On 2026-11-23 the owner picked and registered `antuna.app`.

> As the developer, I want the domain, the certificate and the website defined in one place in the repository.

> As a buyer reading about Antuna, I want its site on its own address, over HTTPS.

Today the site is `Web/`, with `.github/workflows/pages.yml` meant to publish it to GitHub Pages at antenna.code-crave.se. Pages was never enabled and that name has no DNS record, so nothing is served. The app has no server. The app is not published, so no installed build, App Store listing or link in a user's hands names the old domain.

After this change Code Crave has one AWS account defined by Terraform in this repo. The site, a single-page app prerendered to HTML by `add-feature-website`, is served from a private S3 bucket through CloudFront at `https://antuna.app` with a strict Content-Security-Policy. Every deploy runs from main through GitHub Actions with a role assumed through OIDC, and nothing keeps a log of who asked for what. The domain is renamed everywhere the repo names antenna.code-crave.se, and the unused GitHub Pages workflow is removed.

## What Changes

- Terraform under `Infra/`, owner-decided on 2026-11-22 in place of a CDK app: a Route 53 hosted zone for `antuna.app`, ACM certificates in us-east-1 for CloudFront, a private S3 bucket and a CloudFront distribution with Origin Access Control for the site, the GitHub OIDC provider and deploy roles, and an AWS Budgets alarm at $20 a month.
- A deploy workflow: `terraform test` and a `terraform plan` comment on pull requests that touch `Infra/`, `terraform apply` and the site upload on merge to main, through roles assumed with GitHub's OIDC token. No AWS keys are stored in GitHub.
- One environment, production, and no other. The owner approves each infrastructure deploy; site uploads need no approval.
- No request logs anywhere: CloudFront standard and real-time logs off, S3 server access logs off.
- The site is served from CloudFront at `antuna.app`, not GitHub Pages. `.github/workflows/pages.yml`, `Web/CNAME` and `Web/.nojekyll` are removed. Pages was never switched on, so there is nothing to switch off and no redirect.
- Every place the repo names antenna.code-crave.se names `antuna.app` instead: the associated domains entitlement, the setup and sign-in links, the paywall's Terms and Privacy links, the App Store support and privacy addresses, the App Review notes and the review playlist's guide address. design.md has the list.
- No email on the new domain and no MX records.
- A Content-Security-Policy header on every page that lets a page run only the site's own scripts, styles and images and connect to nothing but the site. The setup page gets a stricter one: no scripts at all.
- Every address without a page answers with the site's "Page not found" page and a not-found status, never the home page with a success status.
- `www.antuna.app` redirects permanently to `antuna.app`.

Dropped on 2026-11-23: the API. The owner dropped the in-app support form (support is email to antuna@code-crave.se on the site's support page) and put the title-info service (`add-title-metadata`) on hold, so nothing needs `api.antuna.app` and there is still no server of our own. design.md decisions 6 and 10 say what was planned.

Out of scope:
- An API, `api.antuna.app`, Lambdas or a WAF web ACL. A later change that needs a server adds them on this account, domain and set of roles.
- The feature website's pages (`add-feature-website`).
- A staging environment or preview deployments per pull request.
- A redirect from antenna.code-crave.se. Nothing published uses it.
- Anything else on code-crave.se. The company domain's DNS stays where it is, apart from removing the `antenna` record.
- Email of any kind on the new domain.
- The Apple developer team and what hangs on it. Code Crave stays the team; the team id, the bundle ids (`se.codecrave.antenna` and its extensions), the iCloud container `iCloud.se.codecrave.antenna` and the Keychain service names do not change. Only the website domain moves.

## Capabilities

### New Capabilities
- `hosting`: where the site is served, how and from where it deploys, and what it never logs.

### Modified Capabilities
- `antuna-website`: the site answers on the new domain and publishes from main to the new host.
- `app-release`: the review playlist and guide are served from the new domain, and the App Store addresses point there.

## Impact

- New: `Infra/` (Terraform roots and modules, their `terraform test` files), `.github/workflows/infra.yml`. Removed: `.github/workflows/pages.yml`, `Web/CNAME`, `Web/.nojekyll`.
- `scripts/publish-web.sh` keeps building the folder, and copies in the single-page app's build when it is given one; the upload moves to the new workflow, which builds the app with Node 22 first.
- App: `Config/Antenna.entitlements`, `Config/AntennaMac.entitlements`, `project.yml` (Terms and Privacy addresses), `Apps/Mobile/Info.plist`, `Apps/TV/Info.plist`, `Apps/Shared/Components/Paywall/Paywall.swift` (preview addresses), `SetupLink.host` in AntennaCore.
- Store and release: `fastlane/metadata/*/support_url.txt` and `privacy_url.txt`, `scripts/store_metadata.py`, `docs/release/app-review-notes.md`, `docs/release/app-privacy.md`, `docs/release/device-checklist.md`, `Web/review/antuna-review.m3u`, `scripts/check-rules.sh`.
- Tests: `WebsiteTests`, `SetupLinkTests`, `LoginLinkTests`, `SetupInboxTests`, `SetupUITests`, `SendLoginsUITests`. `ReleaseTests` reads `SetupLink.host` and follows on its own.
- Boards: `TV-Paywall`, `TV-Paywall-Purchasing` and `TV-Paywall-Unavailable` show the addresses as text and change with them.
- Docs: CLAUDE.md's `Web/` line, and `docs/architecture/` (the website on CloudFront, S3 and Route 53). `openspec/config.yaml`'s "no server of our own" line stays as it is.
- `add-feature-website` depends on this change for the host.
- Was blocked on the owner registering `antuna.app` (task 1.1), creating the AWS account, and the one-time bootstrap in design.md decision 9. All three were done by 2026-11-24.
