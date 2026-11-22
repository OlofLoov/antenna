# Design

## Context

See proposal.md for why. What exists on 2026-11-22:

- `Web/` is copied by `scripts/publish-web.sh` into a folder, with the team id filled into the association file from the `APPLE_TEAM_ID` repository variable and the App Review guide written by `scripts/make-review-guide.py`. `.github/workflows/pages.yml` uploads that folder to GitHub Pages on pushes to main that touch the site, and `release.yml` runs it again after each release (`gh workflow run pages.yml`).
- `Web/CNAME` holds antenna.code-crave.se. The code-crave.se DNS has an `antenna` record pointing at GitHub Pages; that zone is not in this repo.
- No AWS account, no server, no CDK. `add-title-metadata` decision 1 planned `Services/lookup/` with "a TypeScript Lambda and a CDK stack", an OIDC deploy workflow, Secrets Manager, CloudFront with a one-day cache, a WAF rate rule and every request log off. `add-support-requests` decision 1 puts `/v1/support` on the same stack. Both are proposed; neither has built any of it.
- The app is not published. Nothing has been uploaded to App Store Connect or TestFlight (`app-release/merging-the-release-pull-request-publishes-the-release`), so no installed build, listing or user's link holds the old domain. The move is a rename.
- The owner wants no email (2026-11-22). `add-support-requests` is being changed by another agent to drop the email field and the support address.

No screens. This change draws no boards; it edits the address text on three existing ones.

## Where antenna.code-crave.se appears

Every hit outside `openspec/changes/archive/` on 2026-11-22. Each becomes `<antenna-domain>` in the rename PR (task group 5) unless noted.

| Where | What |
|-------|------|
| `Config/Antenna.entitlements`, `Config/AntennaMac.entitlements` | `applinks:antenna.code-crave.se`. The Apple TV app has no associated domains. |
| `project.yml` lines 66 to 67 and 166 to 167 | `AntennaTermsURL`, `AntennaPrivacyURL` for the iOS and tvOS targets |
| `Apps/Mobile/Info.plist`, `Apps/TV/Info.plist` | the same two keys, as XcodeGen writes them |
| `Apps/Shared/Components/Paywall/Paywall.swift` line 128 | preview Terms and Privacy addresses |
| `Packages/AntennaCore/Sources/AntennaCore/Setup/SetupLink.swift` | `SetupLink.host`, used to write and read setup and sign-in links. Its doc comment ("An assumption until the hosting decision picks one") goes. |
| `Packages/AntennaCore/Tests/AntennaCoreTests/SetupLinkTests.swift`, `LoginLinkTests.swift` | literal links; switch to `SetupLink.host` so the next rename touches one line |
| `Packages/AntennaCore/Tests/AntennaCoreTests/WebsiteTests.swift` | reads `Web/CNAME`; checks `support@code-crave.se` on the legal pages (lines 128 and 157) |
| `Packages/AntennaCore/Tests/AntennaCoreTests/ReleaseTests.swift` | uses `SetupLink.host`; follows on its own. It also checks `pages.yml` (lines 122 to 125), which changes to the new workflow. |
| `Apps/Tests/SetupInboxTests.swift`, `Apps/UITests/SetupUITests.swift`, `Apps/UITests/SendLoginsUITests.swift` | literal setup links |
| `Web/CNAME` | removed |
| `Web/review/antenna-review.m3u` | `url-tvg` guide address |
| `Web/terms/index.html`, `Web/privacy/index.html` | `support@code-crave.se` as the contact. Not a site address; it goes with the no-email decision (decision 8), in `add-feature-website`'s support page PR. |
| `fastlane/metadata/*/support_url.txt` (9 locales) | `/terms` today. Renamed here; `add-feature-website` points them at `/support`. |
| `fastlane/metadata/*/privacy_url.txt` (9 locales) | `/privacy` |
| `scripts/store_metadata.py` line 49 | `SITE`, which the listing check compares the addresses with |
| `scripts/check-rules.sh` line 38 | `code-crave\.se/review` in the pattern that keeps the review playlist out of the app; becomes the new domain |
| `docs/release/app-review-notes.md` lines 10 to 12 and 32 | the reviewer's playlist address and the curl checks |
| `docs/release/app-privacy.md` line 6 | the Privacy Policy address |
| `docs/release/device-checklist.md` lines 373 to 374 | the association file check, which also says "at GitHub Pages" |
| `CLAUDE.md` line 49 | "the static site at antenna.code-crave.se, published by pages.yml" |
| `openspec/specs/design-system/boards/TV-Paywall.dc.html`, `TV-Paywall-Purchasing.dc.html`, `TV-Paywall-Unavailable.dc.html` | the addresses as text in the footer |
| `openspec/specs/design-system/boards/iPhone-Report-Sent.dc.html`, `TV-Report-Sent.dc.html`, `openspec/changes/add-support-requests/` | `support@code-crave.se`. Owned by the agent removing email from that change; not edited here. |

