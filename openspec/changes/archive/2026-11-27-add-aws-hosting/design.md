# Design

## Context

See proposal.md for why. What exists on 2026-11-22:

- `Web/` is copied by `scripts/publish-web.sh` into a folder, with the team id filled into the association file from the `APPLE_TEAM_ID` repository variable and the App Review guide written by `scripts/make-review-guide.py`. `.github/workflows/pages.yml` uploads that folder to GitHub Pages on pushes to main that touch the site, and `release.yml` runs it again after each release (`gh workflow run pages.yml`). Pages was never enabled on the repository, so that workflow fails and nothing is served.
- `Web/CNAME` holds antenna.code-crave.se. The code-crave.se DNS has no `antenna` record; that zone is not in this repo.
- No AWS account, no server, no CDK or Terraform. `add-title-metadata` decision 1 planned `Services/lookup/` with "a TypeScript Lambda and a CDK stack", an OIDC deploy workflow, Secrets Manager, CloudFront with a one-day cache, a WAF rate rule and every request log off. It is proposed and has built none of it.
- The app is not published. Nothing has been uploaded to App Store Connect or TestFlight (`app-release/merging-the-release-pull-request-publishes-the-release`), so no installed build, listing or user's link holds the old domain. The move is a rename.
- The owner dropped `add-support-requests` (the in-app report form and its `/v1/support` route) on 2026-11-23. Support is email to antuna@code-crave.se, on the company's domain, not `antuna.app`. The same day the owner put the title-info service (`add-title-metadata`) on hold, so nothing needs an API, and the API this design planned is dropped (decisions 6 and 10).
- The owner took every recommendation below on 2026-11-22, and asked for the website to be a single-page app. `add-feature-website` decision 2 picks SvelteKit, prerendered to one HTML file per address, so the bucket still holds plain files; decision 3 here covers what that changes for hosting.
- Later that day the owner asked for Terraform instead of the CDK app this design first chose (decision 1).

No screens. This change draws no boards; it edits the address text on three existing ones.

## Where antenna.code-crave.se appears

Every hit outside `openspec/changes/archive/` on 2026-11-22. Each becomes `antuna.app` in the rename PR (task group 5) unless noted.

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
| `Web/review/antuna-review.m3u` | `url-tvg` guide address |
| `Web/terms/index.html`, `Web/privacy/index.html` | `support@code-crave.se` as the contact. Not a site address; `add-feature-website`'s support page replaces it. |
| `fastlane/metadata/*/support_url.txt` (9 locales) | `/terms` today. Renamed here; `add-feature-website` points them at `/support`. |
| `fastlane/metadata/*/privacy_url.txt` (9 locales) | `/privacy` |
| `scripts/store_metadata.py` line 49 | `SITE`, which the listing check compares the addresses with |
| `scripts/check-rules.sh` line 38 | `code-crave\.se/review` in the pattern that keeps the review playlist out of the app; becomes the new domain |
| `docs/release/app-review-notes.md` lines 10 to 12 and 32 | the reviewer's playlist address and the curl checks |
| `docs/release/app-privacy.md` line 6 | the Privacy Policy address |
| `docs/release/device-checklist.md` lines 373 to 374 | the association file check, which also says "at GitHub Pages" |
| `CLAUDE.md` line 49 | "the static site at antenna.code-crave.se, published by pages.yml" |
| `openspec/specs/design-system/boards/TV-Paywall.dc.html`, `TV-Paywall-Purchasing.dc.html`, `TV-Paywall-Unavailable.dc.html` | the addresses as text in the footer |

Not in the list, because they do not depend on a domain: the bundle ids, `iCloud.se.codecrave.antenna`, the Keychain service `se.codecrave.antenna.sources`, the Handoff activity type `se.codecrave.antenna.setup`, and the team id in `APPLE_TEAM_ID`.

The specs name no domain; they say "the app's domain". The `antuna-website` Purpose line stays.

## Goals / Non-Goals

