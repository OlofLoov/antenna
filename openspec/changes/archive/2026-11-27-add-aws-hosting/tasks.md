## 1. Proposal and owner setup

- [x] 1.1 Owner: register `antuna.app` in Route 53 Domains. The owner picked the name on 2026-11-23, and `rename-to-antuna` replaced the placeholder in this change, `add-feature-website` and `add-title-metadata`. Every task after this group waited for the registration. Done on 2026-11-23
- [x] 1.2 Write the proposal, delta specs, design and tasks, and validate with `openspec validate add-aws-hosting --strict`
- [x] 1.3 Fold in the owner's 2026-11-22 decisions on the open questions, and the single-page site from `add-feature-website`
- [x] 1.4 Owner, outside the repo, the steps in design.md decision 9: create the AWS account, create the state bucket with `Infra/bootstrap/`, apply `Infra/ci/` from his machine, import the Route 53 Domains zone and apply `Infra/antuna/`, set `AWS_ACCOUNT_ID`, `ANTUNA_DOMAIN`, `AWS_ALERT_EMAIL`, `SITE_BUCKET` and `SITE_DISTRIBUTION_ID`, and create the `production` environment with the owner as required reviewer. Done by 2026-11-24, with the state bucket `antuna-terraform-state-<account id>`
- [x] 1.5 Record the owner's switch from the CDK app to Terraform (design.md decisions 1 and 2), with the layout, the pinned versions, the S3 state backend and the `terraform test` files

## 2. Terraform and CI roles

- [x] 2.1 Add `Infra/bootstrap/` (the state bucket, local state) and the `Infra/ci/` root (the GitHub OIDC provider and the `antuna-diff`, `antuna-deploy` and `antuna-site` roles), with Terraform 1.17.2 and `hashicorp/aws` 6.73.0 pinned, the lock files committed, and `terraform test` files for each trust subject, citing `hosting/deploys-come-only-from-main`
- [x] 2.2 Add `.github/workflows/infra.yml`: `terraform fmt`, `validate` and `test` on pull requests, a plan comment through `antuna-diff` when `AWS_ACCOUNT_ID` is set, apply in the `production` environment on main; every AWS job skips while the variables are unset
- [x] 2.3 Add the `scripts/check-rules.sh` grep that fails on logging blocks in `Infra/**/*.tf`, citing `hosting/nothing-keeps-a-record-of-requests`
- [x] 2.4 Make `scripts/check-spec-refs.sh` also read citations in `Infra/**/*.tftest.hcl`

## 3. Edge and site modules

- [x] 3.1 Add `Infra/modules/edge` and the `Infra/antuna/` root: hosted zone, certificate, CAA, SPF `-all` and DMARC reject records and no MX, the Budgets alarm and the anomaly monitor, with `terraform test` files citing `hosting/the-domain-receives-no-email` and `hosting/the-owner-hears-about-cost-before-it-grows`
- [x] 3.2 Add `Infra/modules/site`: the private bucket, the distribution with Origin Access Control, the address function with the `www` redirect, 403 and 404 answered by `/404.html` with status 404 and no fallback to `index.html` (the site build writes `/404.html`), with `terraform test` files for no public access, no logs and the error responses, citing `hosting/the-site-is-served-over-https-on-antuna-s-domain` and `hosting/the-site-s-files-cannot-be-read-around-it`
- [x] 3.3 Add the two response headers policies from design.md decision 3, the site's and the stricter one on `/setup*`, with `terraform test` files that compare each Content-Security-Policy with the decided string and fail on `'unsafe-inline'` or `'unsafe-eval'` in `script-src`, citing `hosting/pages-run-only-the-site-s-own-code`
- [x] 3.4 Add the site job to `infra.yml`: Node from `Web/site/.nvmrc`, `npm ci` and `npm run build` in `Web/site/` once it exists, `scripts/publish-web.sh` with the build folder, the two-step `aws s3 sync` with the JSON content type on the association file and the year-long cache on `/_app/immutable/`, and the invalidation, with `SITE_BUCKET` and `SITE_DISTRIBUTION_ID` from repository variables, citing `antuna-website/the-site-publishes-from-main`
- [x] 3.5 After the first deploy, check the site, the association file, HTTPS, the `www` redirect, a 404 status on a made-up address and the CSP header on `antuna.app` with the device checklist. Checked with curl on 2026-11-24: every page linked from the header and footer answers 200 over HTTPS with HSTS and the site CSP, `/setup/` has the no-script CSP, `http://` and `www.` answer 301 to `https://antuna.app`, a made-up address answers 404 with "Page not found", the association file is `application/json` with the team id, `/review/antuna-review.m3u` and `/review/guide.xml` are served, the bucket refuses a direct request with 403, and DNS has no MX, SPF `-all`, DMARC reject and CAA `amazon.com`
- [x] 3.6 Allow the route announcer's style attribute by its hash in the site's `style-src-attr` (design.md decision 3), drop the `#svelte-announcer` rule from `site.css`, and add `checkStyleHashes` to the site check, which fails when a style attribute in the built scripts has no hash in the policy or the policy holds a hash nothing writes, citing `hosting/pages-run-only-the-site-s-own-code`