Not in the list, because they do not depend on a domain: the bundle ids, `iCloud.se.codecrave.antenna`, the Keychain service `se.codecrave.antenna.sources`, the Handoff activity type `se.codecrave.antenna.setup`, and the team id in `APPLE_TEAM_ID`.

The specs name no domain; they say "the app's domain". The `antenna-website` Purpose line stays.

## Goals / Non-Goals

**Goals:**
- One CDK app owns everything Code Crave runs in AWS for Antenna, so the services in later changes add a route and a Lambda, not an account, a distribution or a role.
- Nothing logs a request's path, query, body or caller.
- A deploy needs no stored secret and comes only from main.
- The cost stays a few dollars a month until the API carries traffic, and an alarm fires before it does more.

**Non-Goals:**
- High availability across regions. One region for the API; CloudFront is already global.
- A second environment.
- Moving the company's own DNS or mail.

## Decisions

### 1. Where the infrastructure lives: one CDK app in `Infra/`

Options considered:
- **A. One CDK app in `Infra/`, Lambda code in `Services/<name>/` (chosen).** `Infra/` is a TypeScript CDK app (`bin/antenna.ts`, `lib/*-stack.ts`, `test/`), with Jest snapshot and assertion tests. Each service's handler code lives in its own package under `Services/` and the API stack bundles it with `NodejsFunction` (esbuild). The domain, the certificates, the WAF web ACL and the roles exist once.
- **B. A CDK stack per service, as `add-title-metadata` planned (`Services/lookup/` with its own stack).** Fine for one service. With the site and the support route it becomes three stacks each wanting the hosted zone, a certificate, a distribution and a deploy role, or cross-stack lookups between apps.
- **C. Terraform or OpenTofu.** Equal in reach, but state needs its own bucket and lock, and the lookup service was already planned in TypeScript.
- **D. SST or Amplify Hosting.** Less code for the site, more framework between the owner and the AWS resources, and Amplify keeps access logs by default.

`Infra/` uses Node 22 and a pinned `aws-cdk-lib`. Its tests and `cdk synth` run in PR CI (`infra.yml`), so the Swift jobs stay as they are. `scripts/check-rules.sh` gains a grep that fails on `accessLog`, `enableLogging: true`, `logBucket` or `serverAccessLogs` in `Infra/lib/` (decision 5).

### 2. Stacks and regions

The API runs in eu-north-1 (Stockholm): the owner is in Sweden, every service the API needs exists there, and it is among the cheaper EU regions. us-east-1 only where AWS requires it: ACM certificates used by CloudFront and WAF web ACLs with CloudFront scope.

| Stack | Region | Holds |
|-------|--------|-------|
| `AntennaEdge` | us-east-1 | Route 53 hosted zone for `<antenna-domain>` (Route 53 is global; the stack has to sit somewhere), ACM certificates for `<antenna-domain>`, `www.<antenna-domain>` and `api.<antenna-domain>` with DNS validation in that zone, the CloudFront-scope WAF web ACL, the Budgets alarm |
| `AntennaSite` | eu-north-1 | the site bucket, its CloudFront distribution with Origin Access Control, the CloudFront Function for addresses and the response headers policy, the alias records |
| `AntennaApi` | eu-north-1 | the HTTP API, its CloudFront distribution at `api.<antenna-domain>` with the WAF web ACL, the origin secret, the alias record; routes and Lambdas are added by later changes |
| `AntennaCi` | eu-north-1 | the GitHub OIDC provider and the three roles in decision 4 |

Cross-region values (certificate and web ACL ARNs) pass with `crossRegionReferences: true`. `AntennaCi` is deployed once by hand by the owner (decision 9) and then by the workflow like the rest.

### 3. The site: private S3 and CloudFront with Origin Access Control