**Goals:**
- One Terraform configuration in `Infra/` owns everything Code Crave runs in AWS for Antuna, so a later change that needs a server adds it to this account, domain and set of roles.
- Nothing logs a request's path, query, body or caller.
- A deploy needs no stored secret and comes only from main.
- The cost stays a few dollars a month, and an alarm fires before it does more.

**Non-Goals:**
- High availability across regions. CloudFront is already global.
- A second environment.
- Moving the company's own DNS or mail.

## Decisions

### 1. Where the infrastructure lives: Terraform in `Infra/` (decided)

The owner chose one place for all of it on 2026-11-22, first as a CDK app (option B). Later the same day the owner switched it to Terraform (option A): "create the needed terraform for it", not CDK.

Options considered:
- **A. Terraform in `Infra/` (chosen).** HCL with the `hashicorp/aws` provider, laid out as roots and modules (decision 2). The domain, the certificate and the roles exist once. When this was chosen, Lambda code for later services was to live in `Services/<name>/`; with the API dropped (decision 6) there is none.
- **B. One CDK app in TypeScript in `Infra/` (chosen first, then replaced).** `bin/antuna.ts`, `lib/*-stack.ts`, Jest assertion tests, `NodejsFunction` for the Lambdas. CloudFormation keeps the state, so no state bucket, and the lookup service was already planned in TypeScript. Cross-region values need `crossRegionReferences`, which creates SSM parameters and custom resources that make deleting stacks out of order fail.
- **C. A CDK stack per service, as `add-title-metadata` planned (`Services/lookup/` with its own stack).** Fine for one service. With the site it becomes two stacks each wanting the hosted zone, a certificate, a distribution and a deploy role, or cross-stack lookups between apps.
- **D. OpenTofu.** The same language and state format as Terraform under an open-source license. The owner asked for Terraform by name, and moving to OpenTofu later is a binary swap.
- **E. SST or Amplify Hosting.** Less code for the site, more framework between the owner and the AWS resources, and Amplify keeps access logs by default.

What Terraform changes against the CDK plan: state lives in an S3 bucket the owner creates once (decision 9); cross-region values are plain references between modules under two provider configurations; there is no `cdk bootstrap`; and the tests are `terraform test` files.

Versions, read on 2026-11-22: Terraform 1.17.2 and `hashicorp/aws` 6.73.0, the current releases. Each root pins both exactly (`required_version = "1.17.2"`, `version = "6.73.0"`) and commits its `.terraform.lock.hcl`; the modules ask for `~> 6.73` and take the root's pin. `infra.yml` installs the same Terraform. A bump is one PR that changes the pins and the lock files.

State: the S3 backend in eu-north-1 with its native lock file (`use_lockfile = true`), so no DynamoDB table. One state file per root, `ci.tfstate` and `antuna.tfstate`, in the bucket `antuna-terraform-state-<account id>`. The bucket name is passed at `terraform init` (`-backend-config=bucket=...`), since a backend block cannot read a variable.

Tests: each `*.tftest.hcl` runs with `mock_provider "aws"` and `command = plan`, so no test reaches AWS, and `override_during = plan` gives computed values such as ARNs a fixed value to assert on. They check the planned values: trust subjects, the CSP strings, the error responses, the public access block, the DNS records. Each cites its requirement in a comment, `# hosting/<slug>`, and `scripts/check-spec-refs.sh` reads `Infra/**/*.tftest.hcl`. They run in `infra.yml` on pull requests, so the Swift jobs stay as they are. `scripts/check-rules.sh` greps `Infra/**/*.tf` for logging blocks (decision 5).

### 2. Layout and regions (decided)

The site bucket and the state live in eu-north-1 (Stockholm): the owner is in Sweden and it is among the cheaper EU regions. us-east-1 only where AWS requires it: ACM certificates used by CloudFront and Cost Explorer, which answers only there.

```
Infra/
  bootstrap/      the state bucket, with local state; applied once by the owner
  ci/             root: the GitHub OIDC provider and the three roles (ci.tfstate)
  antuna/        root: the edge and site modules (antuna.tfstate)
    tests/        terraform test files for the root and for each module
  modules/
    edge/         hosted zone, certificate, mail records, budget, anomaly monitor
    site/         bucket, distribution, address function, header policies, aliases
```

