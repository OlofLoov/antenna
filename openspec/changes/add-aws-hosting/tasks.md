## 1. Proposal and owner setup

- [ ] 1.1 Owner: pick the exact name, a short `.app` name containing "antenna", register it in Route 53 Domains, and replace `<antenna-domain>` in this change, `add-support-requests` and `add-feature-website`. Every task after this group waits for it
- [x] 1.2 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-aws-hosting --strict`
- [x] 1.3 Fold in the owner's 2026-11-22 decisions on the open questions, and the single-page site from `add-feature-website`
- [ ] 1.4 Owner, outside the repo: create the AWS account, bootstrap CDK in eu-north-1 and us-east-1, deploy `AntennaCi` by hand, set `AWS_ACCOUNT_ID`, `ANTENNA_DOMAIN` and the `production` environment with the owner as required reviewer (design.md decision 9)

## 2. CDK app and CI roles

- [ ] 2.1 Add `Infra/` (TypeScript CDK app, pinned `aws-cdk-lib`, Jest) with `AntennaCi`: the GitHub OIDC provider and the `antenna-diff`, `antenna-deploy` and `antenna-site` roles, with assertion tests for each trust subject, citing `hosting/deploys-come-only-from-main`
- [ ] 2.2 Add `.github/workflows/infra.yml`: test, synth and a `cdk diff` comment on pull requests; deploy in the `production` environment on main
- [ ] 2.3 Add the `scripts/check-rules.sh` grep that fails on access log settings in `Infra/lib/`, citing `hosting/nothing-keeps-a-record-of-requests`
- [ ] 2.4 Make `scripts/check-spec-refs.sh` also read citations in `Infra/` TypeScript tests

## 3. Edge and site stacks

- [ ] 3.1 Add `AntennaEdge`: hosted zone, certificates, CAA, SPF `-all` and DMARC reject records and no MX, the Budgets alarm and the anomaly monitor, citing `hosting/the-domain-receives-no-email` and `hosting/the-owner-hears-about-cost-before-it-grows`
- [ ] 3.2 Add `AntennaSite`: the private bucket, the distribution with Origin Access Control, the address function with the `www` redirect, 403 and 404 answered by `/404.html` with status 404 and no fallback to `index.html`, and `Web/404.html`, with assertion tests for no public access, no logs and the error responses, citing `hosting/the-site-is-served-over-https-on-antenna-s-domain` and `hosting/the-site-s-files-cannot-be-read-around-it`
- [ ] 3.3 Add the two response headers policies from design.md decision 3, the site's and the stricter one on `/setup*`, with assertion tests that compare each Content-Security-Policy with the decided string and fail on `'unsafe-inline'` or `'unsafe-eval'` in `script-src`, citing `hosting/pages-run-only-the-site-s-own-code`
- [ ] 3.4 Add the site job to `infra.yml`: Node 22, `npm ci` and `npm run build` in `Web/site/` once it exists, `scripts/publish-web.sh` with the build folder, the two-step `aws s3 sync` with the JSON content type on the association file and the year-long cache on `/_app/immutable/`, and the invalidation, citing `antenna-website/the-site-publishes-from-main`
- [ ] 3.5 After the first deploy, check the site, the association file, HTTPS, the `www` redirect, a 404 status on a made-up address and the CSP header on `<antenna-domain>` with the device checklist

## 4. Retire GitHub Pages

- [ ] 4.1 Remove `.github/workflows/pages.yml`, `Web/CNAME` and `Web/.nojekyll`; point `release.yml` at the site job in `infra.yml`; update `WebsiteTests` and `ReleaseTests` to read the new workflow
- [ ] 4.2 Owner: switch off GitHub Pages and delete the `antenna` record in the code-crave.se DNS

## 5. Rename the domain

Waits for 1.1 and 3.5: the name is picked and the site answers on it.

- [ ] 5.1 Change `SetupLink.host`, the two entitlements, the Terms and Privacy addresses in `project.yml`, both `Info.plist` files and the paywall previews; make the link tests and setup UI tests use `SetupLink.host`, citing `antenna-website/the-site-answers-every-address-the-app-uses`
- [ ] 5.2 Change `Web/review/antenna-review.m3u`, `docs/release/app-review-notes.md` and the `scripts/check-rules.sh` review pattern, citing `app-release/app-review-gets-a-test-source-outside-the-app`
- [ ] 5.3 Change every `fastlane/metadata/*/support_url.txt` and `privacy_url.txt` and `SITE` in `scripts/store_metadata.py`, and make the listing check fail on the old domain, citing `app-release/the-app-store-addresses-are-on-antenna-s-domain`
- [ ] 5.4 Change `docs/release/app-privacy.md`, `docs/release/device-checklist.md`, CLAUDE.md's `Web/` line and the three `TV-Paywall` boards
- [ ] 5.5 Run `SetupUITests` and `SendLoginsUITests` on a local simulator

## 6. API stack and constraints

Ships when `add-title-metadata` or `add-support-requests` is ready to add its first route.

- [ ] 6.1 Add `AntennaApi`: the HTTP API, its distribution at `api.<antenna-domain>`, the origin secret and header, the shared origin check in `Services/shared/`, the WAF web ACL with no logging or sampled requests, and the header-stripping policy, with assertion tests, citing `hosting/the-api-answers-on-its-own-address`
- [ ] 6.2 Amend the "no server of our own" line in `openspec/config.yaml` and CLAUDE.md's hard constraints as design.md decision 10 words it
- [ ] 6.3 Add AWS (CloudFront, the API) to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg`
- [ ] 6.4 Record the App Store trader contact answer from decision 8 in `docs/release/`

## 7. Verify

- [ ] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [ ] 7.2 `/opsx:verify` passes