Options considered:
- **S3 static website hosting alone.** The website endpoint is HTTP only; a custom domain gets no HTTPS. Ruled out.
- **S3 website endpoint behind CloudFront.** HTTPS at the edge, but the bucket has to be public, and anyone can read it around CloudFront.
- **Private bucket, CloudFront with Origin Access Control (chosen).** The bucket blocks all public access and its policy lets only this distribution read. The site's files cannot be read around it (`hosting/the-site-s-files-cannot-be-read-around-it`).
- **Keep GitHub Pages and use AWS only for the API.** No work for the site, but two hosts, two DNS paths and no response headers policy; Pages also cannot send a Content-Security-Policy.

Details:
- A viewer-request CloudFront Function maps `/terms` and `/terms/` to `/terms/index.html`, `/` to `/index.html`, and `www.<antenna-domain>` to a 301 on the apex. The S3 REST origin has no index documents of its own.
- `/404.html` is the error page for 403 and 404 from the origin, answered with 404.
- Viewer protocol policy: redirect HTTP to HTTPS. TLS 1.2 minimum (`TLSv1.2_2021`).
- Response headers policy: `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`, `Content-Security-Policy: default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`, `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`. With the CSP, the browser enforces "nothing loads from another address" (`antenna-website/the-pages-read-on-a-phone-and-in-dark-mode`) on top of the test.
- Caching: the managed CachingOptimized policy, a one-hour default TTL for HTML and a day for images, and an invalidation of `/*` after each upload (the first 1,000 paths a month are free).
- The association file has no extension, so the upload sets `Content-Type: application/json` on it explicitly. A test in `WebsiteTests` reads the workflow and checks for it.
- `.nojekyll` and `CNAME` were for GitHub Pages and are removed.

### 4. Deploy: GitHub Actions, OIDC, one environment

A new workflow, `.github/workflows/infra.yml`:
- On a pull request touching `Infra/**`, `Services/**` or the workflow: install, test, `cdk synth`, and `cdk diff` with the read-only `antenna-diff` role, posted as one sticky PR comment. Pull requests from forks get no OIDC token and skip the diff.
- On push to main touching those paths or `Web/**`, `scripts/publish-web.sh`, `scripts/make-review-guide.py`: a `deploy` job in the `production` environment runs `cdk deploy --all --require-approval never` with `antenna-deploy`, then a `site` job builds the folder with `scripts/publish-web.sh` and runs `aws s3 sync --delete` and the invalidation with `antenna-site`.
- `workflow_dispatch` for the site job, which `release.yml` calls after a release instead of `gh workflow run pages.yml`.

Roles in `AntennaCi`, each trusting `token.actions.githubusercontent.com` with audience `sts.amazonaws.com`:

| Role | Subject it trusts | Can |
|------|-------------------|-----|
| `antenna-diff` | `repo:<owner>/antenna:pull_request` | assume the CDK lookup role and read CloudFormation; nothing that writes |
| `antenna-deploy` | `repo:<owner>/antenna:environment:production` | assume the CDK bootstrap deploy, file-publishing and image-publishing roles |
| `antenna-site` | `repo:<owner>/antenna:ref:refs/heads/main` | `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on the site bucket and `cloudfront:CreateInvalidation` on the site distribution |

The `production` environment allows only the main branch. Who approves:
- Options considered: no reviewer (the merge is the approval, as for the site), the owner as required reviewer on every infrastructure deploy, or the owner only for changes to IAM, DNS or WAF.
- Recommended: the owner as required reviewer on `production`, which gates `cdk deploy`. Site uploads use `antenna-site` without the environment, so a page edit is live within minutes of the merge, the way Pages works today. Infrastructure changes are rare, and the PR's diff comment tells the owner what he is approving. The third option needs a script that reads the diff, which is more to get wrong than one click.

Environments: one, `production`, in one AWS account. A staging account is added when a service has users who would notice a bad deploy; the stacks take the account and domain from context, so a second set is a second `cdk deploy` with other values.

### 5. No request logs

The Privacy Policy says Code Crave keeps nothing about the user, and both later services promise to keep no record of requests. So, by configuration in the stacks, checked by assertion tests in `Infra/test/`:
- CloudFront standard logs off and no real-time log config, on every distribution.
- API Gateway access logs off on the default stage; detailed metrics off.
- S3 server access logs off on the site bucket. No CloudTrail data events.
- WAF: no logging configuration, `SampledRequestsEnabled: false` on the web ACL and every rule (sampled requests otherwise keep IP addresses and headers for three hours). CloudWatch metrics stay on; they are counts.
- Lambda: a log group per function created by the stack with 14 days' retention. The handlers log the route, the status and the error class, never the query, body, headers or source IP. Each later service adds a test for its handler.
- CloudTrail's default event history (90 days of management events, the AWS API calls the deploy role makes) stays. It records deploys, not visitors.

### 6. The API: HTTP API behind CloudFront and WAF

AWS WAF cannot attach to an API Gateway HTTP API, only to REST APIs, CloudFront, ALB and a few others. `add-title-metadata` also wants CloudFront's cache in front. So:
- The HTTP API in eu-north-1 with its default `execute-api` endpoint as the origin of a CloudFront distribution at `api.<antenna-domain>`. No regional custom domain, so no eu-north-1 certificate.
- CloudFront adds an `x-antenna-origin` header with a random value from Secrets Manager (`antenna/api/origin-secret`). A Lambda authorizer would cost a call per request; instead each handler checks the header with a shared helper in `Services/shared/` and answers 403 without it. That is how `hosting/the-api-answers-on-its-own-address` refuses calls to the `execute-api` address.
- Cache policy: by default none (`CachingDisabled`) and all query strings forwarded; a route that wants caching, such as `/v1/match`, sets its own behavior in the change that adds it.
- WAF web ACL with the AWS managed IP reputation list and a rate rule of 300 requests per IP per five minutes on `/v1/*`. `add-support-requests` adds its own tighter rule on `/v1/support*`.
- Unknown routes answer API Gateway's 404 with the body `{"message":"Not Found"}`, which names no version or server. A response headers policy removes `x-amzn-*` and `apigw-requestid` headers.

What this means for the two services, written into their designs in this PR:
- `add-title-metadata`: the lookup Lambda and its routes are added to `AntennaApi`; its code stays in `Services/lookup/`. Its planned CDK stack, deploy workflow and OIDC role are this change's. It adds a cache behavior for `/v1/match*` and `/v1/trending*` with a one-day TTL.
- `add-support-requests`: its Lambda, secrets and WAF rule are added to `AntennaApi` and `AntennaEdge`.

### 7. The domain

Registration is not something CDK or CloudFormation does. The owner registers `<antenna-domain>` by hand, in Route 53 Domains if it sells the top-level domain (then the name servers point at the hosted zone with no extra step), otherwise at another registrar with its name servers set to the hosted zone's four. `.app` is HTTPS-only by HSTS preload, which matches the site, and Route 53 sells it; `.tv` and `.se` are the other names the owner might want (open question 1).

Records in the zone: apex and `www` A/AAAA aliases to the site distribution, `api` aliases to the API distribution, the ACM validation CNAMEs, and a CAA record allowing only `amazon.com`. No MX record, an SPF record `v=spf1 -all` and a DMARC record `v=DMARC1; p=reject` so nobody can send mail as the domain.

Old domain: the `antenna` CNAME in the code-crave.se zone is deleted once the new site serves, and the Pages site is switched off in the repository settings (an owner step; this change touches no repo settings from automation).

### 8. No email

The owner wants none. The domain gets no MX record (decision 7), so mail to it bounces. Contact goes through the app's Report a problem form (`add-support-requests`) and the site's support page (`add-feature-website`).

App Store Connect requires a support URL; the site's `/support` page is it, once `add-feature-website` ships it, and `/terms` until then. App Review's guideline 1.5 asks that the support URL "include an easy way to contact you"; the support page names Report a problem in the app. Separately, the EU Digital Services Act makes Apple show a trader's address, phone number and email on the product page for a paid app in the EU. That is an address the owner gives Apple in App Store Connect, it can be on any domain, and it needs nothing on `<antenna-domain>`. It is recorded in `docs/release/` with the other App Store answers (task 6.4).

### 9. One-time setup by the owner

Outside the repo, before the first deploy. No agent or workflow runs these.
1. Create the AWS account with MFA on the root user, and an IAM Identity Center user for the owner.
2. Register `<antenna-domain>`.
3. `cdk bootstrap` in eu-north-1 and us-east-1.
4. `cdk deploy AntennaCi` from the owner's machine, which creates the OIDC provider and the three roles.
5. Set the repository variables `AWS_ACCOUNT_ID` and `ANTENNA_DOMAIN`, and the `production` environment with the owner as reviewer.

### 10. The config.yaml amendment

`openspec/config.yaml` says sync is CloudKit "with no server of our own", and `add-title-metadata` and `add-support-requests` each planned to amend it. It is amended once here, when `AntennaApi` first deploys: "Sync is SwiftData over the user's private CloudKit database, with no server of our own. Code Crave runs one API at `api.<antenna-domain>` for services the app calls by name; it holds no user's sources, logins or watch data and keeps no record of requests." `add-title-metadata` adds its routes without touching the line; `add-support-requests` adds its sentence about problem reports reaching the private repository (its task 3.4). CLAUDE.md's hard constraints say the same.

## Cost

AWS list prices as read on 2026-11-22 for us-east-1 and eu-north-1; not measured.

| Item | Per month |
|------|-----------|
| Route 53 hosted zone | $0.50, plus $0.40 per million queries |
| Domain | about $1 to $2 (a `.app` is about $15 to $20 a year) |
| ACM public certificates | $0 |
| S3, a few MB | under $0.05 |
| CloudFront | inside the always-free tier (1 TB out, 10 million requests) at this size |
| CloudFront Function | inside the free 2 million invocations |
| WAF web ACL | $5, plus $1 per rule (two rules) and $0.60 per million requests |
| Secrets Manager (origin secret) | $0.40 |
| HTTP API, Lambda | inside the free tier until a service has traffic |
| Budgets | the first two budgets are free |

About $8 a month with the API's WAF, about $2 before it. The web ACL is created with the API stack, so it can wait until the first route ships. CloudFront also sells flat-rate plans that bundle WAF and Route 53 (a free plan was announced in late 2025); not checked, and worth a look when the API ships.

Budget: $20 a month in AWS Budgets, alerting the owner's AWS account address at 50% actual, 100% actual and 100% forecast, plus a Cost Anomaly Detection monitor on all services. Alerts use the AWS account's email, which is not on the new domain.

## Risks / Trade-offs

- The account is the owner's to keep: root credentials, MFA, and billing. A leaked deploy role is limited to one repository's main branch and environment.
- Cross-region references create SSM parameters and custom resources that make deleting stacks out of order fail. Stacks are torn down in reverse order, written in `Infra/README.md`.
- If the domain is not registered before the rename PR, the app builds with a name that does not resolve and the paywall's links fail on device. The rename (task group 5) waits for the site to answer on the new domain.
- Universal links: Apple fetches the association file through its CDN, which caches it. A wrong file on the first deploy can keep setup links opening in Safari for up to a day on test devices. The device checklist's association check runs after the first deploy.
- A WAF rate limit shared by everyone behind one carrier NAT can refuse real users. 300 per five minutes per IP is far above what one person makes; the services' own rules are tighter only on writes.
- Lock-in is small: the site is a folder, the services are Lambdas behind plain HTTP, and the domain is the owner's.

## Migration Plan

1. Owner: steps in decision 9.
2. PR: `Infra/` with `AntennaEdge`, `AntennaSite`, `AntennaCi`, and `infra.yml`. Merge deploys the site to `<antenna-domain>` next to Pages.
3. PR: the rename in every place listed above. `pages.yml`, `Web/CNAME` and `Web/.nojekyll` removed.
4. Owner: switch off GitHub Pages, delete the `antenna` record in code-crave.se's DNS.
5. PR: `AntennaApi` with no routes, the `config.yaml` amendment and the diagrams, when `add-title-metadata` or `add-support-requests` is ready to add its first route.

No data moves. Rollback for steps 2 and 3 is reverting the PRs while Pages still serves.

## Open Questions

Open questions for the owner, each with a recommendation:

1. **The domain name.** Recommend a short `.app` name containing "antenna" (for example `antenna<word>.app`), registered in Route 53 Domains so the zone needs no name server step. `.app` is HTTPS-only, which matches the site. Every task after group 1 waits for this.
2. **Who approves infrastructure deploys?** Recommend the owner as required reviewer on the `production` environment for `cdk deploy`, and no approval for site uploads (decision 4).
3. **One environment or two?** Recommend one, `production`, until a service has users; the stacks are parameterized so a staging account is a later deploy.
4. **`Infra/` or `Services/` for the CDK app?** Recommend `Infra/` for the CDK app and `Services/<name>/` for each Lambda's code, so a service PR touches its own folder and one stack file.
5. **Budget amount.** Recommend $20 a month, with alerts at 50% and 100% and a forecast alert.
6. **When the WAF web ACL is created.** Recommend with `AntennaApi`, when the first route ships, not with the site, which saves about $6 a month until then.
7. **www.** Recommend serving the apex and redirecting `www` to it, with one certificate covering both.