## 4. Retire GitHub Pages

- [x] 4.1 Remove `.github/workflows/pages.yml`, `Web/CNAME` and `Web/.nojekyll`; point `release.yml` at the site job in `infra.yml`; update `WebsiteTests` and `ReleaseTests` to read the new workflow
- [x] 4.2 Owner: switch off GitHub Pages and delete the `antenna` record in the code-crave.se DNS. Not needed: Pages was never enabled on the repository and the record never existed
- [x] 4.3 Say in the Privacy Policy that the site is served by Amazon CloudFront and that its request logs are off (decision 5), in place of the GitHub Pages paragraph, citing `antuna-website/the-privacy-policy-rules-out-tracking`

## 5. Rename the domain

Done in `rename-to-antuna` on 2026-11-23, ahead of 1.1 and 3.5, at the owner's word.

- [x] 5.1 Change `SetupLink.host`, the two entitlements, the Terms and Privacy addresses in `project.yml`, both `Info.plist` files and the paywall previews; make the link tests and setup UI tests use `SetupLink.host`, citing `antuna-website/the-site-answers-every-address-the-app-uses`
- [x] 5.2 Change `Web/review/antuna-review.m3u`, `docs/release/app-review-notes.md` and the `scripts/check-rules.sh` review pattern, citing `app-release/app-review-gets-a-test-source-outside-the-app`
- [x] 5.3 Change every `fastlane/metadata/*/support_url.txt` and `privacy_url.txt` and `SITE` in `scripts/store_metadata.py`, and make the listing check fail on the old domain, citing `app-release/the-app-store-addresses-are-on-antuna-s-domain`
- [x] 5.4 Change `docs/release/app-privacy.md`, `docs/release/device-checklist.md`, CLAUDE.md's `Web/` line and the three `TV-Paywall` boards
- [x] 5.5 Run `SetupUITests` and `SendLoginsUITests` on a local simulator

## 6. Diagrams and store answers

The owner dropped the API on 2026-11-23 (design.md decisions 6 and 10), so 6.1 and 6.2 are not built.

- [x] 6.1 Add `Infra/modules/api`: the HTTP API, its distribution at `api.antuna.app` and its certificate, the origin secret and header, the shared origin check in `Services/shared/`, the WAF web ACL with no logging or sampled requests, and the header-stripping policy, with `terraform test` files, citing `hosting/the-api-answers-on-its-own-address`. Dropped on 2026-11-23 with the API; the requirement is removed
- [x] 6.2 Amend the "no server of our own" line in `openspec/config.yaml` and CLAUDE.md's hard constraints as design.md decision 10 words it. Dropped on 2026-11-23: with no API there is still no server of our own, and the line stays
- [x] 6.3 Add the website on AWS (CloudFront, S3 and Route 53) to `docs/architecture/c4-context.drawio.svg` and `c4-container.drawio.svg`
- [x] 6.4 Record the App Store trader contact answer from decision 8 in `docs/release/`. `docs/release/trader-contact.md` has what is decided. On 2026-11-27 the owner picked the email and gave the address; the phone number is left as a release step in that file

## 7. Verify

- [x] 7.1 Each requirement has a test citing `<capability>/<requirement-slug>`, and `scripts/check-spec-refs.sh` passes
- [x] 7.2 `/opsx:verify` passes. Run on 2026-11-24: every other task is done and every requirement is cited by a test; the one finding was task 6.4, closed on 2026-11-27