| Module or root | Region | Holds |
|-------|--------|-------|
| `modules/edge` | us-east-1 | Route 53 hosted zone for `antuna.app` (Route 53 is global), the ACM certificate for `antuna.app` and `www.antuna.app` with DNS validation in that zone, the CAA, SPF and DMARC records, the Budgets alarm and the Cost Anomaly Detection monitor |
| `modules/site` | eu-north-1 | the site bucket, its CloudFront distribution with Origin Access Control, the CloudFront Function for addresses, the two response headers policies, the alias records, and the inline policy of the `antuna-site` role |
| `ci` | eu-north-1 (IAM is global) | the GitHub OIDC provider and the three roles in decision 4 |

`ci` is a root of its own because the owner applies it from his machine before any workflow can reach AWS (decision 9), and a mistake in the main root cannot take away the roles the workflow runs as. The `antuna-site` role's permissions name the bucket and the distribution, which `ci` does not know, so `modules/site` attaches that inline policy to the role by name. The workflow applies `ci` first, then `antuna`.

Inputs, from repository variables in the workflow and from `-var` on the owner's machine:
- `domain`, from the `ANTUNA_DOMAIN` repository variable, which the owner sets to `antuna.app`. The tests plan against `antuna.example`.
- `alert_email`, from `AWS_ALERT_EMAIL`: where the budget and anomaly alerts go. AWS has no way to read the account's own address into a budget.
- `github_subject`, the repository part of GitHub's OIDC subject, for the trust subjects. The repository uses GitHub's immutable subjects, which name the owner and repository with their numeric ids (`repo:<owner>@<owner id>/<name>@<repository id>`), so a later rename or a new repository under an old name cannot assume the roles. The workflow builds it from `github.repository_owner_id` and `github.repository_id`; the owner reads it with `gh api repos/<owner>/<name>/actions/oidc/customization/sub`.
- `state_bucket`, built from `AWS_ACCOUNT_ID`, for the diff role's lock file permission.

Earlier changes name the stacks of the CDK plan. They map onto this layout: `AntennaEdge` is `modules/edge`, `AntennaSite` is `modules/site` and `AntennaCi` is the `ci` root. `AntennaApi` was dropped with the API (decision 6).

### 3. The site: private S3 and CloudFront with Origin Access Control (decided)

Options considered:
- **S3 static website hosting alone.** The website endpoint is HTTP only; a custom domain gets no HTTPS. Ruled out.
- **S3 website endpoint behind CloudFront.** HTTPS at the edge, but the bucket has to be public, and anyone can read it around CloudFront.
- **Private bucket, CloudFront with Origin Access Control (chosen).** The bucket blocks all public access and its policy lets only this distribution read. The site's files cannot be read around it (`hosting/the-site-s-files-cannot-be-read-around-it`).
- **Keep GitHub Pages.** No work for the site, but no response headers policy; Pages cannot send a Content-Security-Policy.

Details:
- A viewer-request CloudFront Function (`Infra/modules/site/address.js`, runtime `cloudfront-js-2.0`) maps `/terms` and `/terms/` to `/terms/index.html`, `/` to `/index.html`, and `www.antuna.app` to a 301 on the apex. The S3 REST origin has no index documents of its own. Paths with a file extension, such as `/_app/immutable/...js` or `/review/antuna-review.m3u`, and `/.well-known/apple-app-site-association` pass unchanged.
- `/404.html` is the error page for 403 and 404 from the origin, answered with status 404. Every route of the single-page app is prerendered to its own `index.html` (`add-feature-website` decision 2), so no address needs the usual single-page fallback of `index.html` with status 200. That fallback is ruled out: it would answer every mistyped or removed address with the home page and a success status, which search engines index and link checkers miss (`hosting/the-site-is-served-over-https-on-antuna-s-domain`). Until `add-feature-website` ships, `Web/404.html` is a hand-written page; after it, the build writes `/404.html`.
- Viewer protocol policy: redirect HTTP to HTTPS. TLS 1.2 minimum (`TLSv1.2_2021`).
- Response headers policy for the site: `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`, `Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, and `Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; style-src-attr 'unsafe-hashes' 'sha256-S8qMpvofolR8Mpjy4kQvEm7m1q8clzU4dfDH0AmvZjo='; img-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`. With it the browser refuses any script, stylesheet, image, font, frame or request from another address, any inline script or style but the one style attribute on SvelteKit's route announcer, which `style-src-attr` allows by its exact hash (`add-feature-website` decision 2), and any form, on top of the site's own checks (`hosting/pages-run-only-the-site-s-own-code`, `antuna-website/the-pages-read-on-a-phone-and-in-dark-mode`). `connect-src 'self'` covers the app's own fetches, such as its version file. The value is one fixed string in `modules/site`; a page edit never changes it, so site uploads need no `terraform apply`.
- A second response headers policy on a `/setup*` cache behavior, for the setup page that stays outside the app: the same headers with `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`. It allows the page's inline style attributes and no script at all (`iphone-as-setup-device/an-iphone-without-antuna-gets-a-plain-page`).
- Before `add-feature-website` ships, the legal pages carry inline `<style>` blocks and the site has no script. `add-feature-website` shipped first, so the site policy is the one above from the start. Had this change deployed first, it would have started as `default-src 'none'; style-src 'self' 'unsafe-inline'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`, and the single-page app's first PR sets the policy above (`add-feature-website` task 2.4).
- Options considered for the CSP: a `<meta http-equiv>` tag in each page, which SvelteKit can write with per-page script hashes, but a meta policy cannot set `frame-ancestors` and is only as strict as the page that carries it; a header with per-page hashes from a CloudFront KeyValueStore and a viewer-response function, which needs the store updated on every site upload; and one fixed header (chosen), which works because the site build moves SvelteKit's inline start script into a file (`add-feature-website` decision 2).
- Caching: a cache policy of the site's own with a one-hour default TTL for pages, the managed CachingOptimized policy (a day by default) on `/images/*`, the same policy on `/_app/immutable/*`, where the upload's `Cache-Control: public, max-age=31536000, immutable` keeps the app's hashed files a year, and an invalidation of `/*` after each upload (the first 1,000 paths a month are free). Price class 100 (North America and Europe), the cheapest.
- The upload runs in two steps: `aws s3 sync` of `/_app/immutable/` without `--delete`, then everything else with `--delete`. A visitor who loaded the previous version can still fetch its scripts when they move to another page. The old hashed files stay in the bucket; they are a few hundred KB a release.
- The association file has no extension, so the upload sets `Content-Type: application/json` on it explicitly. A test in `WebsiteTests` reads the workflow and checks for it.
- `.nojekyll` and `CNAME` were for GitHub Pages and are removed.

### 4. Deploy: GitHub Actions, OIDC, one environment (decided)

A new workflow, `.github/workflows/infra.yml`:
- On a pull request touching `Infra/**` or the workflow: `terraform fmt -check -recursive Infra`, then in each root `terraform init -backend=false`, `terraform validate` and `terraform test`. A `plan` job then assumes the read-only `antuna-diff` role, plans `ci` and `antuna`, and posts both plans as one sticky PR comment. It runs only when `AWS_ACCOUNT_ID` is set (and plans `antuna` only when `ANTUNA_DOMAIN` and `AWS_ALERT_EMAIL` are too); otherwise it writes a notice and skips. Pull requests from forks get no OIDC token and skip the plan.
- On push to main touching `Infra/**`, `Web/**`, `scripts/publish-web.sh`, `scripts/make-review-guide.py` or the workflow: an `apply` job in the `production` environment runs `terraform apply` on `ci` and then `antuna` with `antuna-deploy`, only when the push changed `Infra/**` or the workflow and the variables are set. Then a `site` job, after `apply` succeeded or was skipped, sets up Node from `Web/site/.nvmrc`, runs `npm ci` and `npm run build` in `Web/site/` once it exists, builds the folder with `scripts/publish-web.sh <folder> Web/site/build` (or without the second argument while there is no `Web/site/`), and runs the two-step `aws s3 sync` and the invalidation from decision 3 with `antuna-site`. It runs only when `AWS_ACCOUNT_ID`, `SITE_BUCKET` and `SITE_DISTRIBUTION_ID` are set.
- `workflow_dispatch` runs the site job alone, which `release.yml` calls after a release instead of `gh workflow run pages.yml` (task 4.1).
- Until the owner sets the variables every AWS job is skipped, so main stays green and no site is served. The owner decided on 2026-11-23 not to use GitHub Pages in the meantime, and `pages.yml` is removed (task 4.1).

Where the site job's values come from: repository variables. The role ARNs are built from `AWS_ACCOUNT_ID` and the fixed role names. `SITE_BUCKET` and `SITE_DISTRIBUTION_ID` are copied once by the owner from `terraform output` after the first apply. The other option, reading the outputs from state in the site job, needs the site role to read the whole state file.

Roles in the `ci` root, each trusting `token.actions.githubusercontent.com` with audience `sts.amazonaws.com`:

| Role | Subject it trusts | Can |
|------|-------------------|-----|
| `antuna-diff` | `<subject>:pull_request` | the AWS managed `ReadOnlyAccess` policy, and writing and deleting the lock files (`*.tflock`) in the state bucket; nothing else that writes |
| `antuna-deploy` | `<subject>:environment:production` | `AdministratorAccess`. Terraform creates roles, DNS records, certificates and distributions, so a narrower policy would list most of IAM, Route 53, ACM, S3, CloudFront, Budgets and Cost Explorer anyway; the CDK plan's execution role had the same policy. The trust subject and the environment's reviewer limit it. |
| `antuna-site` | `<subject>:ref:refs/heads/main` | `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` on the site bucket and `cloudfront:CreateInvalidation` on the site distribution, attached by `modules/site` |

The `production` environment allows only the main branch. Who approves:
- Options considered: no reviewer (the merge is the approval, as for the site), the owner as required reviewer on every infrastructure deploy, or the owner only for changes to IAM or DNS.
- Chosen by the owner on 2026-11-22: the owner as required reviewer on `production`, which gates `terraform apply`. Site uploads use `antuna-site` without the environment, so a page edit is live within minutes of the merge. Infrastructure changes are rare, and the PR's plan comment tells the owner what he is approving. The third option needs a script that reads the plan, which is more to get wrong than one click.

Environments: one, `production`, in one AWS account, decided by the owner on 2026-11-22. The other option was a staging account next to it, at twice the fixed cost and a second set of roles. A staging account is added when a service has users who would notice a bad deploy; the roots take the domain as a variable and the bucket at init, so a second account is a second state bucket and other values.

### 5. No request logs (decided)

The Privacy Policy says Code Crave keeps nothing about the user. So, by configuration in `Infra/`, checked by the `terraform test` files and by a grep in `scripts/check-rules.sh` that fails on `logging_config`, `aws_s3_bucket_logging`, `aws_cloudfront_realtime_log_config`, `aws_wafv2_web_acl_logging_configuration`, `access_log_settings` or `sampled_requests_enabled = true` in any `Infra/**/*.tf`:
- CloudFront standard logs off and no real-time log config, on every distribution.
- S3 server access logs off on the site bucket. No CloudTrail data events.
- CloudTrail's default event history (90 days of management events, the AWS API calls the deploy role makes) stays. It records deploys, not visitors.

### 6. The API (dropped on 2026-11-23)

This design planned an API at `api.antuna.app`: an API Gateway HTTP API in eu-north-1 behind its own CloudFront distribution, an AWS WAF web ACL with the IP reputation list and a rate rule, an origin secret so calls around CloudFront were refused, and a Lambda per service in `Services/<name>/`. Two changes were to use it: `add-support-requests` (an in-app report form that filed GitHub issues) and `add-title-metadata` (movie and series info from TMDB).

On 2026-11-23 the owner dropped the in-app support form as too much machinery for what it gives; support is email to antuna@code-crave.se on the site's support page. The owner also put the title-info service on hold. With no caller left, the API, `Infra/modules/api`, the `api` DNS record, the WAF web ACL, the origin secret and `hosting/the-api-answers-on-its-own-address` are dropped, and nothing of them was built. If a later change needs a server, it decides how in its own design.md and builds on this account, domain and set of roles.

### 7. The domain (decided)

The owner decided on 2026-11-22: a short `.app` name, registered in Route 53 Domains, so the name servers point at the hosted zone with no extra step. On 2026-11-23 the owner renamed the app Antuna and picked `antuna.app` (task 1.1); `rename-to-antuna` moved every address to it. Registration is a purchase, so the owner does it by hand. Route 53 Domains creates a hosted zone with it, and the owner imports that zone into `modules/edge` before the first apply (decision 9), so the name servers already match.

Options considered:
- **A short `.app` name in Route 53 Domains (chosen).** `.app` is HTTPS-only by HSTS preload, which matches the site, and Route 53 sells it.
- **`.tv`.** Fits a TV app, but costs more a year and has no HTTPS preload.
- **`.se`.** Matches the company's country; Route 53 Domains does not sell it, so the name servers are set by hand at another registrar.
- **Another registrar for any of these.** Works, with the hosted zone's four name servers set there by hand.

`www` and the bare domain, decided by the owner on 2026-11-22. Options considered: serve the bare domain and redirect `www` to it (chosen), serve `www` and redirect the bare domain, or serve both. One address keeps links and search results on one name; the certificate covers both names.

Records in the zone: apex and `www` A/AAAA aliases to the site distribution, the ACM validation CNAMEs, and a CAA record allowing only `amazon.com`. No MX record, an SPF record `v=spf1 -all` and a DMARC record `v=DMARC1; p=reject` so nobody can send mail as the domain.

Old domain: nothing to retire. Pages was never enabled on the repository and the code-crave.se zone has no `antenna` record, so there is no redirect and no owner step (task 4.2).

### 8. No email on the domain (decided)

`antuna.app` gets no MX record (decision 7), so mail to it bounces. Support mail goes to antuna@code-crave.se, which the site's support page (`add-feature-website`) shows. That mailbox is on the company's domain, outside this repo and outside AWS.

App Store Connect requires a support URL; the site's `/support/` page is it. App Review's guideline 1.5 asks that the support URL "include an easy way to contact you"; the support page gives the email address. Separately, the EU Digital Services Act makes Apple show a trader's address, phone number and email on the product page for a paid app in the EU. That is an address the owner gives Apple in App Store Connect, it can be on any domain, and it needs nothing on `antuna.app`. `docs/release/trader-contact.md` records what is decided: Code Crave is a trader, and the email cannot be on `antuna.app`. The address and phone number are the owner's to give, so task 6.4 stays open until the owner enters them in App Store Connect.

### 9. One-time setup by the owner

Done by 2026-11-24: the domain is registered, the three roots are applied, the state bucket is `antuna-terraform-state-<account id>`, the repository variables are set and the `production` environment exists (tasks 1.1 and 1.4).

Outside the repo, in this order. No agent or workflow runs these. The state bucket comes from `Infra/bootstrap/`, a small config with local state, rather than by hand: it gets versioning, encryption, the public access block and a TLS-only policy the same way every time, and its state file holds that one bucket. The file stays on the owner's machine (`*.tfstate` is ignored by version control); if it is lost, the bucket keeps working and `terraform import` brings it back.

1. Create the AWS account with MFA on the root user, and an IAM Identity Center user with administrator access for the owner. Sign in on the machine with `aws sso login`.
2. Register `antuna.app` in Route 53 Domains (task 1.1). Note the id of the hosted zone it creates.
3. Install Terraform 1.17.2.
4. Create the state bucket: `cd Infra/bootstrap && terraform init && terraform apply`.
5. Apply the CI roles: `cd Infra/ci && terraform init -backend-config=bucket=antuna-terraform-state-<account id> && terraform apply -var github_subject=<subject> -var state_bucket=antuna-terraform-state-<account id>`.
6. Import the zone and apply the rest: in `Infra/antuna`, `terraform init -backend-config=bucket=antuna-terraform-state-<account id>`, then `terraform import -var domain=antuna.app -var alert_email=<address> module.edge.aws_route53_zone.this <zone id>`, then `terraform apply` with the same two `-var`. If Cost Anomaly Detection already has a services monitor in the account, import it as `module.edge.aws_ce_anomaly_monitor.services` before the apply. AWS emails `<address>` once to confirm the anomaly subscription.
7. Set the repository variables `AWS_ACCOUNT_ID`, `ANTUNA_DOMAIN`, `AWS_ALERT_EMAIL`, and from `terraform output` in `Infra/antuna`, `SITE_BUCKET` and `SITE_DISTRIBUTION_ID`. `APPLE_TEAM_ID` is already set.
8. Create the `production` environment, limited to the main branch, with the owner as required reviewer.

From then on `infra.yml` plans on pull requests, applies on main after the owner approves, and uploads the site.

### 10. The config.yaml amendment (dropped on 2026-11-23)

`openspec/config.yaml` says sync is CloudKit "with no server of our own". This design planned to amend that line once `modules/api` deployed. With the API dropped (decision 6) there is still no server of our own: the site is static files on S3 behind CloudFront, and the only code of ours that runs in AWS is the CloudFront Function that maps addresses. The line and CLAUDE.md's hard constraints stay as they are.

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
| Budgets | the first two budgets are free |

About $2 a month. The dropped API (decision 6) would have added about $6 for its WAF web ACL and the origin secret.

Budget: $20 a month in AWS Budgets, as the owner decided on 2026-11-22 (the options were $10, $20 and $50), alerting the owner's AWS account address at 50% actual, 100% actual and 100% forecast, plus a Cost Anomaly Detection monitor on all services that emails a daily summary once an anomaly's total impact reaches $5. Alerts use the AWS account's email, which is not on the new domain.

## Risks / Trade-offs

- The account is the owner's to keep: root credentials, MFA, and billing. A leaked deploy role is limited to one repository's main branch and environment.
- The state bucket is the one copy of what Terraform manages. It is versioned, blocks public access and has `prevent_destroy`; a lost state means importing every resource again.
- Tearing down runs in reverse: `antuna`, then `ci`, then `bootstrap`. The `site` module's policy on the `antuna-site` role goes with `antuna`.
- If the domain is not registered before the rename PR, the app builds with a name that does not resolve and the paywall's links fail on device. The rename (task group 5) waits for the site to answer on the new domain.
- Universal links: Apple fetches the association file through its CDN, which caches it. A wrong file on the first deploy can keep setup links opening in Safari for up to a day on test devices. The device checklist's association check runs after the first deploy.
- Lock-in is small: the site is a folder and the domain is the owner's.

## Migration Plan

1. Owner: steps in decision 9.
2. PR: `Infra/` with `bootstrap`, `ci`, `modules/edge` and `modules/site`, and `infra.yml`. It deploys nothing until the owner has done decision 9; after that, the next merge deploys the site to `antuna.app`, or a manual run of `infra.yml` does.
3. PR: `pages.yml`, `Web/CNAME` and `Web/.nojekyll` removed, `release.yml` dispatches `infra.yml` (task 4.1).
4. PR: the rename in every place listed above.
5. PR: the diagrams and the trader contact notes. The `modules/api` PR planned here was dropped with the API (decision 6).

No data moves. No site is live before step 2 deploys, so rollback for steps 2 to 4 is reverting the PRs.

## Open Questions

The owner decided the rest on 2026-11-22, each as recommended: who approves deploys (decision 4), one environment (decision 4), `Infra/` and `Services/` (decision 1; Terraform, not CDK, later the same day), the $20 budget (Cost), when the WAF web ACL is created (decision 6, moot since the API was dropped on 2026-11-23), `www` (decision 7) and the kind of domain (decision 7).

1. **Which exact name.** Decided on 2026-11-23: `antuna.app`, with the app renamed Antuna. Registering it is the owner's part of task 1.1.
